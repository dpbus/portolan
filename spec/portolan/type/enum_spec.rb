# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::Enum do
  subject(:type) { described_class.new(%i[adriatic aegean]) }

  it 'is named string' do
    expect(type.name).to eq('string')
  end

  it 'keeps its values as frozen strings' do
    expect(type.values).to eq(%w[adriatic aegean]).and be_frozen
  end

  describe '#errors_for' do
    it 'returns no errors for a listed value' do
      expect(type.errors_for('aegean')).to be_empty
    end

    it 'returns an error for a value not listed' do
      expect(type.errors_for('baltic')).to eq(['unknown value `baltic`; allowed: `adriatic`, `aegean`'])
    end

    it 'returns the string error for a value that is not text' do
      expect(type.errors_for(%w[aegean])).to eq(['`["aegean"]` is not text'])
    end
  end
end
