# frozen_string_literal: true

module Portolan
  module Type
    class Integer < Base
      OPERATORS = %w[eq in gt lt between].freeze

      def name = 'integer'
      def operators = OPERATORS
      def errors_for(value) = parse(value) ? [] : ["`#{value}` is not an integer"]
      def cast(value) = parse(value)
      def label(value, _period = nil) = value.to_i

      private

      def parse(value)
        return value if value.is_a?(::Integer)

        Kernel.Integer(value, 10, exception: false) if value.is_a?(::String)
      end
    end
  end
end
