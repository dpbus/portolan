# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::Decimal do
  subject(:type) { described_class.new }

  it 'is named decimal' do
    expect(type.name).to eq('decimal')
  end

  it 'allows equality and comparison operators' do
    expect(type.operators).to eq(%w[eq in gt lt between])
  end

  describe '#errors_for' do
    it 'returns no errors for numbers given as text, floats, and integers' do
      expect(['120.5', '1e3', 120.5, 120].map { |value| type.errors_for(value) }).to all(be_empty)
    end

    it 'returns an error for a decimal comma' do
      expect(type.errors_for('120,5')).to eq(['`120,5` is not a number'])
    end

    it 'returns an error for a number with units' do
      expect(type.errors_for('120.5t')).to eq(['`120.5t` is not a number'])
    end

    it 'returns an error for values that are not finite' do
      expect([type.errors_for('NaN'), type.errors_for('Infinity')])
        .to eq([['`NaN` is not a number'], ['`Infinity` is not a number']])
    end
  end

  describe '#cast' do
    it 'casts text to an exact decimal' do
      expect(type.cast('120.5')).to eq(BigDecimal('120.5'))
    end

    it 'casts a float through its shortest form, so 1.1 stays exactly 1.1' do
      expect(type.cast(1.1)).to eq(BigDecimal('1.1'))
    end
  end

  describe '#label' do
    it 'labels a value as a float, so it is a number in JSON' do
      expect(type.label(BigDecimal('120.5'))).to be_a(Float).and eq(120.5)
    end
  end
end
