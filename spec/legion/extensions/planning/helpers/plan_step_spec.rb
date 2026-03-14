# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Planning::Helpers::PlanStep do
  subject(:step) { described_class.new(action: :fetch_data, description: 'Fetch remote data') }

  describe '#initialize' do
    it 'assigns a UUID id' do
      expect(step.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'sets action' do
      expect(step.action).to eq(:fetch_data)
    end

    it 'sets description' do
      expect(step.description).to eq('Fetch remote data')
    end

    it 'defaults status to :pending' do
      expect(step.status).to eq(:pending)
    end

    it 'defaults depends_on to empty array' do
      expect(step.depends_on).to eq([])
    end

    it 'defaults estimated_effort to 1' do
      expect(step.estimated_effort).to eq(1)
    end

    it 'accepts depends_on list' do
      s = described_class.new(action: :second, depends_on: %w[abc def])
      expect(s.depends_on).to eq(%w[abc def])
    end

    it 'accepts estimated_effort' do
      s = described_class.new(action: :heavy, estimated_effort: 5)
      expect(s.estimated_effort).to eq(5)
    end
  end

  describe '#ready?' do
    let(:dep_id) { 'some-uuid' }
    let(:step_with_dep) { described_class.new(action: :second, depends_on: [dep_id]) }

    it 'returns true when no dependencies' do
      expect(step.ready?([])).to be true
    end

    it 'returns true when all deps are in completed set' do
      expect(step_with_dep.ready?([dep_id])).to be true
    end

    it 'returns false when deps are missing' do
      expect(step_with_dep.ready?([])).to be false
    end

    it 'returns false when already completed' do
      step.complete!
      expect(step.ready?([])).to be false
    end

    it 'returns false when already failed' do
      step.fail!
      expect(step.ready?([])).to be false
    end

    it 'returns false when already skipped' do
      step.status = :skipped
      expect(step.ready?([])).to be false
    end
  end

  describe '#blocked?' do
    it 'returns false when pending' do
      expect(step.blocked?).to be false
    end

    it 'returns true when status is :blocked' do
      step.status = :blocked
      expect(step.blocked?).to be true
    end
  end

  describe '#duration' do
    it 'returns nil when not started' do
      expect(step.duration).to be_nil
    end

    it 'returns elapsed time after completion' do
      step.start!
      sleep 0.01
      step.complete!
      expect(step.duration).to be > 0
    end
  end

  describe '#complete!' do
    before { step.complete!(result: { value: 42 }) }

    it 'sets status to :completed' do
      expect(step.status).to eq(:completed)
    end

    it 'stores the result' do
      expect(step.result).to eq({ value: 42 })
    end

    it 'sets completed_at' do
      expect(step.completed_at).not_to be_nil
    end
  end

  describe '#fail!' do
    before { step.fail!(reason: 'timeout') }

    it 'sets status to :failed' do
      expect(step.status).to eq(:failed)
    end

    it 'stores the reason in result' do
      expect(step.result[:reason]).to eq('timeout')
    end

    it 'sets completed_at' do
      expect(step.completed_at).not_to be_nil
    end
  end

  describe '#start!' do
    before { step.start! }

    it 'sets status to :active' do
      expect(step.status).to eq(:active)
    end

    it 'sets started_at' do
      expect(step.started_at).not_to be_nil
    end
  end

  describe '#to_h' do
    it 'returns a hash with expected keys' do
      h = step.to_h
      expect(h).to have_key(:id)
      expect(h).to have_key(:action)
      expect(h).to have_key(:description)
      expect(h).to have_key(:status)
      expect(h).to have_key(:depends_on)
      expect(h).to have_key(:estimated_effort)
      expect(h).to have_key(:actual_effort)
      expect(h).to have_key(:result)
      expect(h).to have_key(:started_at)
      expect(h).to have_key(:completed_at)
    end
  end
end
