# frozen_string_literal: true

module Portolan
  module Query
    class Filter
      PARAMS = %w[dimension op value values].freeze
      OPERATOR_ARITIES = { 'eq' => 1..1, 'gt' => 1..1, 'lt' => 1..1, 'in' => 1.., 'between' => 2..2 }.freeze

      attr_reader :dimension, :operator, :values, :errors

      def initialize(dataset, params)
        @dataset = dataset
        @params = params
        if params.is_a?(Hash)
          @dimension = dataset.dimensions[params['dimension'].to_s]
          @operator = params['op'].to_s
        end
        @errors = []
        validate
        @errors.freeze
        @values = cast_values if valid?
        freeze
      end

      def valid? = errors.empty?

      def apply(scope)
        return apply_buckets(scope) if dimension.buckets?

        scope = scope.joins(dimension.joins) if dimension.joins
        dimension.expression ? scope.where(expression_condition) : column_condition(scope)
      end

      private

      def validate
        validate_shape
        validate_keys if valid?
        validate_dimension if valid?
        validate_operator if valid?
        validate_arity if valid?
        validate_values if valid?
        validate_order if valid?
      end

      def validate_shape
        errors << 'must be an object with `dimension`, `op`, and `value` or `values`' unless @params.is_a?(Hash)
      end

      def validate_keys
        unknown = @params.keys - PARAMS
        errors << "unknown key #{quoted(unknown)}; allowed: #{quoted(PARAMS)}" if unknown.any?
        errors << 'give `value` or `values`, not both' if @params.key?('value') && @params.key?('values')
      end

      def validate_dimension
        return if dimension

        errors << "unknown dimension `#{@params['dimension']}`; allowed: #{quoted(@dataset.dimensions.keys)}"
      end

      def validate_operator
        return if dimension.operators.include?(operator)

        errors << "operator `#{operator}` does not apply to `#{dimension.name}`; " \
                  "allowed: #{quoted(dimension.operators)}"
      end

      def validate_arity
        errors << arity_message unless OPERATOR_ARITIES.fetch(operator).cover?(requested_values.size)
      end

      def validate_values
        requested_values.each do |value|
          type.errors_for(value).each { |error| errors << "`#{dimension.name}`: #{error}" }
        end
      end

      def validate_order
        return unless operator == 'between'
        return if type.cast(requested_values.first) <= type.cast(requested_values.last)

        errors << '`between` needs the smaller value first'
      end

      def arity_message
        case operator
        when 'between' then '`between` takes two values'
        when 'in' then '`in` takes one or more values'
        else "`#{operator}` takes one value"
        end
      end

      def type = dimension.type
      def requested_values = Array(@params.key?('values') ? @params['values'] : @params['value'])
      def cast_values = requested_values.map { |value| type.cast(value) }.freeze

      def column_condition(scope)
        case operator
        when 'eq', 'in' then scope.where(dimension.name => values)
        when 'gt' then scope.where.not(dimension.name => ..upper_bound)
        when 'lt' then scope.where(dimension.name => ...lower_bound)
        when 'between' then scope.where(dimension.name => lower_bound..upper_bound)
        end
      end

      def expression_condition
        expression = Arel::Nodes::Grouping.new(Arel.sql(dimension.expression))
        case operator
        when 'eq', 'in' then expression.in(values.map { |value| bound(value) })
        when 'gt' then expression.gt(bound(upper_bound))
        when 'lt' then expression.lt(bound(lower_bound))
        when 'between' then expression.gteq(bound(lower_bound)).and(expression.lteq(bound(upper_bound)))
        end
      end

      def lower_bound = type.lower_bound(values.first)
      def upper_bound = type.upper_bound(values.last)

      def bound(value)
        Arel::Nodes::BindParam.new(ActiveRecord::Relation::QueryAttribute.new(dimension.name, value, ActiveModel::Type::Value.new))
      end

      def apply_buckets(scope)
        values.map { |name| dimension.buckets.fetch(name).apply(scope) }.reduce(:or)
      end

      def quoted(items) = items.map { |item| "`#{item}`" }.join(', ')
    end
  end
end
