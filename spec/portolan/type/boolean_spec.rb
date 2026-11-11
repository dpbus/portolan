# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::Boolean do
  subject(:type) { described_class.new }

  it 'is named boolean' do
    expect(type.name).to eq('boolean')
  end

  it 'allows eq only' do
    expect(type.operators).to eq(%w[eq])
  end

  describe '#errors_for' do
    it 'returns no errors for true and false, as booleans or text' do
      expect([true, false, 'true', 'false'].map { |value| type.errors_for(value) }).to all(be_empty)
    end

    it 'returns an error for anything else' do
      expect(type.errors_for('yes')).to eq(['`yes` is not true or false'])
    end
  end

  describe '#cast' do
    it 'casts text to a boolean' do
      expect([type.cast('true'), type.cast('false')]).to eq([true, false])
    end
  end
end
