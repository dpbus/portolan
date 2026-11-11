# frozen_string_literal: true

module Portolan
  class Measure
    AGGREGATES = %i[count_distinct sum average].freeze

    attr_reader :name, :description, :aggregate, :column

    def initialize(name, description, **options)
      @name = name.to_s
      check!(options, description)
      @description = description
      @aggregate, @column = options.first || [:count, nil]
      @column = @column&.to_s
      freeze
    end

    def call(scope)
      case aggregate
      when :count then scope.count
      when :count_distinct then scope.distinct.count(column.to_sym)
      when :sum then scope.sum(column.to_sym)
      when :average then scope.average(column.to_sym)
      end
    end

    def describe = { name:, description: }
    def label(value) = value.is_a?(::BigDecimal) ? value.to_f : value

    private

    def check!(options, description)
      raise ArgumentError, 'a measure needs a name' if name.blank?

      unknown = options.keys - AGGREGATES
      invalid!("unknown option #{Portolan.quoted(unknown.map(&:inspect))}") if unknown.any?
      invalid!('needs a description') unless description.is_a?(String) && description.present?
      invalid!("takes one of #{Portolan.quoted(AGGREGATES)}, not several") if options.size > 1

      options.each do |kind, column|
        next if (column.is_a?(Symbol) || column.is_a?(String)) && column.present?

        invalid!("`#{kind}` needs a column name")
      end
    end

    def invalid!(problem)
      raise ArgumentError, "measure `#{name}`: #{problem}"
    end
  end
end
