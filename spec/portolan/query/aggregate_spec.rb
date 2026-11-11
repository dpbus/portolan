# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Query::Aggregate do
  let(:voyages) do
    Class.new(Portolan::Dataset) do
      description 'One row per voyage.'
      relation { |fleet| fleet ? Voyage.where(fleet:) : Voyage.all }
      dimension :harbor, 'the harbor the voyage set out from'
      dimension :crew, 'how many sailors were aboard', type: :integer
      dimension :departed_at, 'when the ship set sail', type: :datetime
      dimension :charted_on, 'when the coast was charted', type: :date
      dimension :flag, 'the flag the ship sailed under', joins: :ship, expression: 'ships.flag'
      dimension :long_voyage, 'whether it was over 1000 leagues', type: :boolean, expression: 'voyages.leagues > 1000'
      dimension :fate, 'how the voyage ended', buckets: {
        arrived: { where: -> { Voyage.where.not(arrived_at: nil) }, description: 'reached its destination' },
        lost: -> { Voyage.where(lost: true) },
      }
      measure :voyages, 'number of voyages'
      measure :ships, 'number of ships that sailed', count_distinct: :ship_id
      measure :leagues, 'distance sailed, in leagues', sum: :leagues
      measure :crew_size, 'average crew aboard', average: :crew
    end
  end

  let(:registry) { Portolan::Registry.new(voyages:) }

  let(:ordered_voyages) do
    Class.new(Portolan::Dataset) do
      description 'One row per voyage, in sailing order.'
      relation { Voyage.order(:departed_at) }
      dimension :harbor, 'the harbor the voyage set out from'
      measure :voyages, 'number of voyages'
    end
  end

  def aggregate(params, context: 'genoa') = described_class.new(registry, params, context:).call
  def errors(params) = aggregate(params).errors
  def rows(params, context: 'genoa') = aggregate(params, context:).rows
  def request(**params) = { 'dataset' => 'voyages', 'measure' => 'voyages' }.merge(params.transform_keys(&:to_s))

  describe 'errors' do
    it 'reports a request that is not an object' do
      expect(errors('voyages by harbor')).to eq(['request must be an object'])
    end

    it 'reports an unknown key such as context' do
      expect(errors(request(context: 'venice'))).to eq(['unknown key `context`; allowed: `dataset`, ' \
                                                          '`filters`, `limit`, `measure`, `group_by`, `period`'])
    end

    it 'reports a missing dataset' do
      expect(errors({ 'measure' => 'voyages' })).to eq(['dataset is required; allowed: `voyages`'])
    end

    it 'reports an unknown dataset' do
      expect(errors(request(dataset: 'voyage'))).to eq(['unknown dataset `voyage`; allowed: `voyages`'])
    end

    it 'reports a missing measure' do
      expect(errors({ 'dataset' => 'voyages' }))
        .to eq(['measure is required; allowed: `voyages`, `ships`, `leagues`, `crew_size`'])
    end

    it 'reports an unknown measure' do
      expect(errors(request(measure: 'cargo')))
        .to eq(['unknown measure `cargo`; allowed: `voyages`, `ships`, `leagues`, `crew_size`'])
    end

    it 'reports a group_by that is not a list' do
      expect(errors(request(group_by: { harbor: true }))).to eq(['group_by must be a list of dimension names'])
    end

    it 'reports an unknown dimension in group_by' do
      expect(errors(request(group_by: %w[harbour])).first).to start_with('unknown dimension `harbour` in group_by;')
    end

    it 'reports a dimension named twice' do
      expect(errors(request(group_by: %w[harbor harbor]))).to eq(['group_by names `harbor` twice'])
    end

    it 'reports too many dimensions' do
      expect(errors(request(group_by: %w[harbor crew flag fate]))).to eq(['group_by takes at most 3 dimensions'])
    end

    it 'reports two date dimensions' do
      expect(errors(request(group_by: %w[departed_at charted_on], period: 'month')))
        .to eq(['group_by takes at most one date dimension; filter on `charted_on` instead'])
    end

    it 'reports too many bucket combinations' do
      stub_const('Portolan::Query::Aggregate::MAX_BUCKET_COMBINATIONS', 1)

      expect(errors(request(group_by: %w[fate])))
        .to eq(['group_by makes 2 bucket combinations; at most 1 are allowed, so filter on a bucket dimension instead'])
    end

    it 'reports a missing period' do
      expect(errors(request(group_by: %w[charted_on])))
        .to eq(['period is required when grouping by `charted_on`; allowed: `day`, `week`, `month`, `quarter`, `year`'])
    end

    it 'reports a period the dimension does not allow' do
      expect(errors(request(group_by: %w[charted_on], period: 'hour')).first)
        .to start_with('period `hour` does not apply to `charted_on`;')
    end

    it 'reports a period with nothing to apply to' do
      expect(errors(request(period: 'month'))).to eq(['period only applies when grouping by a date dimension'])
    end

    it 'reports filters that are not a list' do
      expect(errors(request(filters: { 'dimension' => 'crew' }))).to eq(['filters must be a list'])
    end

    it 'numbers filter errors from one' do
      filters = [{ 'dimension' => 'crew', 'op' => 'gt', 'value' => 20 },
                 { 'dimension' => 'crew', 'op' => 'gt', 'value' => 'ten' }]

      expect(errors(request(filters:))).to eq(['filter 2: `crew`: `ten` is not an integer'])
    end

    it 'reports a limit out of range' do
      expect(errors(request(limit: 0))).to eq(['limit must be an integer from 1 to 50'])
    end

    it 'reports a limit that is not an integer' do
      expect(errors(request(limit: 'many'))).to eq(['limit must be an integer from 1 to 50'])
    end

    it 'reports every error once the dataset is known' do
      expect(errors(request(measure: 'cargo', limit: 0)).size).to eq(2)
    end

    it 'returns a result that is not a success' do
      expect(aggregate(request(measure: 'cargo'))).not_to be_success
    end
  end

  describe 'answers' do
    before do
      san_giorgio = Ship.create!(name: 'San Giorgio', flag: 'Genoa')
      santa_caterina = Ship.create!(name: 'Santa Caterina', flag: 'Genoa')
      san_marco = Ship.create!(name: 'San Marco', flag: 'Venice')
      voyage = ->(ship, **attributes) { ship.voyages.create!(fleet: 'genoa', crew: 26, leagues: 900, **attributes) }
      voyage.call(san_giorgio, harbor: 'Genoa', leagues: 1100, charted_on: '1325-08-01',
        departed_at: Time.utc(1325, 8, 3, 8), arrived_at: Time.utc(1325, 10, 12))
      voyage.call(santa_caterina, harbor: 'Genoa', crew: 24, leagues: 1100,
        departed_at: Time.utc(1325, 8, 3, 9), arrived_at: Time.utc(1325, 10, 12))
      voyage.call(san_giorgio, harbor: 'Caffa', departed_at: Time.utc(1326, 9, 25), lost: true, crew: 40,
        charted_on: '1326-09-01')
      voyage.call(san_marco, fleet: 'venice', harbor: 'Venice', departed_at: Time.utc(1330, 7, 8),
        arrived_at: Time.utc(1331, 5, 20), crew: 170, leagues: 4000)
    end

    it 'counts the rows the context may see' do
      expect(rows(request)).to eq([{ 'voyages' => 3 }])
    end

    it 'counts every row for a context that sees everything' do
      expect(rows(request, context: nil)).to eq([{ 'voyages' => 4 }])
    end

    it 'groups by a column, largest first' do
      expect(rows(request(group_by: 'harbor')))
        .to eq([{ 'harbor' => 'Genoa', 'voyages' => 2 }, { 'harbor' => 'Caffa', 'voyages' => 1 }])
    end

    it 'groups by a joined table' do
      expect(rows(request(group_by: %w[flag]), context: nil))
        .to eq([{ 'flag' => 'Genoa', 'voyages' => 3 }, { 'flag' => 'Venice', 'voyages' => 1 }])
    end

    it 'groups by an expression' do
      expect(rows(request(group_by: %w[long_voyage])))
        .to eq([{ 'long_voyage' => true, 'voyages' => 2 }, { 'long_voyage' => false, 'voyages' => 1 }])
    end

    it 'groups by buckets' do
      expect(rows(request(group_by: %w[fate])))
        .to eq([{ 'fate' => 'arrived', 'voyages' => 2 }, { 'fate' => 'lost', 'voyages' => 1 }])
    end

    it 'shows a bucket with nothing in it' do
      filters = [{ 'dimension' => 'harbor', 'op' => 'eq', 'value' => 'Genoa' }]

      expect(rows(request(group_by: %w[fate], filters:)))
        .to eq([{ 'fate' => 'arrived', 'voyages' => 2 }, { 'fate' => 'lost', 'voyages' => 0 }])
    end

    it 'groups by buckets and a column together' do
      expect(rows(request(group_by: %w[fate harbor])))
        .to eq([{ 'fate' => 'arrived', 'harbor' => 'Genoa', 'voyages' => 2 },
                { 'fate' => 'lost', 'harbor' => 'Caffa', 'voyages' => 1 }])
    end

    it 'groups datetimes by period, oldest first' do
      expect(rows(request(group_by: %w[departed_at], period: 'month')))
        .to eq([{ 'departed_at' => '1325-08-01', 'voyages' => 2 }, { 'departed_at' => '1326-09-01', 'voyages' => 1 }])
    end

    it 'gives a missing date as nil, before every period' do
      expect(rows(request(group_by: %w[charted_on], period: 'year')).map { |row| row['charted_on'] })
        .to eq([nil, '1325-01-01', '1326-01-01'])
    end

    it 'keeps the newest real periods when trimming, not the missing one' do
      expect(rows(request(group_by: %w[charted_on], period: 'year', limit: 2)).map { |row| row['charted_on'] })
        .to eq(%w[1325-01-01 1326-01-01])
    end

    it 'groups a relation that has its own order' do
      ordered = Portolan::Registry.new(voyages: ordered_voyages)

      expect(described_class.new(ordered, request(group_by: %w[harbor]), context: nil).call.rows.first)
        .to eq('harbor' => 'Genoa', 'voyages' => 2)
    end

    it 'compares an integer beyond the column range the way Rails does' do
      filters = [{ 'dimension' => 'crew', 'op' => 'lt', 'value' => 3_000_000_000 }]

      expect(rows(request(filters:))).to eq([{ 'voyages' => 3 }])
    end

    it 'reports an integer too large for any integer column' do
      filters = [{ 'dimension' => 'crew', 'op' => 'lt', 'value' => 10**20 }]

      expect(errors(request(filters:)).first).to start_with('filter 1: `crew`: `100000000000000000000` is outside')
    end

    it 'ignores a select or limit on the relation, measuring every row' do
      trimmed = Class.new(Portolan::Dataset) do
        description 'One row per voyage.'
        relation { Voyage.select(:id, :harbor).limit(1) }
        measure :voyages, 'number of voyages'
      end

      expect(described_class.new(Portolan::Registry.new(voyages: trimmed), request, context: nil).call.rows)
        .to eq([{ 'voyages' => 4 }])
    end

    it 'reports too many groups instead of loading them all' do
      stub_const('Portolan::Query::Aggregate::GROUP_LIMIT', 1)

      expect(errors(request(group_by: %w[harbor])))
        .to eq(['more than 10000 groups; filter or group by fewer dimensions'])
    end

    it 'builds the relation for the context once' do
      allow(voyages).to receive(:relation_for).and_call_original
      aggregate(request(group_by: %w[fate]))

      expect(voyages).to have_received(:relation_for).once
    end

    it 'counts distinct values' do
      expect(rows(request(measure: 'ships'))).to eq([{ 'ships' => 2 }])
    end

    it 'sums a column' do
      expect(rows(request(measure: 'leagues'))).to eq([{ 'leagues' => 3100 }])
    end

    it 'averages a column as a float' do
      expect(rows(request(measure: 'crew_size')).first['crew_size']).to be_a(Float).and eq(30.0)
    end

    it 'applies filters' do
      expect(rows(request(filters: [{ 'dimension' => 'crew', 'op' => 'gt', 'value' => 25 }])))
        .to eq([{ 'voyages' => 2 }])
    end

    it 'keeps the largest rows within the limit' do
      result = aggregate(request(group_by: %w[harbor], limit: 1))

      expect([result.rows, result.notes]).to eq([[{ 'harbor' => 'Genoa', 'voyages' => 2 }],
                                                 ['Showing the largest 1 of 2 rows.']])
    end

    it 'trims a series by whole periods' do
      expect(rows(request(group_by: %w[departed_at crew], period: 'month', limit: 2)))
        .to eq([{ 'departed_at' => '1326-09-01', 'crew' => 40, 'voyages' => 1 }])
    end

    it 'shows only the buckets the filters allow' do
      filters = [{ 'dimension' => 'fate', 'op' => 'eq', 'value' => 'lost' }]

      expect(rows(request(group_by: %w[fate], filters:))).to eq([{ 'fate' => 'lost', 'voyages' => 1 }])
    end

    it 'keeps the newest periods within the limit' do
      result = aggregate(request(group_by: %w[departed_at], period: 'month', limit: 1))

      expect(result.rows).to eq([{ 'departed_at' => '1326-09-01', 'voyages' => 1 }])
    end

    it 'defines the dimensions and measure it used' do
      filters = [{ 'dimension' => 'crew', 'op' => 'gt', 'value' => 25 }]

      expect(aggregate(request(group_by: %w[fate], filters:)).definitions.keys).to eq(%w[fate crew voyages])
    end

    it 'includes bucket descriptions in its definitions' do
      expect(aggregate(request(group_by: %w[fate])).definitions['fate'])
        .to eq(description: 'how the voyage ended', buckets: { 'arrived' => 'reached its destination' })
    end

    it 'echoes the request' do
      expect(aggregate(request(group_by: 'harbor')).request)
        .to eq(dataset: 'voyages', measure: 'voyages', group_by: %w[harbor])
    end
  end
end
