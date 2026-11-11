# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Type::DateTime do
  subject(:type) { described_class.new }

  it 'is named datetime' do
    expect(type.name).to eq('datetime')
  end

  it 'allows hour and the calendar periods' do
    expect(type.periods).to eq(%w[hour day week month quarter year])
  end

  it 'starts a range at the first moment of the day, in UTC' do
    expect(type.lower_bound(Date.new(1325, 8, 3))).to eq(Time.utc(1325, 8, 3))
  end

  it 'ends a range one nanosecond before the next day, in UTC' do
    expect(type.upper_bound(Date.new(1325, 8, 3))).to eq(Time.utc(1325, 8, 4) - Rational(1, 1_000_000_000))
  end

  it 'takes a day as a value' do
    expect(type.cast('1325-08-03')).to eq(Date.new(1325, 8, 3))
  end

  describe '#truncate' do
    before do
      ship = Ship.create!(name: 'San Giorgio', flag: 'Genoa')
      [Time.utc(2026, 11, 8, 23, 59), Time.utc(2026, 11, 9), Time.utc(2026, 11, 11, 14, 30)].each do |departed_at|
        ship.voyages.create!(fleet: 'genoa', harbor: 'Genoa', crew: 26, leagues: 900, departed_at:)
      end
    end

    def counts(period) = Voyage.group(type.truncate(Voyage.arel_table[:departed_at], period)).count

    it 'starts weeks on Monday' do
      expect(counts('week')).to eq(Time.utc(2026, 11, 2) => 1, Time.utc(2026, 11, 9) => 2)
    end

    it 'groups by hour' do
      expect(counts('hour').keys).to contain_exactly(Time.utc(2026, 11, 8, 23), Time.utc(2026, 11, 9),
        Time.utc(2026, 11, 11, 14))
    end

    it 'raises for a period it does not allow' do
      expect { counts('minute') }.to raise_error(ArgumentError, 'period `minute` does not apply to datetime')
    end
  end

  describe '#label' do
    it 'labels an hour with its time in UTC' do
      expect(type.label(Time.utc(1325, 8, 3, 14), 'hour')).to eq('1325-08-03T14:00Z')
    end

    it 'labels any other period with its first day' do
      expect(type.label(Time.utc(1325, 8, 1), 'month')).to eq('1325-08-01')
    end

    it 'labels the day in UTC, whatever the time zone of the value' do
      expect(type.label(Time.new(2026, 11, 1, 1, 0, 0, '+05:00'), 'day')).to eq('2026-10-31')
    end
  end
end
