# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Query::Guard do
  def setting(name) = Voyage.connection.select_value("SHOW #{name}")

  describe '.run' do
    it 'returns the value of the block' do
      expect(described_class.run(Voyage) { :answered }).to eq(:answered)
    end

    it 'limits how long each statement may run' do
      expect(described_class.run(Voyage) { setting('statement_timeout') }).to eq('5s')
    end

    it 'runs in UTC' do
      Voyage.connection.execute("SET LOCAL TIME ZONE 'Europe/Berlin'")

      expect(described_class.run(Voyage) { setting('TimeZone') }).to eq('UTC')
    end

    it 'puts the time zone back afterwards, even inside a transaction' do
      Voyage.connection.execute("SET LOCAL TIME ZONE 'Europe/Berlin'")
      described_class.run(Voyage) { nil }

      expect(setting('TimeZone')).to eq('Europe/Berlin')
    end

    it 'puts the timeout back afterwards, even inside a transaction' do
      described_class.run(Voyage) { nil }

      expect(setting('statement_timeout')).to eq('0')
    end

    it 'leaves an outer transaction able to write' do
      described_class.run(Voyage) { nil }

      expect(setting('transaction_read_only')).to eq('off')
    end

    context 'when it opens the transaction itself' do
      def on_own_connection(&) = Thread.new { Voyage.connection_pool.with_connection(&) }.value

      it 'refuses writes that Rails cannot see, such as advancing a sequence' do
        error = on_own_connection do
          described_class.run(Voyage) { Voyage.connection.select_value("SELECT nextval('voyages_id_seq')") }
        rescue ActiveRecord::StatementInvalid => e
          e
        end

        expect(error.message).to include('read-only transaction')
      end

      it 'leaves the connection able to write afterwards' do
        expect(on_own_connection { described_class.run(Voyage) { nil } || setting('transaction_read_only') })
          .to eq('off')
      end
    end

    it 'refuses writes' do
      expect { described_class.run(Voyage) { Ship.create!(name: 'San Giorgio', flag: 'Genoa') } }
        .to raise_error(ActiveRecord::ReadOnlyError)
    end

    it 'refuses a statement that runs too long, with a message for the caller' do
      expect { described_class.run(Voyage, timeout_ms: 10) { Voyage.connection.execute('SELECT pg_sleep(0.2)') } }
        .to raise_error(Portolan::Query::Refused, described_class::TIMEOUT_ERROR)
    end

    it 'leaves the outer transaction usable after a cancelled statement' do
      expect { described_class.run(Voyage, timeout_ms: 10) { Voyage.connection.execute('SELECT pg_sleep(0.2)') } }
        .to raise_error(Portolan::Query::Refused)

      expect(Voyage.count).to eq(0)
    end
  end
end
