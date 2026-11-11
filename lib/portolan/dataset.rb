# frozen_string_literal: true

module Portolan
  class Dataset
    Example = Data.define(:question, :query)

    class << self
      def description(text = nil)
        text.nil? ? @description : @description = text
      end

      def relation(&block)
        @relation = block
      end

      def relation_for(context)
        @relation.call(context)
      end

      def dimension(name, description, **options)
        add(dimension_list, Dimension.new(name, description, **options), 'dimension')
      end

      def measure(name, description, **options)
        add(measure_list, Measure.new(name, description, **options), 'measure')
      end

      def example(question, query)
        example_list << Example.new(question:, query: query.freeze)
      end

      def dimensions = dimension_list.dup.freeze
      def measures = measure_list.dup.freeze
      def examples = example_list.dup.freeze

      def describe
        {
          description:,
          dimensions: dimension_list.values.map(&:describe),
          measures: measure_list.values.map(&:describe),
          examples: example_list.map(&:to_h),
        }
      end

      def check!
        invalid!('needs a description') unless description.is_a?(String) && description.present?
        invalid!('needs a relation') unless @relation
        invalid!('needs at least one measure') if measure_list.empty?
      end

      private

      def dimension_list = @dimension_list ||= {}
      def measure_list = @measure_list ||= {}
      def example_list = @example_list ||= []

      def add(list, item, kind)
        invalid!("#{kind} `#{item.name}` is declared twice") if list.key?(item.name)
        invalid!("`#{item.name}` names both a dimension and a measure") if declared_names.include?(item.name)
        list[item.name] = item
      end

      def declared_names = dimension_list.keys + measure_list.keys

      def invalid!(problem)
        raise ArgumentError, "dataset `#{name || 'anonymous'}`: #{problem}"
      end
    end
  end
end
