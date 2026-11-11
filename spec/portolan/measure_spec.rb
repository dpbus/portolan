# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Measure do
  let(:scope) { instance_double(ActiveRecord::Relation, count: 12, sum: 840, average: 31.5) }

  context 'with count' do
    subject(:voyages) { described_class.new(:voyages, 'number of voyages') }

    it 'has the count aggregate' do
      expect(voyages.aggregate).to eq(:count)
    end

    it 'returns the row count of the scope' do
      expect(voyages.call(scope)).to eq(12)
    end
  end

  context 'with count_distinct' do
    subject(:ships) { described_class.new(:ships, 'number of ships that sailed', count_distinct: :ship_id) }

    let(:distinct) { instance_double(ActiveRecord::Relation, count: 3) }

    before { allow(scope).to receive(:distinct).and_return(distinct) }

    it 'returns the distinct count of its column' do
      expect(ships.call(scope)).to eq(3)
    end

    it 'passes its column to count' do
      ships.call(scope)

      expect(distinct).to have_received(:count).with(:ship_id)
    end
  end

  context 'with sum' do
    subject(:leagues) { described_class.new(:leagues, 'distance sailed, in leagues', sum: :leagues) }

    it 'returns the sum of its column' do
      expect(leagues.call(scope)).to eq(840)
    end

    it 'passes its column to sum' do
      leagues.call(scope)

      expect(scope).to have_received(:sum).with(:leagues)
    end
  end

  context 'with average' do
    subject(:crew_size) { described_class.new(:crew_size, 'average crew aboard', average: 'crew') }

    it 'stores the column as a string' do
      expect(crew_size.column).to eq('crew')
    end

    it 'passes its column to average' do
      crew_size.call(scope)

      expect(scope).to have_received(:average).with(:crew)
    end
  end

  describe '#describe' do
    it 'returns only the name and description' do
      expect(described_class.new(:leagues, 'distance sailed', sum: :leagues).describe)
        .to eq(name: 'leagues', description: 'distance sailed')
    end
  end

  describe 'checks' do
    it 'raises without a name' do
      expect { described_class.new(' ', 'number of voyages') }.to raise_error(ArgumentError, 'a measure needs a name')
    end

    it 'raises on an unknown option' do
      expect { described_class.new(:leagues, 'distance', total: :leagues) }
        .to raise_error(ArgumentError, 'measure `leagues`: unknown option `:total`')
    end

    it 'raises without a description' do
      expect { described_class.new(:leagues, ' ', sum: :leagues) }
        .to raise_error(ArgumentError, 'measure `leagues`: needs a description')
    end

    it 'raises when the description is not text' do
      expect { described_class.new(:leagues, :distance, sum: :leagues) }
        .to raise_error(ArgumentError, 'measure `leagues`: needs a description')
    end

    it 'raises when given more than one aggregate' do
      expect { described_class.new(:leagues, 'distance', sum: :leagues, average: :leagues) }
        .to raise_error(ArgumentError,
          'measure `leagues`: takes one of `count_distinct`, `sum`, `average`, not several')
    end

    it 'raises when the column name is blank' do
      expect { described_class.new(:leagues, 'distance', sum: '') }
        .to raise_error(ArgumentError, 'measure `leagues`: `sum` needs a column name')
    end

    it 'raises when the column name is not a symbol or string' do
      expect { described_class.new(:leagues, 'distance', sum: 3) }
        .to raise_error(ArgumentError, 'measure `leagues`: `sum` needs a column name')
    end
  end
end
