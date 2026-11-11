# frozen_string_literal: true

module Portolan
  module Query
    class Aggregate < Base
      PARAMS = (Base::PARAMS + %w[measure group_by period]).freeze
      MAX_GROUPS = 3
      MAX_BUCKET_COMBINATIONS = 50
      GROUP_LIMIT = 10_000
      TOO_MANY_GROUPS = "more than #{GROUP_LIMIT} groups; filter or group by fewer dimensions".freeze

      attr_reader :measure, :group_dimensions, :time_dimension

      private

      def resolve_request
        @measure = dataset.measures[@params['measure'].to_s]
        @group_dimensions = group_names.filter_map { |name| dataset.dimensions[name] }
        @time_dimension = @group_dimensions.find(&:time?)
      end

      def validate_request
        validate_measure
        validate_group_by
        validate_period
      end

      def validate_measure
        return if measure

        problem = @params['measure'] ? "unknown measure `#{@params['measure']}`" : 'measure is required'
        errors << "#{problem}; allowed: #{quoted(dataset.measures.keys)}"
      end

      def validate_group_by
        return errors << 'group_by must be a list of dimension names' unless group_by_list?

        (group_names - dataset.dimensions.keys).each do |name|
          errors << "unknown dimension `#{name}` in group_by; allowed: #{quoted(dataset.dimensions.keys)}"
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
        if time_dimension.nil?
          errors << 'period only applies when grouping by a date dimension' if period
        elsif period.nil?
          errors << "period is required when grouping by `#{time_dimension.name}`; " \
                    "allowed: #{quoted(time_dimension.periods)}"
        elsif time_dimension.periods.exclude?(period)
          errors << "period `#{period}` does not apply to `#{time_dimension.name}`; " \
                    "allowed: #{quoted(time_dimension.periods)}"
        end
      end

      def group_by_list?
        @params['group_by'].nil? || [::String, ::Symbol, ::Array].any? { |kind| @params['group_by'].is_a?(kind) }
      end

      def group_names
        case @params['group_by']
        when ::String, ::Symbol then [@params['group_by'].to_s]
        when ::Array then @params['group_by'].map(&:to_s)
        else []
        end
      end

      def period = @params['period']&.to_s

      def answer(scope)
        rows = measured_rows(scope)
        return Result.new(request:, errors: [TOO_MANY_GROUPS]) if rows.size > GROUP_LIMIT

        rows = sorted(rows)
        Result.new(request:, rows: trimmed(rows), definitions:, total_rows: rows.size)
      end

      def measured_rows(scope)
        bucket_dimensions, column_dimensions = group_dimensions.partition(&:buckets?)
        rows = []

        bucket_combinations(bucket_dimensions).each do |combination|
          narrowed = combination.reduce(scope) { |current, (_dimension, bucket)| bucket.apply(current) }
          grouped_values(narrowed, column_dimensions).each do |keys, value|
            rows << row(combination, column_dimensions.zip(keys), value)
          end
          break if rows.size > GROUP_LIMIT
        end
        rows
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
        return [[[], measure.call(scope)]] if dimensions.empty?

        grouped = dimensions.reduce(scope) do |current, dimension|
          current = dimension.join(current)
          current.group(group_expression(current, dimension))
        end
        measure.call(grouped.limit(GROUP_LIMIT + 1)).map { |keys, value| [dimensions.one? ? [keys] : keys, value] }
      end

      def group_expression(scope, dimension)
        column = dimension.column(scope)
        dimension.time? ? dimension.type.truncate(column, period) : column
      end

      def row(combination, keyed, value)
        labels = combination.to_h { |dimension, bucket| [dimension.name, bucket.name] }
        keyed.each { |dimension, key| labels[dimension.name] = label(dimension, key) }
        grouped = group_dimensions.to_h { |dimension| [dimension.name, labels[dimension.name]] }
        grouped.merge(measure.name => value.is_a?(::BigDecimal) ? value.to_f : value)
      end

      def label(dimension, key) = key.nil? ? nil : dimension.type.label(key, period)

      def sorted(rows)
        return rows.sort_by { |row| series_order(row) } if time_dimension

        rows.sort_by { |row| [-row[measure.name].to_f, row.values.map(&:to_s)] }
      end

      def series_order(row)
        label = row[time_dimension.name]
        [label.nil? ? 0 : 1, label.to_s, -row[measure.name].to_f, row.values.map(&:to_s)]
      end

      def trimmed(rows)
        return rows.first(limit) unless time_dimension

        periods = rows.chunk_while { |earlier, later| earlier[time_dimension.name] == later[time_dimension.name] }
        kept = []
        periods.reverse_each do |period_rows|
          if kept.size + period_rows.size > limit
            kept = period_rows.first(limit) if kept.empty?
            break
          end
          kept = period_rows + kept
        end
        kept
      end

      def definitions
        definitions_for(group_dimensions).merge(measure.name => { description: measure.description })
      end

      def request
        return super unless @params.is_a?(Hash)

        super.merge(measure: @params['measure']&.to_s, group_by: group_names.presence, period:)
      end
    end
  end
end
