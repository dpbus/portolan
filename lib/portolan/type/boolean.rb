# frozen_string_literal: true

module Portolan
  module Type
    class Boolean < Base
      OPERATORS = %w[eq].freeze

      def name = 'boolean'
      def errors_for(value) = [true, false, 'true', 'false'].include?(value) ? [] : ["`#{value}` is not true or false"]
      def cast(value) = [true, 'true'].include?(value)
    end
  end
end
