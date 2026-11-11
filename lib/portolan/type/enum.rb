# frozen_string_literal: true

module Portolan
  module Type
    class Enum < String
      attr_reader :values

      def initialize(values)
        super()
        @values = values.map(&:to_s).freeze
        freeze
      end

      def errors_for(value)
        errors = super
        return errors if errors.any? || values.include?(value.to_s)

        ["unknown value `#{value}`; allowed: #{Portolan.quoted(values)}"]
      end
    end
  end
end
