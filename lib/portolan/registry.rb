# frozen_string_literal: true

module Portolan
  class Registry
    NAME = /\A[a-z][a-z0-9_]*\z/

    def initialize(datasets)
      @datasets = build(datasets)
      check_examples!
      freeze
    end

    def names = @datasets.keys
    def [](name) = @datasets[name.to_s]

    def list
      @datasets.map { |name, dataset| { name:, description: dataset.description } }
    end

    def describe(name)
      dataset = self[name]
      { name: name.to_s, **dataset.describe } if dataset
    end

    def aggregate(params, context:)
      Query::Aggregate.new(self, normalize(params), context:).call
    end

    private

    def normalize(params)
      params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
      case params
      when ::Hash then params.to_h { |key, value| [key.to_s, normalize(value)] }
      when ::Array then params.map { |value| normalize(value) }
      when ::Symbol then params.to_s
      else params
      end
    end

    def build(datasets)
      invalid!('needs a hash of names to datasets') unless datasets.is_a?(Hash) && datasets.any?
      duplicate = datasets.keys.map(&:to_s).tally.find { |_, count| count > 1 }&.first
      invalid!("dataset `#{duplicate}` is registered twice") if duplicate

      datasets.to_h { |name, dataset| [name.to_s, checked(name.to_s, dataset)] }.freeze
    end

    def check_examples!
      @datasets.each do |name, dataset|
        dataset.examples.each.with_index(1) do |example, number|
          query = Query::Aggregate.new(self, normalize(example.query).merge('dataset' => name), context: nil)
          next if query.valid?

          invalid!("dataset `#{name}`: example #{number} is not a valid request: #{query.errors.join('; ')}")
        end
      end
    end

    def checked(name, dataset)
      invalid!("dataset name `#{name}` must be lower case letters, digits and underscores") unless name.match?(NAME)
      invalid!("dataset `#{name}` is not a Portolan::Dataset") unless dataset.is_a?(Class) && dataset < Dataset
      dataset.check!
      dataset
    end

    def invalid!(problem)
      raise ArgumentError, "registry: #{problem}"
    end
  end
end
