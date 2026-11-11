# frozen_string_literal: true

module Portolan
  module Type
    class Date < Base
      OPERATORS = %w[gt lt between].freeze
      PERIODS = %w[day week month quarter year].freeze

      def name = 'date'
      def errors_for(value) = cast(value)&.year&.positive? ? [] : ["`#{value}` is not a date; use YYYY-MM-DD"]
      def group(column, period) = truncate(column, period)
      def truncate(column, period) = Arel::Nodes::NamedFunction.new('CAST', [date_trunc(column, period).as('date')])
      def label(value, _period = nil) = value.strftime('%Y-%m-%d')

      def cast(value)
        return unless value.is_a?(::String)

        date = ::Date.strptime(value, '%Y-%m-%d')
        date if date.strftime('%Y-%m-%d') == value
      rescue ::Date::Error
        nil
      end

      private

      def date_trunc(column, period)
        raise ArgumentError, "period `#{period}` does not apply to #{name}" unless periods.include?(period)

        Arel::Nodes::NamedFunction.new('date_trunc', [Arel::Nodes.build_quoted(period), column])
      end
    end
  end
end
