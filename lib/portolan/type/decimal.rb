# frozen_string_literal: true

require 'bigdecimal'

module Portolan
  module Type
    class Decimal < Base
      OPERATORS = %w[eq in gt lt between].freeze

      def name = 'decimal'
      def operators = OPERATORS
      def errors_for(value) = parse(value) ? [] : ["`#{value}` is not a number"]
      def cast(value) = parse(value)
      def label(value, _period = nil) = value.to_f

      private

      def parse(value)
        number = case value
                 when ::Integer, ::BigDecimal then BigDecimal(value)
                 when ::Float then BigDecimal(value.to_s)
                 when ::String then BigDecimal(value, exception: false)
                 end
        number if number&.finite?
      end
    end
  end
end
