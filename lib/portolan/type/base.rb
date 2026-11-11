# frozen_string_literal: true

module Portolan
  module Type
    class Base
      PERIODS = [].freeze

      def periods = PERIODS
      def lower_bound(value) = value
      def upper_bound(value) = value
    end
  end
end
