# frozen_string_literal: true

module Portolan
  module Query
    class Result
      attr_reader :request, :rows, :definitions, :total_rows, :errors

      def initialize(request:, rows: [], definitions: {}, total_rows: rows.size, errors: [])
        @request = request.compact.freeze
        @rows = rows.freeze
        @definitions = definitions.freeze
        @total_rows = total_rows
        @errors = errors.freeze
        freeze
      end

      def success? = errors.empty?
      def truncated? = total_rows > rows.size

      def notes
        messages = []
        messages << truncation_note if truncated?
        messages << 'Periods with no rows are omitted.' if request[:period] && success?
        messages
      end

      def to_h
        details = { truncated: truncated?, notes:, definitions:, errors: }.compact_blank
        success? ? { **request, rows:, **details } : { **request, **details }
      end

      private

      def truncation_note
        "Showing the #{request[:period] ? 'newest' : 'largest'} #{rows.size} of #{total_rows} rows."
      end
    end
  end
end
