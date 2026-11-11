# frozen_string_literal: true

module Portolan
  class Dimension
    class Bucket
      OPTIONS = %i[where description].freeze

      attr_reader :name, :where, :description

      def initialize(name, options)
        @name = name.to_s
        options = { where: options } unless options.is_a?(Hash)
        check!(options)
        @where = options[:where]
        @description = options[:description].presence
        freeze
      end

      def apply(scope)
        primary_key = scope.klass.primary_key
        raise ArgumentError, composite_key_message(scope.klass) unless primary_key.is_a?(::String)

        scope.where(primary_key => where.call.select(primary_key))
      end

      private

      def check!(options)
        unknown = options.keys - OPTIONS
        invalid!("unknown option `#{unknown.map(&:inspect).join('`, `')}`") if unknown.any?
        invalid!('needs a `where` that responds to `call`') unless options[:where].respond_to?(:call)
      end

      def composite_key_message(model)
        keys = Array(model.primary_key).map { |key| "`#{key}`" }.join(', ')
        "bucket `#{name}`: needs a model with a single-column primary key; `#{model.table_name}` has #{keys}"
      end

      def invalid!(problem)
        raise ArgumentError, "bucket `#{name}`: #{problem}"
      end
    end
  end
end
