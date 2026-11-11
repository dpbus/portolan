# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Portolan::Query::Result do
  let(:request) { { dataset: 'voyages', measure: 'voyages', group_by: %w[harbor], period: nil } }
  let(:rows) { [{ 'harbor' => 'Genoa', 'voyages' => 3 }, { 'harbor' => 'Venice', 'voyages' => 2 }] }
  let(:definitions) { { 'harbor' => { description: 'the harbor the voyage set out from' } } }

  context 'with rows' do
    subject(:result) { described_class.new(request:, rows:, definitions:) }

    it 'is a success' do
      expect(result).to be_success
    end

    it 'is not truncated when every row is shown' do
      expect(result).not_to be_truncated
    end

    it 'has no notes' do
      expect(result.notes).to be_empty
    end

    it 'drops request parts that were not given' do
      expect(result.request).to eq(dataset: 'voyages', measure: 'voyages', group_by: %w[harbor])
    end

    it 'returns the request, rows, and definitions, leaving out what is empty' do
      expect(result.to_h).to eq(dataset: 'voyages', measure: 'voyages', group_by: %w[harbor], rows:, definitions:)
    end

    it 'is frozen with frozen parts' do
      expect([result, result.rows, result.definitions, result.errors]).to all(be_frozen)
    end
  end

  context 'with no rows' do
    subject(:result) { described_class.new(request:, rows: [], definitions:) }

    it 'still includes empty rows in its hash, so no rows reads as an answer' do
      expect(result.to_h).to include(rows: [])
    end
  end

  context 'with rows trimmed from a larger total' do
    subject(:result) { described_class.new(request:, rows:, definitions:, total_rows: 9) }

    it 'is truncated' do
      expect(result).to be_truncated
    end

    it 'notes the largest rows were kept' do
      expect(result.notes).to eq(['Showing the largest 2 of 9 rows.'])
    end

    it 'includes truncated and the notes in its hash' do
      expect(result.to_h).to include(truncated: true, notes: ['Showing the largest 2 of 9 rows.'])
    end
  end

  context 'with a period' do
    subject(:result) { described_class.new(request: request.merge(period: 'month'), rows:, total_rows: 9) }

    it 'notes the newest rows were kept and empty periods are omitted' do
      expect(result.notes).to eq(['Showing the newest 2 of 9 rows.', 'Periods with no rows are omitted.'])
    end
  end

  context 'with errors' do
    subject(:result) { described_class.new(request: { dataset: 'voyages' }, errors: ['unknown measure `ships`']) }

    it 'is not a success' do
      expect(result).not_to be_success
    end

    it 'returns the dataset and the errors only' do
      expect(result.to_h).to eq(dataset: 'voyages', errors: ['unknown measure `ships`'])
    end
  end
end
