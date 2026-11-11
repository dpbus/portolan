# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Query::Filter do
  let(:dataset) do
    Class.new(Portolan::Dataset) do
      description 'One row per voyage.'
      relation { Voyage.all }
      dimension :harbor, 'the harbor the voyage set out from'
      dimension :fleet, 'the fleet the ship sailed with', values: %w[genoa venice]
      dimension :crew, 'how many sailors were aboard', type: :integer
      dimension :lost, 'whether the ship was lost', type: :boolean
      dimension :departed_at, 'when the ship set sail', type: :datetime
      dimension :charted_on, 'when the coast was charted', type: :date
      dimension :flag, 'the flag the ship sailed under', joins: :ship, expression: 'ships.flag'
      dimension :long_voyage, 'whether it was over 1000 leagues', type: :boolean, expression: 'voyages.leagues > 1000'
      dimension :fate, 'how the voyage ended', buckets: {
        arrived: -> { Voyage.where.not(arrived_at: nil) },
        lost: -> { Voyage.where(lost: true) },
      }
      measure :voyages, 'number of voyages'
    end
  end

  def filter(params) = described_class.new(dataset, params)
  def harbors(params) = filter(params).apply(Voyage.all).pluck(:harbor).sort

  def bound_values(params)
    binds = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      binds.concat(payload[:type_casted_binds]) if payload[:sql].include?('voyages')
    end
    filter(params).apply(Voyage.all).to_a
    binds
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe '#errors' do
    it 'is empty for a valid filter' do
      expect(filter('dimension' => 'harbor', 'op' => 'eq', 'value' => 'Genoa').errors).to be_empty
    end

    it 'reports params that are not an object' do
      expect(filter('harbor = Genoa').errors)
        .to eq(['must be an object with `dimension`, `op`, and `value` or `values`'])
    end

    it 'reports an unknown key' do
      expect(filter('dimension' => 'harbor', 'op' => 'eq', 'value' => 'Genoa', 'note' => 'x').errors)
        .to eq(['unknown key `note`; allowed: `dimension`, `op`, `value`, `values`'])
    end

    it 'reports both value and values' do
      expect(filter('dimension' => 'harbor', 'op' => 'eq', 'value' => 'Genoa', 'values' => ['Genoa']).errors)
        .to eq(['give `value` or `values`, not both'])
    end

    it 'reports an unknown dimension with the allowed ones' do
      expect(filter('dimension' => 'harbour', 'op' => 'eq', 'value' => 'Genoa').errors.first)
        .to start_with('unknown dimension `harbour`; allowed: `harbor`, `fleet`, `crew`')
    end

    it 'reports an operator that does not apply to the dimension' do
      expect(filter('dimension' => 'harbor', 'op' => 'gt', 'value' => 'Genoa').errors)
        .to eq(['operator `gt` does not apply to `harbor`; allowed: `eq`, `in`'])
    end

    it 'reports between with one value' do
      expect(filter('dimension' => 'crew', 'op' => 'between', 'value' => 26).errors)
        .to eq(['`between` takes two values'])
    end

    it 'reports in with no values' do
      expect(filter('dimension' => 'crew', 'op' => 'in', 'values' => []).errors)
        .to eq(['`in` takes one or more values'])
    end

    it 'reports eq with two values' do
      expect(filter('dimension' => 'crew', 'op' => 'eq', 'values' => [26, 40]).errors)
        .to eq(['`eq` takes one value'])
    end

    it 'reports a value of the wrong type, naming the dimension' do
      expect(filter('dimension' => 'crew', 'op' => 'eq', 'value' => 'ten').errors)
        .to eq(['`crew`: `ten` is not an integer'])
    end

    it 'reports a value outside the listed values' do
      expect(filter('dimension' => 'fleet', 'op' => 'eq', 'value' => 'pisa').errors)
        .to eq(['`fleet`: unknown value `pisa`; allowed: `genoa`, `venice`'])
    end

    it 'reports every bad value at once' do
      expect(filter('dimension' => 'crew', 'op' => 'in', 'values' => %w[ten x]).errors)
        .to eq(['`crew`: `ten` is not an integer', '`crew`: `x` is not an integer'])
    end

    it 'reports between with the larger value first' do
      expect(filter('dimension' => 'crew', 'op' => 'between', 'values' => [40, 26]).errors)
        .to eq(['`between` needs the smaller value first'])
    end

    it 'stops at the first structural error' do
      expect(filter('dimension' => 'harbour', 'op' => 'gt', 'values' => []).errors.size).to eq(1)
    end

    it 'is frozen' do
      expect(filter('dimension' => 'crew', 'op' => 'eq', 'value' => 'ten').errors).to be_frozen
    end
  end

  describe '#values' do
    it 'casts the values to the dimension type' do
      expect(filter('dimension' => 'crew', 'op' => 'in', 'values' => %w[26 40]).values).to eq([26, 40])
    end

    it 'casts days to dates' do
      expect(filter('dimension' => 'departed_at', 'op' => 'gt', 'value' => '1325-08-03').values)
        .to eq([Date.new(1325, 8, 3)])
    end

    it 'is frozen' do
      expect(filter('dimension' => 'crew', 'op' => 'eq', 'value' => 26).values).to be_frozen
    end

    it 'is nil for an invalid filter' do
      expect(filter('dimension' => 'crew', 'op' => 'eq', 'value' => 'ten').values).to be_nil
    end
  end

  describe '#apply' do
    before do
      san_giorgio = Ship.create!(name: 'San Giorgio', flag: 'Genoa')
      san_marco = Ship.create!(name: 'San Marco', flag: 'Venice')
      san_giorgio.voyages.create!(fleet: 'genoa', harbor: 'Genoa', crew: 26, leagues: 1100, charted_on: '1325-08-01',
        departed_at: Time.utc(1325, 8, 3, 8), arrived_at: Time.utc(1325, 10, 12))
      san_marco.voyages.create!(fleet: 'venice', harbor: 'Venice', crew: 170, leagues: 4000,
        charted_on: '1330-06-30', departed_at: Time.utc(1330, 7, 8, 23, 59, 59.999999r),
        arrived_at: Time.utc(1331, 5, 20))
      san_giorgio.voyages.create!(fleet: 'genoa', harbor: 'Caffa', crew: 40, leagues: 900, lost: true,
        departed_at: Time.utc(1330, 7, 9))
    end

    it 'keeps rows equal to the value' do
      expect(harbors('dimension' => 'harbor', 'op' => 'eq', 'value' => 'Genoa')).to eq(%w[Genoa])
    end

    it 'keeps rows matching any of the values' do
      expect(harbors('dimension' => 'harbor', 'op' => 'in', 'values' => %w[Genoa Venice])).to eq(%w[Genoa Venice])
    end

    it 'keeps rows greater than the value' do
      expect(harbors('dimension' => 'crew', 'op' => 'gt', 'value' => 30)).to eq(%w[Caffa Venice])
    end

    it 'keeps rows less than the value' do
      expect(harbors('dimension' => 'crew', 'op' => 'lt', 'value' => '30')).to eq(%w[Genoa])
    end

    it 'keeps rows between the values, inclusive' do
      expect(harbors('dimension' => 'crew', 'op' => 'between', 'values' => [26, 40])).to eq(%w[Caffa Genoa])
    end

    it 'keeps datetimes after the whole day' do
      expect(harbors('dimension' => 'departed_at', 'op' => 'gt', 'value' => '1330-07-08')).to eq(%w[Caffa])
    end

    it 'keeps datetimes before the whole day' do
      expect(harbors('dimension' => 'departed_at', 'op' => 'lt', 'value' => '1330-07-09')).to eq(%w[Genoa Venice])
    end

    it 'keeps datetimes from the first to the last moment of the day' do
      expect(harbors('dimension' => 'departed_at', 'op' => 'between', 'values' => %w[1330-07-08 1330-07-08]))
        .to eq(%w[Venice])
    end

    it 'compares dates directly' do
      expect(harbors('dimension' => 'charted_on', 'op' => 'gt', 'value' => '1325-08-01')).to eq(%w[Venice])
    end

    it 'keeps rows matching a boolean given as text' do
      expect(harbors('dimension' => 'lost', 'op' => 'eq', 'value' => 'false')).to eq(%w[Genoa Venice])
    end

    it 'keeps rows matching a listed value' do
      expect(harbors('dimension' => 'fleet', 'op' => 'eq', 'value' => 'venice')).to eq(%w[Venice])
    end

    it 'keeps rows in a bucket' do
      expect(harbors('dimension' => 'fate', 'op' => 'eq', 'value' => 'lost')).to eq(%w[Caffa])
    end

    it 'keeps rows in any of several buckets' do
      expect(harbors('dimension' => 'fate', 'op' => 'in', 'values' => %w[arrived lost])).to eq(%w[Caffa Genoa Venice])
    end

    it 'filters on a joined table' do
      expect(harbors('dimension' => 'flag', 'op' => 'eq', 'value' => 'Venice')).to eq(%w[Venice])
    end

    it 'filters on an expression' do
      expect(harbors('dimension' => 'long_voyage', 'op' => 'eq', 'value' => true)).to eq(%w[Genoa Venice])
    end

    it 'compares an integer beyond the column range the way Rails does' do
      expect(harbors('dimension' => 'crew', 'op' => 'lt', 'value' => 3_000_000_000)).to eq(%w[Caffa Genoa Venice])
    end

    it 'sends a column value as a bound parameter' do
      expect(bound_values('dimension' => 'harbor', 'op' => 'eq', 'value' => 'Genoa')).to include('Genoa')
    end

    it 'sends an expression value as a bound parameter' do
      expect(bound_values('dimension' => 'long_voyage', 'op' => 'eq', 'value' => true)).to include(true)
    end

    it 'treats a value as data, never as SQL' do
      expect(harbors('dimension' => 'harbor', 'op' => 'eq', 'value' => "Genoa'; DROP TABLE voyages; --")).to be_empty
    end

    it 'leaves the table intact after a hostile value' do
      harbors('dimension' => 'harbor', 'op' => 'eq', 'value' => "Genoa'; DROP TABLE voyages; --")

      expect(Voyage.count).to eq(3)
    end
  end
end
