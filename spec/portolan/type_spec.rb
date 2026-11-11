# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type do
  describe '.for' do
    it 'returns the type for each name' do
      expect(described_class::NAMES.map { |name| described_class.for(name).name })
        .to eq(%w[string integer boolean date datetime])
    end

    it 'hands out frozen operators and periods' do
      types = described_class::NAMES.map { |name| described_class.for(name) }

      expect(types.flat_map { |type| [type.operators, type.periods] }).to all(be_frozen)
    end

    it 'raises for an unknown name' do
      expect { described_class.for(:time) }.to raise_error(KeyError)
    end
  end
end
