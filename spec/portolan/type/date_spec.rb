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

  it 'uses the value itself as both bounds of a range' do
    day = Date.new(1325, 8, 3)

    expect([type.lower_bound(day), type.upper_bound(day)]).to eq([day, day])
  end

  describe '#cast' do
    it 'casts a day to a date' do
      expect(type.cast('1325-08-03')).to eq(Date.new(1325, 8, 3))
    end
  end

  describe '#truncate' do
    before do
      ship = Ship.create!(name: 'San Giorgio', flag: 'Genoa')
      %w[1325-08-01 1325-08-31 1325-09-15].each do |charted_on|
        ship.voyages.create!(fleet: 'genoa', harbor: 'Genoa', crew: 26, leagues: 900, charted_on:,
          departed_at: Time.utc(1325, 8, 3))
      end
    end

    it 'groups dates by period, keeping them as dates' do
      expect(Voyage.group(type.truncate(Voyage.arel_table[:charted_on], 'month')).count)
        .to eq(Date.new(1325, 8, 1) => 2, Date.new(1325, 9, 1) => 1)
    end
  end

  describe '#label' do
    it 'labels a period with its first day' do
      expect(type.label(Date.new(1325, 8, 1), 'month')).to eq('1325-08-01')
    end
  end
end
