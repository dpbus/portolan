# frozen_string_literal: true

module Portolan
  module Type
    class Base
      PERIODS = [].freeze

      def operators = self.class::OPERATORS
      def periods = self.class::PERIODS
      def values = nil
      def group(column, _period) = column
      def lower_bound(value) = value
      def upper_bound(value) = value
      def label(value, _period = nil) = value
    end
  end
end
