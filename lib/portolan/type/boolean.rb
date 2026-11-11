# frozen_string_literal: true

module Portolan
  module Type
    class Boolean
      OPERATORS = %w[eq].freeze
      PERIODS = [].freeze

      def name = 'boolean'
      def operators = OPERATORS
      def periods = PERIODS
      def errors_for(value) = [true, false, 'true', 'false'].include?(value) ? [] : ["`#{value}` is not true or false"]
      def cast(value) = [true, 'true'].include?(value)
    end
  end
end
