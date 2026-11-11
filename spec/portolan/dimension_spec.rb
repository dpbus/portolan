# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Dimension do
  context 'with no type' do
    subject(:harbor) { described_class.new(:harbor, 'the harbor the voyage set out from') }

    it 'is a string' do
      expect(harbor.type).to eq(:string)
    end

    it 'allows eq and in' do
      expect(harbor.operators).to eq(%w[eq in])
    end

    it 'has no periods' do
      expect(harbor.periods).to be_empty
    end

    it 'is not a time dimension' do
      expect(harbor).not_to be_time
    end

    it 'describes only what it has' do
      expect(harbor.describe).to eq(name: 'harbor', type: 'string',
        description: 'the harbor the voyage set out from', operators: %w[eq in])
    end
  end

  context 'with type: :integer' do
    subject(:crew) { described_class.new(:crew, 'how many sailors were aboard', type: :integer) }

    it 'allows equality and comparisons' do
      expect(crew.operators).to eq(%w[eq in gt lt between])
    end
  end

  context 'with type: :boolean' do
    subject(:charted) { described_class.new(:charted, 'whether the route was on the chart', type: :boolean) }

    it 'allows eq only' do
      expect(charted.operators).to eq(%w[eq])
    end
  end

  context 'with type: :datetime' do
    subject(:departed_at) { described_class.new(:departed_at, 'when the ship set sail', type: :datetime) }

    it 'allows ranges only' do
      expect(departed_at.operators).to eq(%w[gt lt between])
    end

    it 'is a time dimension' do
      expect(departed_at).to be_time
    end

    it 'allows an hourly period' do
      expect(departed_at.periods).to eq(%w[hour day week month quarter year])
    end

    it 'lists its periods when described' do
      expect(departed_at.describe).to include(type: 'datetime', periods: %w[hour day week month quarter year])
    end
  end

  context 'with type: :date' do
    subject(:charted_on) { described_class.new(:charted_on, 'when the coast was charted', type: :date) }

    it 'allows ranges only' do
      expect(charted_on.operators).to eq(%w[gt lt between])
    end

    it 'allows calendar periods only' do
      expect(charted_on.periods).to eq(%w[day week month quarter year])
    end

    it 'lists its periods when described' do
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

    it 'keeps a described bucket condition as its where' do
      expect(fate.buckets['arrived'].where).to be(arrived)
    end

    it 'accepts a bare lambda as the short form of a where' do
      expect(fate.buckets['lost'].where).to be(lost)
    end

    it 'uses the bucket names as values' do
      expect(fate.values).to eq(%w[arrived lost])
    end

    it 'treats a blank bucket description as none' do
      blank = described_class.new(:fate, 'how', buckets: { arrived: { where: -> {}, description: '  ' } })

      expect(blank.describe).not_to have_key(:buckets)
    end

    it 'describes only the buckets that have a description' do
      expect(fate.describe[:buckets]).to eq('arrived' => 'reached its destination')
    end

    it 'carries the same descriptions in its definition' do
      expect(fate.definition).to eq(description: 'how the voyage ended',
        buckets: { 'arrived' => 'reached its destination' })
    end
  end

  context 'with values' do
    subject(:sea) { described_class.new(:sea, 'the sea crossed', values: seas) }

    let(:seas) { %i[adriatic aegean] }

    it 'keeps them as strings' do
      expect(sea.values).to eq(%w[adriatic aegean])
    end

    it 'lists them when described' do
      expect(sea.describe[:values]).to eq(%w[adriatic aegean])
    end

    it 'is not changed by the array it was given' do
      sea
      seas << :baltic

      expect(sea.values).to eq(%w[adriatic aegean])
    end

    it 'cannot be changed through what it hands out' do
      expect(sea.values).to be_frozen
    end
  end

  describe 'shared lists' do
    it 'freezes every operator list' do
      expect(described_class::OPERATORS.values).to all(be_frozen)
    end

    it 'freezes every period list' do
      expect(described_class::PERIODS.values).to all(be_frozen)
    end
  end

  describe 'declaration mistakes' do
    def needs_where(bucket)
      "dimension `fate`: bucket `#{bucket}`: needs a `where` that responds to `call`"
    end

    it 'requires a name' do
      expect { described_class.new(' ', 'the harbor') }.to raise_error(ArgumentError, 'a dimension needs a name')
    end

    it 'rejects an unknown option' do
      expect { described_class.new(:harbor, 'the harbor', joinz: :port) }
        .to raise_error(ArgumentError, 'dimension `harbor`: unknown option `:joinz`')
    end

    it 'shows a string option key as a string' do
      expect { described_class.new(:crew, 'how many', **{ 'type' => :integer }) }
        .to raise_error(ArgumentError, 'dimension `crew`: unknown option `"type"`')
    end

    it 'requires a description' do
      expect { described_class.new(:harbor, ' ') }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end

    it 'treats unicode spaces as no description' do
      expect { described_class.new(:harbor, "\u00A0") }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end

    it 'requires the description to be text' do
      expect { described_class.new(:harbor, %w[the harbor]) }
        .to raise_error(ArgumentError, 'dimension `harbor`: needs a description')
    end

    it 'reports a bad option before looking at buckets' do
      expect { described_class.new(:fate, 'how', bogus: 1, buckets: :arrived) }
        .to raise_error(ArgumentError, 'dimension `fate`: unknown option `:bogus`')
    end

    it 'rejects an unknown type' do
      expect { described_class.new(:departed_at, 'when', type: :time) }
        .to raise_error(ArgumentError, 'dimension `departed_at`: unknown type `:time` ' \
                                       '(allowed: :string, :integer, :boolean, :date, :datetime)')
    end

    it 'requires values to be a list' do
      expect { described_class.new(:sea, 'the sea', values: 'adriatic') }
        .to raise_error(ArgumentError, 'dimension `sea`: values must be a non-empty array')
    end

    it 'requires at least one value' do
      expect { described_class.new(:sea, 'the sea', values: []) }
        .to raise_error(ArgumentError, 'dimension `sea`: values must be a non-empty array')
    end

    it 'keeps buckets as strings' do
      expect { described_class.new(:fate, 'how', type: :integer, buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets are always `:string`')
    end

    it 'keeps buckets apart from values' do
      expect { described_class.new(:fate, 'how', values: %w[arrived], buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets cannot have `values`, `joins`, or `expression`')
    end

    it 'keeps buckets apart from joins' do
      expect { described_class.new(:fate, 'how', joins: :ship, buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets cannot have `values`, `joins`, or `expression`')
    end

    it 'keeps buckets apart from expressions' do
      expect { described_class.new(:fate, 'how', expression: 'x', buckets: { arrived: -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets cannot have `values`, `joins`, or `expression`')
    end

    it 'requires buckets to be a hash' do
      expect { described_class.new(:fate, 'how', buckets: :arrived) }
        .to raise_error(ArgumentError, 'dimension `fate`: buckets must be a hash of names to conditions')
    end

    it 'requires at least one bucket' do
      expect { described_class.new(:fate, 'how', buckets: {}) }
        .to raise_error(ArgumentError, 'dimension `fate`: needs at least one bucket')
    end

    it 'rejects a bucket declared twice' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: -> {}, 'arrived' => -> {} }) }
        .to raise_error(ArgumentError, 'dimension `fate`: bucket `arrived` is declared twice')
    end

    it 'rejects an unknown bucket option' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { where: -> {}, descripton: 'made port' } }) }
        .to raise_error(ArgumentError, 'dimension `fate`: bucket `arrived`: unknown option `:descripton`')
    end

    it 'shows a string bucket key as a string, so the missing symbol is visible' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { 'where' => -> {} } }) }
        .to raise_error(ArgumentError, 'dimension `fate`: bucket `arrived`: unknown option `"where"`')
    end

    it 'rejects a bucket given as a symbol' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: :reached }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'rejects a bucket given as nil' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: nil }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'rejects a bucket with a description but no where' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { description: 'made port' } }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'rejects a where that cannot be called' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: { where: { reached: true } } }) }
        .to raise_error(ArgumentError, needs_where('arrived'))
    end

    it 'names the bad bucket among good ones' do
      expect { described_class.new(:fate, 'how', buckets: { arrived: -> {}, lost: nil }) }
        .to raise_error(ArgumentError, needs_where('lost'))
    end
  end
end
