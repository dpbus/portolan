# frozen_string_literal: true

module Portolan
  class Dataset
    Example = Data.define(:question, :query)

    class << self
      def description(text = nil)
        text.nil? ? @description : @description = text
      end

      def model(model = nil)
        model.nil? ? @model : @model = model
      end

      def relation(&block)
        @relation = block
      end

      def relation_for(context)
        check_columns!
        relation = @relation ? @relation.call(context) : model.all
        return relation if relation.is_a?(ActiveRecord::Relation) && relation.klass <= model

        invalid!("relation must return a relation of `#{model.name}`")
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
        invalid!('needs a model, an ActiveRecord class') unless model.is_a?(Class) && model < ActiveRecord::Base
        invalid!('needs at least one measure') if measure_list.empty?
        dimension_list.each_value { |dimension| check_join!(dimension, model, dimension.joins) if dimension.joins }
      end

      def check_columns!
        return if @columns_checked

        measure_list.each_value { |measure| check_measure_column!(measure) }
        dimension_list.each_value { |dimension| check_dimension_column!(dimension) }
        @columns_checked = true
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

      def check_measure_column!(measure)
        return if measure.column.nil? || attribute?(measure.column)

        invalid!("measure `#{measure.name}`: `#{measure.column}` is not a column of `#{model.name}`")
      end

      def check_dimension_column!(dimension)
        return if dimension.expression || dimension.buckets? || attribute?(dimension.name)

        invalid!("dimension `#{dimension.name}`: `#{dimension.name}` is not a column of `#{model.name}`; " \
                 'add an `expression` to read it another way')
      end

      def check_join!(dimension, from, path)
        case path
        when ::Hash then path.each { |name, rest| check_join!(dimension, check_join!(dimension, from, name), rest) }
        when ::Array then path.each { |name| check_join!(dimension, from, name) }
        else joined_model(dimension, from, path)
        end
      end

      def joined_model(dimension, from, name)
        reflection = from.reflect_on_association(name)
        invalid!("dimension `#{dimension.name}`: `#{from.name}` has no association `#{name}`") unless reflection
        if reflection.polymorphic?
          invalid!("dimension `#{dimension.name}`: `#{name}` is polymorphic, and Rails cannot join it")
        end
        if reflection.collection?
          invalid!("dimension `#{dimension.name}`: `#{name}` is a has_many, and joining it would count rows " \
                   'more than once; see the grain rule')
        end
        reflection.klass
      end

      def attribute?(name) = model.attribute_names.include?(name) || model.attribute_alias?(name)

      def invalid!(problem)
        raise ArgumentError, "dataset `#{name || 'anonymous'}`: #{problem}"
      end
    end
  end
end
