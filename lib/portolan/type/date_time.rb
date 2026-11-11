# frozen_string_literal: true

module Portolan
  module Type
    class DateTime < Date
      PERIODS = ['hour', *Date::PERIODS].freeze

      def name = 'datetime'
      def periods = PERIODS
    end
  end
end
