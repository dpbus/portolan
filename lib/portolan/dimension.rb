# frozen_string_literal: true

module Portolan
  class Dimension
    TYPES = %i[string integer boolean date datetime].freeze
    OPTIONS = %i[type values joins expression buckets].freeze
    BUCKET_OPTIONS = %i[where description].freeze
    OPERATORS = {
      string: %w[eq in],
      integer: %w[eq in gt lt between],
      boolean: %w[eq],
      date: %w[gt lt between],
      datetime: %w[gt lt between],
    }.transform_values(&:freeze).freeze
    DATE_PERIODS = %w[day week month quarter year].freeze
    PERIODS = { date: DATE_PERIODS, datetime: ['hour', *DATE_PERIODS].freeze }.freeze

    Bucket = Data.define(:name, :where, :description) do
      def callable? = where.respond_to?(:call)
    end

    attr_reader :name, :description, :type, :joins, :expression, :buckets

    def initialize(name, description, **options)
      @name = name.to_s
      check_options!(options.keys, description)
      @description = description
      @type = options.fetch(:type, :string)
      @values = build_values(options[:values])
      @joins = options[:joins]
      @expression = options[:expression]
      @buckets = build_buckets(options[:buckets])
      check!
      freeze
    end

    def values = buckets ? buckets.keys : @values
    def operators = OPERATORS.fetch(type)
    def periods = PERIODS.fetch(type, [])
    def time? = periods.any?
    def buckets? = !buckets.nil?

    def describe
      {
        name:,
        type: type.to_s,
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

    def build_values(values)
      return if values.nil?

      invalid!('values must be a non-empty array') unless values.is_a?(Array) && values.any?
      values.map(&:to_s).freeze
    end

    def build_buckets(buckets)
      return if buckets.nil?

      invalid!('buckets must be a hash of names to conditions') unless buckets.is_a?(Hash)
      invalid!('needs at least one bucket') if buckets.empty?
      duplicate = buckets.keys.map(&:to_s).tally.find { |_, count| count > 1 }&.first
      invalid!("bucket `#{duplicate}` is declared twice") if duplicate

      buckets.to_h { |bucket_name, options| [bucket_name.to_s, build_bucket(bucket_name.to_s, options)] }.freeze
    end

    def build_bucket(bucket_name, options)
      options = { where: options } unless options.is_a?(Hash)
      unknown = options.keys - BUCKET_OPTIONS
      invalid!("bucket `#{bucket_name}`: unknown option `#{unknown.map(&:inspect).join('`, `')}`") if unknown.any?

      bucket = Bucket.new(name: bucket_name, where: options[:where], description: options[:description].presence)
      invalid!("bucket `#{bucket_name}`: needs a `where` that responds to `call`") unless bucket.callable?
      bucket
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

    def check!
      unless TYPES.include?(type)
        invalid!("unknown type `#{type.inspect}` (allowed: #{TYPES.map(&:inspect).join(', ')})")
      end
      check_buckets! if buckets?
    end

    def check_buckets!
      invalid!('buckets are always `:string`') unless type == :string
      invalid!('buckets cannot have `values`, `joins`, or `expression`') if @values || joins || expression
    end

    def invalid!(problem)
      raise ArgumentError, "dimension `#{name}`: #{problem}"
    end
  end
end
