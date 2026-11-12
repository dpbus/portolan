# frozen_string_literal: true

module Portolan
  module Query
    class Aggregate < Base
      PARAMS = (Base::PARAMS + %w[measure group_by period]).freeze
      MAX_GROUPS = 3
      MAX_BUCKET_COMBINATIONS = 50
      GROUP_LIMIT = 10_000
      TOO_MANY_GROUPS = "more than #{GROUP_LIMIT} groups; filter or group by fewer dimensions".freeze

      private

      attr_reader :measure, :group_names, :group_dimensions, :time_dimension

      def resolve_request
        @group_names = parse_group_by
        return unless dataset

        @measure = dataset.measures[@params['measure']]
        @group_dimensions = Array(group_names).filter_map { |name| dataset.dimensions[name] }
        @time_dimension = @group_dimensions.find(&:time?)
      end

      def parse_group_by
        case @params['group_by']
        when nil then []
        when ::String then [@params['group_by']]
        when ::Array then @params['group_by'].map(&:to_s)
        end
      end

      def validate_request
        validate_measure
        validate_group_by
        validate_period
      end

      def validate_measure
        return if measure

        problem = @params['measure'] ? "unknown measure `#{@params['measure']}`" : 'measure is required'
        errors << "#{problem}; allowed: #{Portolan.quoted(dataset.measures.keys)}"
      end

      def validate_group_by
        return errors << 'group_by must be a list of dimension names' unless group_names

        (group_names - dataset.dimensions.keys).each do |name|
          errors << "unknown dimension `#{name}` in group_by; allowed: #{Portolan.quoted(dataset.dimensions.keys)}"
        end
        group_names.tally.each { |name, count| errors << "group_by names `#{name}` twice" if count > 1 }
        errors << "group_by takes at most #{MAX_GROUPS} dimensions" if group_names.size > MAX_GROUPS
        group_dimensions.select(&:time?).drop(1).each do |dimension|
          errors << "group_by takes at most one date dimension; filter on `#{dimension.name}` instead"
        end
        validate_bucket_combinations
      end

      def validate_bucket_combinations
        combinations = group_dimensions.select(&:buckets?).map { |dimension| dimension.buckets.size }.reduce(1, :*)
        return if combinations <= MAX_BUCKET_COMBINATIONS

        errors << "group_by makes #{combinations} bucket combinations; at most #{MAX_BUCKET_COMBINATIONS} " \
                  'are allowed, so filter on a bucket dimension instead'
      end

      def validate_period
        return errors << 'period only applies when grouping by a date dimension' if period && !time_dimension
        return if time_dimension.nil? || time_dimension.periods.include?(period)

        problem = period ? "period `#{period}` does not apply to" : 'period is required when grouping by'
        errors << "#{problem} `#{time_dimension.name}`; allowed: #{Portolan.quoted(time_dimension.periods)}"
      end

      def period = @params['period']

      def answer(scope)
        rows, total_rows = measured_rows(scope)
        raise Refused, TOO_MANY_GROUPS if rows.size > GROUP_LIMIT

        Result.new(request:, rows: trimmed(sorted(rows)), definitions:, total_rows:)
      end

      def measured_rows(scope)
        bucket_dimensions, column_dimensions = group_dimensions.partition(&:buckets?)
        rows = []
        total_rows = 0

        bucket_combinations(bucket_dimensions).each do |combination|
          narrowed = combination.reduce(scope) { |current, (_dimension, bucket)| bucket.apply(current) }
          bucket_labels = combination.to_h { |dimension, bucket| [dimension.name, bucket.name] }
          values, group_count = grouped_values(narrowed, column_dimensions)
          values.each { |keys, value| rows << row(bucket_labels, column_dimensions.zip(keys), value) }
          total_rows += group_count
          break if rows.size > GROUP_LIMIT
        end
        [rows, total_rows]
      end

      def bucket_combinations(dimensions)
        return [[]] if dimensions.empty?

        lists = dimensions.map { |dimension| allowed_buckets(dimension).map { |bucket| [dimension, bucket] } }
        lists.first.product(*lists.drop(1))
      end

      def allowed_buckets(dimension)
        value_lists = filters.select { |filter| filter.dimension == dimension }.map(&:values)
        names = value_lists.reduce(dimension.buckets.keys) { |kept, values| kept & values }
        dimension.buckets.values_at(*names)
      end

      def grouped_values(scope, dimensions)
        return [[[[], measure.call(scope)]], 1] if dimensions.empty?

        grouped = grouped_scope(scope, dimensions)
        return largest_first(grouped, dimensions) unless time_dimension

        values = keyed(measure.call(grouped.limit(GROUP_LIMIT + 1)), dimensions)
        [values, values.size]
      end

      def grouped_scope(scope, dimensions)
        dimensions.reduce(scope) do |current, dimension|
          current = dimension.join(current)
          current.group(group_expression(current, dimension))
        end
      end

      def largest_first(grouped, dimensions)
        largest = grouped.order(measure.node(grouped).desc.nulls_last).limit(limit)
        [keyed(measure.call(largest), dimensions), group_count(grouped)]
      end

      def group_count(grouped) = grouped.klass.unscoped.from(grouped.select(Arel.sql('1')), :groups).count

      def keyed(values, dimensions) = values.map { |keys, value| [dimensions.one? ? [keys] : keys, value] }

      def group_expression(scope, dimension) = dimension.type.group(dimension.column(scope), period)

      def row(bucket_labels, keyed, value)
        labels = bucket_labels.merge(keyed.to_h { |dimension, key| [dimension.name, label(dimension, key)] })
        grouped = group_dimensions.to_h { |dimension| [dimension.name, labels[dimension.name]] }
        grouped.merge(measure.name => measure.label(value))
      end

      def label(dimension, key) = key.nil? ? nil : dimension.type.label(key, period)

      def sorted(rows)
        rows.sort_by { |row| [*period_order(row), -row[measure.name].to_f, row.values.map(&:to_s)] }
      end

      def period_order(row)
        return [] unless time_dimension

        label = row[time_dimension.name]
        [label.nil? ? 0 : 1, label.to_s]
      end

      def trimmed(rows)
        return rows.first(limit) unless time_dimension

        periods = rows.chunk_while { |earlier, later| earlier[time_dimension.name] == later[time_dimension.name] }.to_a
        kept = []
        periods.reverse_each do |period_rows|
          break if kept.size + period_rows.size > limit

          kept = period_rows + kept
        end
        kept.empty? ? periods.last.to_a.first(limit) : kept
      end

      def definitions
        definitions_for(group_dimensions).merge(measure.name => { description: measure.description })
      end

      def request = super.merge(measure: @params['measure'], group_by: Array(group_names).presence, period:)
    end
  end
end
