# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Dimension::Bucket do
  let(:condition) { -> {} }

  context 'with a condition alone' do
    subject(:lost) { described_class.new(:lost, condition) }

    it 'stores the name as a string' do
      expect(lost.name).to eq('lost')
    end

    it 'stores the condition as its where' do
      expect(lost.where).to be(condition)
    end

    it 'has no description' do
      expect(lost.description).to be_nil
    end
  end

  context 'with a where and a description' do
    subject(:arrived) { described_class.new(:arrived, { where: condition, description: 'reached its destination' }) }

    it 'stores the condition as its where' do
      expect(arrived.where).to be(condition)
    end

    it 'stores the description' do
      expect(arrived.description).to eq('reached its destination')
    end

    it 'is frozen' do
      expect(arrived).to be_frozen
    end
  end

  context 'with a blank description' do
    it 'stores no description' do
      expect(described_class.new(:arrived, { where: condition, description: '  ' }).description).to be_nil
    end
  end

  describe '#apply' do
    subject(:lost) { described_class.new(:lost, -> { Voyage.where(lost: true) }) }

    before do
      ship = Ship.create!(name: 'San Giorgio', flag: 'Genoa')
      %w[genoa venice].each do |fleet|
        [true, false].each do |lost|
          ship.voyages.create!(fleet:, lost:, harbor: "#{fleet} #{lost}", crew: 26, leagues: 900,
            departed_at: Time.utc(1325, 8, 3))
        end
      end
    end

    it 'keeps the rows of the scope that are in the bucket' do
      expect(lost.apply(Voyage.where(fleet: 'genoa')).pluck(:harbor)).to eq(['genoa true'])
    end

    it 'never adds rows the scope left out' do
      expect(lost.apply(Voyage.where(lost: false))).to be_empty
    end
  end

  describe 'checks' do
    it 'raises on an unknown option' do
      expect { described_class.new(:arrived, { where: condition, descripton: 'made port' }) }
        .to raise_error(ArgumentError, 'bucket `arrived`: unknown option `:descripton`')
    end

    it 'raises without a where' do
      expect { described_class.new(:arrived, { description: 'made port' }) }
        .to raise_error(ArgumentError, 'bucket `arrived`: needs a `where` that responds to `call`')
    end

    it 'raises when the condition cannot be called' do
      expect { described_class.new(:arrived, :reached) }
        .to raise_error(ArgumentError, 'bucket `arrived`: needs a `where` that responds to `call`')
    end
  end
end
