# frozen_string_literal: true

module Portolan
  module Query
    module Guard
      TIMEOUT_MS = 5_000

      def self.run(model, timeout_ms: TIMEOUT_MS)
        result = nil
        outermost = !model.connection.transaction_open?
        model.connection_class_for_self.while_preventing_writes do
          model.transaction(requires_new: true) do
            model.connection.execute("SET LOCAL statement_timeout = #{Integer(timeout_ms)}")
            model.connection.execute("SET LOCAL TIME ZONE 'UTC'")
            model.connection.execute('SET LOCAL transaction_read_only = on') if outermost
            result = yield
            raise ActiveRecord::Rollback
          end
        end
        result
      end
    end
  end
end
