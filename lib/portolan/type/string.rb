# frozen_string_literal: true

module Portolan
  module Type
    class String < Base
      OPERATORS = %w[eq in].freeze

      def name = 'string'
      def operators = OPERATORS
      def errors_for(value) = value.is_a?(::String) || value.is_a?(::Numeric) ? [] : ["`#{value}` is not text"]
      def cast(value) = value.to_s
    end
  end
end
