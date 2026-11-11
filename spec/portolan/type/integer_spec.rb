# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::Integer do
  subject(:type) { described_class.new }

  it 'is named integer' do
    expect(type.name).to eq('integer')
  end

  it 'allows equality and comparison operators' do
    expect(type.operators).to eq(%w[eq in gt lt between])
  end

  describe '#errors_for' do
    it 'returns no errors for an integer' do
      expect(type.errors_for(26)).to be_empty
    end

    it 'returns no errors for digits' do
      expect(type.errors_for('26')).to be_empty
    end

    it 'returns an error for words' do
      expect(type.errors_for('twenty six')).to eq(['`twenty six` is not an integer'])
    end

    it 'returns an error for a fraction' do
      expect(type.errors_for('26.5')).to eq(['`26.5` is not an integer'])
    end

    it 'returns an error for a float' do
      expect(type.errors_for(26.5)).to eq(['`26.5` is not an integer'])
    end
  end

  describe '#cast' do
    it 'casts digits to an integer' do
      expect(type.cast('26')).to eq(26)
    end
  end
end
