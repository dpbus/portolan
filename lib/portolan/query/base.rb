# frozen_string_literal: true

module Portolan
  module Query
    class Base
      PARAMS = %w[dataset filters limit].freeze
      ROW_LIMIT = 50
      UNSCOPED = %i[order select limit offset includes preload eager_load].freeze
      INTEGER = Type::Integer.new

      attr_reader :errors

      def initialize(registry, params, context:)
        @registry = registry
        params = normalize(params)
        @shape_error = !params.is_a?(Hash)
        @params = @shape_error ? {} : params
        @context = context
        @filters = []
        resolve
        @errors = []
        validate
        @errors.freeze
        freeze
      end

      def valid? = errors.empty?

      def call
        return Result.new(request:, errors:) unless valid?

        relation = dataset.relation_for(@context).unscope(*UNSCOPED)
        Guard.run(relation.klass) { answer(filtered(relation)) }
      rescue Refused => e
        Result.new(request:, errors: [e.message])
      end

      private

      attr_reader :dataset, :filters

      def normalize(params)
        params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
        case params
        when ::Hash then params.to_h { |key, value| [key.to_s, normalize(value)] }
        when ::Array then params.map { |value| normalize(value) }
        when ::Symbol then params.to_s
        else params
        end
      end

      def resolve
        @dataset = @registry[@params['dataset']]
        @filters = filter_params.map { |params| Filter.new(@dataset, params) } if @dataset
        resolve_request
      end

      def resolve_request; end

      def validate
        validate_shape
        validate_keys if valid?
        validate_dataset if valid?
        return unless valid?

        validate_request
        validate_filters
        validate_limit
      end

      def validate_request; end

      def validate_shape
        errors << 'request must be an object' if @shape_error
      end

      def validate_keys
        unknown = @params.keys - self.class::PARAMS
        return if unknown.empty?

        errors << "unknown key #{Portolan.quoted(unknown)}; allowed: #{Portolan.quoted(self.class::PARAMS)}"
      end

      def validate_dataset
        return if dataset

        problem = @params['dataset'] ? "unknown dataset `#{@params['dataset']}`" : 'dataset is required'
        errors << "#{problem}; allowed: #{Portolan.quoted(@registry.names)}"
      end

      def validate_filters
        return if @params['filters'].nil?
        return errors << 'filters must be a list' unless @params['filters'].is_a?(::Array)

        filters.each.with_index(1) do |filter, number|
          filter.errors.each { |error| errors << "filter #{number}: #{error}" }
        end
      end

      def validate_limit
        errors << "limit must be an integer from 1 to #{ROW_LIMIT}" unless (1..ROW_LIMIT).cover?(limit)
      end

      def filter_params = @params['filters'].is_a?(::Array) ? @params['filters'] : []
      def limit = @params['limit'].nil? ? ROW_LIMIT : INTEGER.cast(@params['limit'])

      def filtered(relation) = filters.reduce(relation) { |current, filter| filter.apply(current) }

      def definitions_for(dimensions)
        (dimensions + filters.map(&:dimension)).uniq.to_h { |dimension| [dimension.name, dimension.definition] }
      end

      def request = { dataset: @params['dataset'] }
    end
  end
end
