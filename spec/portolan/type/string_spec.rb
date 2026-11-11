# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::String do
  subject(:type) { described_class.new }

  it 'is named string' do
    expect(type.name).to eq('string')
  end

  it 'allows eq and in' do
    expect(type.operators).to eq(%w[eq in])
  end

  it 'has no periods' do
    expect(type.periods).to be_empty
  end

  describe '#errors_for' do
    it 'returns no errors for text' do
      expect(type.errors_for('Genoa')).to be_empty
    end

    it 'returns no errors for a number' do
      expect(type.errors_for(1.75)).to be_empty
    end

    it 'returns an error for a value that is not text' do
      expect(type.errors_for(%w[Genoa])).to eq(['`["Genoa"]` is not text'])
    end
  end

  describe '#cast' do
    it 'casts a number to text' do
      expect(type.cast(1.75)).to eq('1.75')
    end
  end
end
