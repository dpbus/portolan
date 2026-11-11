# frozen_string_literal: true

require 'bigdecimal'

module Portolan
  module Type
    class Decimal < Base
      OPERATORS = %w[eq in gt lt between].freeze

      def name = 'decimal'
      def errors_for(value) = cast(value) ? [] : ["`#{value}` is not a number"]
      def label(value, _period = nil) = value.to_f

      def cast(value)
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
