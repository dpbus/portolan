# frozen_string_literal: true

module Portolan
  module Query
    class Refused < StandardError; end

    module Guard
      TIMEOUT_MS = 5_000
      TIMEOUT_ERROR = 'the query took too long; filter to a shorter period or group by fewer dimensions'

      def self.run(model, timeout_ms: TIMEOUT_MS)
        result = nil
        outermost = !model.connection.transaction_open?
        model.connection_class_for_self.while_preventing_writes do
          model.transaction(requires_new: true) do
            model.connection.execute(settings(timeout_ms, outermost))
            result = yield
            raise ActiveRecord::Rollback
          end
        end
        result
      rescue ActiveRecord::QueryCanceled
        raise Refused, TIMEOUT_ERROR
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.cause.is_a?(PG::DataException)

        raise Refused, "the database could not use a value: #{e.cause.message.lines.first.sub(/\AERROR:\s*/, '').strip}"
      end

      def self.settings(timeout_ms, outermost)
        statements = ["SET LOCAL statement_timeout = #{Integer(timeout_ms)}", "SET LOCAL TIME ZONE 'UTC'"]
        statements << 'SET LOCAL transaction_read_only = on' if outermost
        statements.join('; ')
      end
      private_class_method :settings
    end
  end
end
