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
end
