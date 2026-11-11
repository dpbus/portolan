# frozen_string_literal: true

module Portolan
  module Type
    class DateTime < Date
      PERIODS = ['hour', *Date::PERIODS].freeze

      def name = 'datetime'
      def periods = PERIODS
      def lower_bound(date) = ::Time.utc(date.year, date.month, date.day)
      def upper_bound(date) = lower_bound(date).end_of_day
      def truncate(column, period) = date_trunc(column, period)
      def label(value, period = nil) = period == 'hour' ? value.utc.strftime('%Y-%m-%dT%H:00Z') : super(value.utc)
    end
  end
end
