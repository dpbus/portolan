# frozen_string_literal: true

module Portolan
  module Type
    class Integer < Base
      OPERATORS = %w[eq in gt lt between].freeze
      RANGE = (-(2**63))..((2**63) - 1)

      def name = 'integer'
      def operators = OPERATORS
      def cast(value) = parse(value)
      def label(value, _period = nil) = value.to_i

      def errors_for(value)
        number = parse(value)
        return ["`#{value}` is not an integer"] unless number
        return [] if RANGE.cover?(number)

        ["`#{value}` is outside the integer range, #{RANGE.min} to #{RANGE.max}"]
      end

      private

      def parse(value)
        return value if value.is_a?(::Integer)

        Kernel.Integer(value, 10, exception: false) if value.is_a?(::String)
      end
    end
  end
end
