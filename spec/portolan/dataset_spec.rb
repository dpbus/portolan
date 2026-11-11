# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Dataset do
  subject(:voyages) do
    Class.new(described_class) do
      description 'One row per voyage.'
      relation { |context| [:voyages_for, context] }
      dimension :harbor, 'the harbor the voyage set out from'
      dimension :departed_at, 'when the ship set sail', type: :datetime
      measure :voyages, 'number of voyages'
      measure :leagues, 'distance sailed, in leagues', sum: :leagues
      example 'How many voyages left each harbor?', { measure: 'voyages', group_by: %w[harbor] }
    end
  end

  describe '.description' do
    it 'returns the declared description' do
      expect(voyages.description).to eq('One row per voyage.')
    end
  end

  describe '.relation_for' do
    it 'calls the relation with the context' do
      expect(voyages.relation_for(:genoese_fleet)).to eq(%i[voyages_for genoese_fleet])
    end

    it 'calls a relation that takes no context' do
      every_voyage = Class.new(described_class) { relation { :every_voyage } }

      expect(every_voyage.relation_for(:genoese_fleet)).to eq(:every_voyage)
    end
  end

  describe '.dimension' do
    it 'adds each dimension under its name, in declared order' do
      expect(voyages.dimensions.keys).to eq(%w[harbor departed_at])
    end

    it 'passes its options to the dimension' do
      expect(voyages.dimensions['departed_at'].type).to eq(:datetime)
    end

    it 'raises when a dimension name is declared twice' do
      expect { Class.new(described_class) { 2.times { dimension :harbor, 'the harbor' } } }
        .to raise_error(ArgumentError, 'dataset `anonymous`: dimension `harbor` is declared twice')
    end

    it 'raises the dimension error for a bad declaration' do
      expect { Class.new(described_class) { dimension :harbor, ' ' } }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end
  end

  describe '.measure' do
    it 'adds each measure under its name, in declared order' do
      expect(voyages.measures.keys).to eq(%w[voyages leagues])
    end

    it 'passes its options to the measure' do
      expect(voyages.measures['leagues'].aggregate).to eq(:sum)
    end

    it 'raises when a measure has the name of a dimension' do
      expect do
        Class.new(described_class) do
          dimension :crew, 'how many sailors were aboard'
          measure :crew, 'all sailors aboard', sum: :crew
        end
      end.to raise_error(ArgumentError, 'dataset `anonymous`: `crew` names both a dimension and a measure')
    end

    it 'raises when a measure name is declared twice' do
      expect { Class.new(described_class) { 2.times { measure :voyages, 'number of voyages' } } }
        .to raise_error(ArgumentError, 'dataset `anonymous`: measure `voyages` is declared twice')
    end

    it 'raises the measure error for a bad declaration' do
      expect { Class.new(described_class) { measure :leagues, 'distance', sum: '' } }
        .to raise_error(ArgumentError, 'measure `leagues`: `sum` needs a column name')
    end
  end

  describe '.example' do
    it 'adds the question and query' do
      expect(voyages.examples.map(&:to_h)).to eq([{ question: 'How many voyages left each harbor?',
                                                    query: { measure: 'voyages', group_by: %w[harbor] } }])
    end

    it 'freezes the query' do
      expect(voyages.examples.first.query).to be_frozen
    end
  end

  describe '.dimensions' do
    it 'returns a frozen hash' do
      expect(voyages.dimensions).to be_frozen
    end

    it 'excludes dimensions declared on other datasets' do
      Class.new(described_class) { dimension :cargo, 'what the ship carried' }

      expect(voyages.dimensions.keys).not_to include('cargo')
    end
  end

  describe '.measures' do
    it 'returns a frozen hash' do
      expect(voyages.measures).to be_frozen
    end
  end

  describe '.examples' do
    it 'returns a frozen array' do
      expect(voyages.examples).to be_frozen
    end
  end

  describe '.describe' do
    it 'includes the description' do
      expect(voyages.describe[:description]).to eq('One row per voyage.')
    end

    it 'includes the name and type of each dimension' do
      expect(voyages.describe[:dimensions].map { |dimension| dimension.values_at(:name, :type) })
        .to eq([%w[harbor string], %w[departed_at datetime]])
    end

    it 'includes the name of each measure' do
      expect(voyages.describe[:measures].map { |measure| measure[:name] }).to eq(%w[voyages leagues])
    end

    it 'includes the examples' do
      expect(voyages.describe[:examples].first[:question]).to eq('How many voyages left each harbor?')
    end
  end

  describe '.check!' do
    it 'does not raise for a complete dataset' do
      expect { voyages.check! }.not_to raise_error
    end

    context 'without a description' do
      it 'raises, calling an anonymous dataset anonymous' do
        voyages.description(' ')

        expect { voyages.check! }.to raise_error(ArgumentError, 'dataset `anonymous`: needs a description')
      end

      it 'raises, naming the dataset by its class' do
        stub_const('Voyages', Class.new(described_class))

        expect { Voyages.check! }.to raise_error(ArgumentError, 'dataset `Voyages`: needs a description')
      end
    end

    context 'without a relation' do
      subject(:no_relation) do
        Class.new(described_class) do
          description 'One row per voyage.'
          measure :voyages, 'number of voyages'
        end
      end

      it 'raises' do
        expect { no_relation.check! }.to raise_error(ArgumentError, 'dataset `anonymous`: needs a relation')
      end
    end

    context 'without a measure' do
      subject(:no_measure) do
        Class.new(described_class) do
          description 'One row per voyage.'
          relation { :every_voyage }
        end
      end

      it 'raises' do
        expect { no_measure.check! }.to raise_error(ArgumentError, 'dataset `anonymous`: needs at least one measure')
      end
    end
  end
end
