# frozen_string_literal: true

module Portolan
  module Query
    class Base
      PARAMS = %w[dataset filters limit].freeze
      ROW_LIMIT = 50
      UNSCOPED = %i[order select limit offset includes preload eager_load].freeze

      attr_reader :dataset, :filters, :errors

      def initialize(registry, params, context:)
        @registry = registry
        @params = params
        @context = context
        @filters = []
        resolve if params.is_a?(Hash)
        @errors = []
        validate
        @errors.freeze
        freeze
      end

      def valid? = errors.empty?

      TIMEOUT_ERROR = 'the query took too long; filter to a shorter period or group by fewer dimensions'

      def call
        return Result.new(request:, errors:) unless valid?

        relation = dataset.relation_for(@context).unscope(*UNSCOPED)
        Guard.run(relation.klass) { answer(filtered(relation)) }
      rescue ActiveRecord::QueryCanceled
        Result.new(request:, errors: [TIMEOUT_ERROR])
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.cause.is_a?(PG::DataException)

        Result.new(request:, errors: [data_error(e.cause)])
      end

      private

      def resolve
        @dataset = @registry[@params['dataset']]
        return unless @dataset

        @filters = filter_params.map { |params| Filter.new(@dataset, params) }
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
        errors << 'request must be an object' unless @params.is_a?(Hash)
      end

      def validate_keys
        unknown = @params.keys - self.class::PARAMS
        errors << "unknown key #{quoted(unknown)}; allowed: #{quoted(self.class::PARAMS)}" if unknown.any?
      end

      def validate_dataset
        return if dataset

        problem = @params['dataset'] ? "unknown dataset `#{@params['dataset']}`" : 'dataset is required'
        errors << "#{problem}; allowed: #{quoted(@registry.names)}"
      end

      def validate_filters
        return if @params['filters'].nil?
        return errors << 'filters must be a list' unless @params['filters'].is_a?(::Array)

        filters.each.with_index(1) do |filter, number|
          filter.errors.each { |error| errors << "filter #{number}: #{error}" }
        end
      end

      def validate_limit
        return if @params['limit'].nil?
        return if Type::Integer.new.errors_for(@params['limit']).empty? && (1..ROW_LIMIT).cover?(limit)

        errors << "limit must be an integer from 1 to #{ROW_LIMIT}"
      end

      def filter_params = @params['filters'].is_a?(::Array) ? @params['filters'] : []
      def limit = @params['limit'].nil? ? ROW_LIMIT : Type::Integer.new.cast(@params['limit'])

      def data_error(error)
        "the database could not use a value: #{error.message.lines.first.sub(/\AERROR:\s*/, '').strip}"
      end

      def filtered(relation) = filters.reduce(relation) { |current, filter| filter.apply(current) }

      def definitions_for(dimensions)
        (dimensions + filters.map(&:dimension)).uniq.to_h { |dimension| [dimension.name, dimension.definition] }
      end

      def request = @params.is_a?(Hash) ? { dataset: @params['dataset']&.to_s } : {}
      def quoted(items) = items.map { |item| "`#{item}`" }.join(', ')
    end
  end
end
