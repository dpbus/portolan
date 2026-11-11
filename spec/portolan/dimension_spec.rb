# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Dimension do
  context 'with no type' do
    subject(:harbor) { described_class.new(:harbor, 'the harbor the voyage set out from') }

    it 'defaults to the string type' do
      expect(harbor.type).to be_an_instance_of(Portolan::Type::String)
    end

    it 'allows the eq and in operators' do
      expect(harbor.operators).to eq(%w[eq in])
    end

    it 'returns no periods' do
      expect(harbor.periods).to be_empty
    end

    it 'is not a time dimension' do
      expect(harbor).not_to be_time
    end

    it 'returns only its name, type, description and operators from describe' do
      expect(harbor.describe).to eq(name: 'harbor', type: 'string',
        description: 'the harbor the voyage set out from', operators: %w[eq in])
    end
  end

  context 'with type: :integer' do
    subject(:crew) { described_class.new(:crew, 'how many sailors were aboard', type: :integer) }

    it 'allows equality and comparison operators' do
      expect(crew.operators).to eq(%w[eq in gt lt between])
    end
  end

  context 'with type: :boolean' do
    subject(:charted) { described_class.new(:charted, 'whether the route was on the chart', type: :boolean) }

    it 'allows the eq operator only' do
      expect(charted.operators).to eq(%w[eq])
    end
  end

  context 'with type: :datetime' do
    subject(:departed_at) { described_class.new(:departed_at, 'when the ship set sail', type: :datetime) }

    it 'allows range operators only' do
      expect(departed_at.operators).to eq(%w[gt lt between])
    end

    it 'is a time dimension' do
      expect(departed_at).to be_time
    end

    it 'allows hour and the calendar periods' do
      expect(departed_at.periods).to eq(%w[hour day week month quarter year])
    end

    it 'includes its periods in describe' do
      expect(departed_at.describe).to include(type: 'datetime', periods: %w[hour day week month quarter year])
    end
  end

  context 'with type: :date' do
    subject(:charted_on) { described_class.new(:charted_on, 'when the coast was charted', type: :date) }

    it 'allows range operators only' do
      expect(charted_on.operators).to eq(%w[gt lt between])
    end

    it 'allows calendar periods only' do
      expect(charted_on.periods).to eq(%w[day week month quarter year])
    end

    it 'includes its periods in describe' do
      expect(charted_on.describe).to include(type: 'date', periods: %w[day week month quarter year])
    end
  end

  context 'with buckets' do
    subject(:fate) do
      described_class.new(:fate, 'how the voyage ended', buckets: {
        arrived: { where: arrived, description: 'reached its destination' },
        lost:,
      })
    end

    let(:arrived) { -> {} }
    let(:lost) { -> {} }

    it 'uses an enum of the bucket names as its type' do
      expect(fate.type.values).to eq(%w[arrived lost])
    end

    it "stores the given condition as the bucket's where" do
      expect(fate.buckets['arrived'].where).to be(arrived)
    end

    it "stores a bare lambda as the bucket's where" do
      expect(fate.buckets['lost'].where).to be(lost)
    end

    it 'returns the bucket names as its values' do
      expect(fate.values).to eq(%w[arrived lost])
    end

    it 'leaves a blank bucket description out of describe' do
      blank = described_class.new(:fate, 'how', buckets: { arrived: { where: -> {}, description: '  ' } })

      expect(blank.describe).not_to have_key(:buckets)
    end

    it 'includes only described buckets in describe' do
      expect(fate.describe[:buckets]).to eq('arrived' => 'reached its destination')
    end

    it 'includes the same bucket descriptions in its definition' do
      expect(fate.definition).to eq(description: 'how the voyage ended',
        buckets: { 'arrived' => 'reached its destination' })
    end
  end

  context 'with values' do
    subject(:sea) { described_class.new(:sea, 'the sea crossed', values: seas) }

    let(:seas) { %i[adriatic aegean] }

    it 'uses an enum of its values as its type' do
      expect(sea.type).to be_an_instance_of(Portolan::Type::Enum)
    end

    it 'describes its type as a string' do
      expect(sea.describe[:type]).to eq('string')
    end

    it 'converts the values to strings' do
      expect(sea.values).to eq(%w[adriatic aegean])
    end

    it 'includes the values in describe' do
      expect(sea.describe[:values]).to eq(%w[adriatic aegean])
    end

    it 'ignores later changes to the array it was given' do
      sea
      seas << :baltic

      expect(sea.values).to eq(%w[adriatic aegean])
    end

    it 'returns frozen values' do
      expect(sea.values).to be_frozen
    end
  end

  describe '#join' do
    it 'adds a left join for its association' do
      captain = described_class.new(:captain, 'who commanded', joins: :captain, expression: 'captains.name')

      expect(captain.join(Voyage.all).to_sql).to include('LEFT OUTER JOIN "captains"')
    end

    it 'returns the scope unchanged without a join' do
      scope = Voyage.all

      expect(described_class.new(:harbor, 'the harbor').join(scope)).to be(scope)
    end
  end

  describe '#column' do
    it "returns the dataset table's column for a plain dimension" do
      expect(described_class.new(:harbor, 'the harbor').column(Voyage.all))
        .to have_attributes(relation: Voyage.arel_table, name: 'harbor')
    end

    it 'returns the expression in parentheses' do
      long_voyage = described_class.new(:long_voyage, 'over 1000 leagues', type: :boolean,
        expression: 'voyages.leagues > 1000')

      expect(long_voyage.column(Voyage.all).to_sql).to eq('(voyages.leagues > 1000)')
    end
  end

  describe 'checks' do
    def needs_where(bucket)
      "dimension `fate`: bucket `#{bucket}`: needs a `where` that responds to `call`"
    end

    it 'raises without a name' do
      expect { described_class.new(' ', 'the harbor') }.to raise_error(ArgumentError, 'a dimension needs a name')
    end

    it 'raises on an unknown option' do
      expect { described_class.new(:harbor, 'the harbor', joinz: :port) }
        .to raise_error(ArgumentError, 'dimension `harbor`: unknown option `:joinz`')
    end

    it 'raises showing a string option key as a string' do
      expect { described_class.new(:crew, 'how many', **{ 'type' => :integer }) }
        .to raise_error(ArgumentError, 'dimension `crew`: unknown option `"type"`')
    end

    it 'raises without a description' do
      expect { described_class.new(:harbor, ' ') }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end

    it 'raises when the description is only unicode spaces' do
      expect { described_class.new(:harbor, "\u00A0") }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end

    it 'raises when the description is not text' do
      expect { described_class.new(:harbor, %w[the harbor]) }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end

    it 'raises on a bad option before checking buckets' do
      expect { described_class.new(:fate, 'how', bogus: 1, buckets: :arrived) }
        .to raise_error(ArgumentError, 'dimension `fate`: unknown option `:bogus`')
    end

    it 'raises on an unknown type' do
      expect { described_class.new(:departed_at, 'when', type: :time) }
        .to raise_error(ArgumentError, 'dimension `departed_at`: unknown type `:time` ' \
                                       '(allowed: :string, :integer, :decimal, :boolean, :date, :datetime)')
    end

    it 'raises when values is not an array' do
      expect { described_class.new(:sea, 'the sea', values: 'adriatic') }
        .to raise_error(ArgumentError, 'dimension `sea`: values must be a non-empty array')
    end

    it 'raises when values are given for a type other than string' do
      expect { described_class.new(:crew, 'how many', type: :integer, values: [26, 40]) }
        .to raise_error(ArgumentError, 'dimension `crew`: values are only for `:string`')
    end

    it 'raises when values is empty' do
      expect { described_class.new(:sea, 'the sea', values: []) }
        .to raise_error(ArgumentError, 'dimension `sea`: values must be a non-empty array')
    end

    it 'raises when buckets have a non-string type' do
      expect { described_class.new(:fate, 'how', type: :integer, buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets are always `:string`')
    end

    it 'raises when buckets are combined with values' do
      expect { described_class.new(:fate, 'how', values: %w[arrived], buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets cannot have `values`, `joins`, or `expression`')
    end

    it 'raises when buckets are combined with joins' do
      expect { described_class.new(:fate, 'how', joins: :ship, buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets cannot have `values`, `joins`, or `expression`')
    end

    it 'raises when buckets are combined with an expression' do
      expect { described_class.new(:fate, 'how', expression: 'x', buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets cannot have `values`, `joins`, or `expression`')
    end

    it 'raises when a join has no expression to read' do
      expect { described_class.new(:flag, 'the flag', joins: :ship) }
        .to raise_error(ArgumentError, 'dimension `flag`: `joins` needs an `expression` naming the joined column')
    end

    it 'raises when buckets is not a hash' do
      expect { described_class.new(:fate, 'how', buckets: :arrived) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets must be a hash of names to conditions')
    end

    it 'raises when buckets is empty' do
      expect { described_class.new(:fate, 'how', buckets: {}) }
        .to raise_error(ArgumentError, 'dimension `fate`: needs at least one bucket')
    end

    it 'raises when a bucket name is declared twice' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: -> {}, 'arrived' => -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: bucket `arrived` is declared twice')
    end

    it 'raises on an unknown bucket option' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { where: -> {}, descripton: 'made port' } }) }
        .to raise_error(ArgumentError, 'dimension `fate`: bucket `arrived`: unknown option `:descripton`')
    end

    it 'raises showing a string bucket key as a string' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { 'where' => -> {} } }) }
        .to raise_error(ArgumentError, 'dimension `fate`: bucket `arrived`: unknown option `"where"`')
    end

    it 'raises when a bucket is a symbol' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: :reached }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'raises when a bucket is nil' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: nil }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'raises when a bucket has a description but no where' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { description: 'made port' } }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'raises when a where cannot be called' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { where: { reached: true } } }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'raises naming the bad bucket among good ones' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: -> {}, lost: nil }) }
        .to raise_error(ArgumentError, needs_where('lost'))
    end
  end
end
