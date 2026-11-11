# frozen_string_literal: true

module Portolan
  module Type
    class Date
      OPERATORS = %w[gt lt between].freeze
      PERIODS = %w[day week month quarter year].freeze

      def name = 'date'
      def operators = OPERATORS
      def periods = PERIODS
      def errors_for(value) = parse(value)&.year&.positive? ? [] : ["`#{value}` is not a date; use YYYY-MM-DD"]
      def cast(value) = parse(value)

      private

      def parse(value)
        return unless value.is_a?(::String)

        date = ::Date.strptime(value, '%Y-%m-%d')
        date if date.strftime('%Y-%m-%d') == value
      rescue ::Date::Error
        nil
      end
    end
  end
end
