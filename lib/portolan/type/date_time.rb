# frozen_string_literal: true

module Portolan
  module Type
    class DateTime < Date
      PERIODS = ['hour', *Date::PERIODS].freeze

      def name = 'datetime'
      def periods = PERIODS
      def lower_bound(date) = ::Time.utc(date.year, date.month, date.day)
      def upper_bound(date) = lower_bound(date).end_of_day
    end
  end
end
