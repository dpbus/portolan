# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Registry do
  subject(:registry) { described_class.new(voyages:, cargo:) }

  let(:voyages) do
    Class.new(Portolan::Dataset) do
      description 'One row per voyage.'
      relation { :every_voyage }
      dimension :harbor, 'the harbor the voyage set out from'
      measure :voyages, 'number of voyages'
    end
  end

  let(:cargo) do
    Class.new(Portolan::Dataset) do
      description 'One row per cargo hold.'
      relation { :every_hold }
      measure :tons, 'tons of cargo carried', sum: :tons
    end
  end

  describe '.new' do
    it 'raises when not given a hash' do
      expect { described_class.new([voyages]) }
        .to raise_error(ArgumentError, 'registry: needs a hash of names to datasets')
    end

    it 'raises when given no datasets' do
      expect { described_class.new({}) }.to raise_error(ArgumentError, 'registry: needs a hash of names to datasets')
    end

    it 'raises when a name is registered twice' do
      expect { described_class.new(:voyages => voyages, 'voyages' => voyages) }
        .to raise_error(ArgumentError, 'registry: dataset `voyages` is registered twice')
    end

    it 'raises on a name that is not lower snake case' do
      expect { described_class.new('Sea voyages' => voyages) }
        .to raise_error(ArgumentError,
          'registry: dataset name `Sea voyages` must be lower case letters, digits and underscores')
    end

    it 'raises on a name that starts with a digit' do
      expect { described_class.new('1325' => voyages) }
        .to raise_error(ArgumentError,
          'registry: dataset name `1325` must be lower case letters, digits and underscores')
    end

    it 'raises when a value is not a dataset' do
      expect { described_class.new(voyages: String) }
        .to raise_error(ArgumentError, 'registry: dataset `voyages` is not a Portolan::Dataset')
    end

    it 'raises the dataset error for an incomplete dataset' do
      expect { described_class.new(voyages: Class.new(Portolan::Dataset)) }
        .to raise_error(ArgumentError, 'dataset `anonymous`: needs a description')
    end
  end

  describe '#names' do
    it 'returns the names as strings, in registered order' do
      expect(registry.names).to eq(%w[voyages cargo])
    end
  end

  describe '#[]' do
    it 'returns the dataset for a string name' do
      expect(registry['voyages']).to be(voyages)
    end

    it 'returns the dataset for a symbol name' do
      expect(registry[:cargo]).to be(cargo)
    end

    it 'returns nil for an unknown name' do
      expect(registry['voyage']).to be_nil
    end
  end

  describe '#list' do
    it 'returns each name with its description' do
      expect(registry.list).to eq([{ name: 'voyages', description: 'One row per voyage.' },
                                   { name: 'cargo', description: 'One row per cargo hold.' }])
    end
  end

  describe '#describe' do
    it 'includes the name' do
      expect(registry.describe(:voyages)[:name]).to eq('voyages')
    end

    it 'includes what the dataset describes' do
      expect(registry.describe('voyages')).to include(description: 'One row per voyage.',
        measures: [{ name: 'voyages', description: 'number of voyages' }])
    end

    it 'returns nil for an unknown name' do
      expect(registry.describe('voyage')).to be_nil
    end
  end

  it 'is frozen' do
    expect(registry).to be_frozen
  end
end
