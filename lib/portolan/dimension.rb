# frozen_string_literal: true

module Portolan
  class Dimension
    OPTIONS = %i[type values joins expression buckets].freeze

    attr_reader :name, :description, :type, :joins, :expression, :buckets

    def initialize(name, description, **options)
      @name = name.to_s
      check_options!(options.keys, description)
      @description = description
      @joins = options[:joins]
      @expression = options[:expression]
      @buckets = build_buckets(options[:buckets])
      @type = build_type(options)
      freeze
    end

    def values = type.is_a?(Type::Enum) ? type.values : nil
    def operators = type.operators
    def periods = type.periods
    def time? = periods.any?
    def buckets? = !buckets.nil?

    def describe
      {
        name:,
        type: type.name,
        description:,
        operators:,
        values:,
        periods: (periods if time?),
        buckets: (bucket_descriptions.presence if buckets?),
      }.compact
    end

    def definition
      { description:, buckets: (bucket_descriptions.presence if buckets?) }.compact
    end

    private

    def build_type(options)
      type_name = options.fetch(:type, :string)
      unless Type::NAMES.include?(type_name)
        invalid!("unknown type `#{type_name.inspect}` (allowed: #{Type::NAMES.map(&:inspect).join(', ')})")
      end
      return bucket_type(type_name, options) if buckets?
      return Type.for(type_name) if options[:values].nil?

      invalid!('values must be a non-empty array') unless options[:values].is_a?(Array) && options[:values].any?
      invalid!('values are only for `:string`') unless type_name == :string
      Type::Enum.new(options[:values])
    end

    def bucket_type(type_name, options)
      invalid!('buckets are always `:string`') unless type_name == :string
      invalid!('buckets cannot have `values`, `joins`, or `expression`') if options[:values] || joins || expression
      Type::Enum.new(buckets.keys)
    end

    def build_buckets(bucket_options)
      return if bucket_options.nil?

      invalid!('buckets must be a hash of names to conditions') unless bucket_options.is_a?(Hash)
      invalid!('needs at least one bucket') if bucket_options.empty?
      duplicate = bucket_options.keys.map(&:to_s).tally.find { |_, count| count > 1 }&.first
      invalid!("bucket `#{duplicate}` is declared twice") if duplicate

      bucket_options.to_h { |bucket_name, options| [bucket_name.to_s, build_bucket(bucket_name, options)] }.freeze
    end

    def build_bucket(bucket_name, options)
      Bucket.new(bucket_name, options)
    rescue ArgumentError => e
      invalid!(e.message)
    end

    def bucket_descriptions
      buckets.values.select(&:description).to_h { |bucket| [bucket.name, bucket.description] }
    end

    def check_options!(option_names, description)
      raise ArgumentError, 'a dimension needs a name' if name.blank?

      unknown = option_names - OPTIONS
      invalid!("unknown option `#{unknown.map(&:inspect).join('`, `')}`") if unknown.any?
      invalid!('needs a description') unless description.is_a?(String) && description.present?
    end

    def invalid!(problem)
      raise ArgumentError, "dimension `#{name}`: #{problem}"
    end
  end
end
