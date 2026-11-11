# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::Date do
  subject(:type) { described_class.new }

  it 'is named date' do
    expect(type.name).to eq('date')
  end

  it 'allows range operators only' do
    expect(type.operators).to eq(%w[gt lt between])
  end

  it 'allows calendar periods only' do
    expect(type.periods).to eq(%w[day week month quarter year])
  end

  describe '#errors_for' do
    it 'returns no errors for a day' do
      expect(type.errors_for('1325-08-03')).to be_empty
    end

    it 'returns an error for a day that does not exist' do
      expect(type.errors_for('1325-13-01')).to eq(['`1325-13-01` is not a date; use YYYY-MM-DD'])
    end

    it 'returns an error for another format' do
      expect(type.errors_for('03/08/1325')).to eq(['`03/08/1325` is not a date; use YYYY-MM-DD'])
    end

    it 'returns an error for a timestamp, rather than dropping its time' do
      expect(type.errors_for('1325-08-03T10:00Z')).to eq(['`1325-08-03T10:00Z` is not a date; use YYYY-MM-DD'])
    end

    it 'returns an error for a timestamp with an offset' do
      expect(type.errors_for('1325-08-03T23:00-05:00'))
        .to eq(['`1325-08-03T23:00-05:00` is not a date; use YYYY-MM-DD'])
    end

    it 'returns an error for a day without leading zeros' do
      expect(type.errors_for('1325-8-3')).to eq(['`1325-8-3` is not a date; use YYYY-MM-DD'])
    end

    it 'returns an error for year zero' do
      expect(type.errors_for('0000-01-01')).to eq(['`0000-01-01` is not a date; use YYYY-MM-DD'])
    end

    it 'returns an error for a value that is not text' do
      expect(type.errors_for(1325)).to eq(['`1325` is not a date; use YYYY-MM-DD'])
    end
  end

  describe '#cast' do
    it 'casts a day to a date' do
      expect(type.cast('1325-08-03')).to eq(Date.new(1325, 8, 3))
    end
  end
end
