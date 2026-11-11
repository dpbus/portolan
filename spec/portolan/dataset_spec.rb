# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Dataset do
  subject(:voyages) do
    Class.new(described_class) do
      description 'One row per voyage.'
      model Voyage
      relation { |fleet| Voyage.where(fleet:) }
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
      expect(voyages.relation_for('genoa').where_values_hash).to eq('fleet' => 'genoa')
    end

    it 'calls a relation that takes no context' do
      afloat = Class.new(described_class) do
        model Voyage
        relation { Voyage.where(lost: false) }
      end

      expect(afloat.relation_for('genoa').where_values_hash).to eq('lost' => false)
    end

    it 'uses every row of the model without a relation' do
      expect(Class.new(described_class) { model Voyage }.relation_for(nil).to_sql).to eq(Voyage.all.to_sql)
    end

    it 'raises for a relation of another model' do
      ships = Class.new(described_class) do
        model Voyage
        relation { Ship.all }
      end

      expect { ships.relation_for(nil) }
        .to raise_error(ArgumentError, 'dataset `anonymous`: relation must return a relation of `Voyage`')
    end

    it 'raises for something other than a relation' do
      list = Class.new(described_class) do
        model Voyage
        relation { [] }
      end

      expect { list.relation_for(nil) }
        .to raise_error(ArgumentError, 'dataset `anonymous`: relation must return a relation of `Voyage`')
    end
  end

  describe '.dimension' do
    it 'adds each dimension under its name, in declared order' do
      expect(voyages.dimensions.keys).to eq(%w[harbor departed_at])
    end

    it 'passes its options to the dimension' do
      expect(voyages.dimensions['departed_at'].type.name).to eq('datetime')
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

    context 'without a model' do
      subject(:no_model) do
        Class.new(described_class) do
          description 'One row per voyage.'
          measure :voyages, 'number of voyages'
        end
      end

      it 'raises' do
        expect { no_model.check! }
          .to raise_error(ArgumentError, 'dataset `anonymous`: needs a model, an ActiveRecord class')
      end
    end

    it 'does not look at columns, so it needs no database' do
      voyages.measure :distance_sailed, 'distance sailed', sum: :leauges

      expect { voyages.check! }.not_to raise_error
    end

    context 'with a join through a has_many' do
      it 'raises' do
        ships = Class.new(described_class) do
          description 'One row per ship.'
          model Ship
          dimension :harbor, 'a harbor it sailed from', joins: :voyages, expression: 'voyages.harbor'
          measure :ships, 'number of ships'
        end

        expect { ships.check! }.to raise_error(ArgumentError, /`voyages` is a has_many/)
      end
    end

    context 'with a join through a polymorphic association' do
      it 'raises' do
        voyages.dimension :patron_name, 'who paid for the voyage', joins: :patron, expression: 'patrons.name'

        expect { voyages.check! }.to raise_error(ArgumentError, /`patron` is polymorphic, and Rails cannot join it/)
      end
    end

    context 'with a join through an association the model lacks' do
      it 'raises' do
        voyages.dimension :flag, 'the flag', joins: :shipp, expression: 'ships.flag'

        expect { voyages.check! }.to raise_error(ArgumentError, /`Voyage` has no association `shipp`/)
      end
    end

    context 'without a measure' do
      subject(:no_measure) do
        Class.new(described_class) do
          description 'One row per voyage.'
          model Voyage
        end
      end

      it 'raises' do
        expect { no_measure.check! }.to raise_error(ArgumentError, 'dataset `anonymous`: needs at least one measure')
      end
    end
  end

  describe '.check_columns!' do
    context 'with a measure column the model lacks' do
      it 'raises' do
        voyages.measure :distance, 'distance sailed', sum: :leauges

        expect { voyages.check_columns! }.to raise_error(ArgumentError,
          'dataset `anonymous`: measure `distance`: `leauges` is not a column of `Voyage`')
      end
    end

    context 'with a dimension column the model lacks' do
      it 'raises' do
        voyages.dimension :harbour, 'the harbor'

        expect { voyages.check_columns! }
          .to raise_error(ArgumentError, /dimension `harbour`: `harbour` is not a column of `Voyage`/)
      end
    end

    it 'accepts an aliased attribute' do
      voyages.measure :distance, 'distance sailed', sum: :distance

      expect { voyages.check_columns! }.not_to raise_error
    end

    it 'runs on the first query' do
      voyages.dimension :harbour, 'the harbor'

      expect { voyages.relation_for('genoa') }.to raise_error(ArgumentError, /`harbour` is not a column of `Voyage`/)
    end
  end
end
