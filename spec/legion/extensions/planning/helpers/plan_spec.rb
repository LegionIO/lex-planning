# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Planning::Helpers::Plan do
  let(:step_a) { Legion::Extensions::Planning::Helpers::PlanStep.new(action: :step_a) }
  let(:step_b) { Legion::Extensions::Planning::Helpers::PlanStep.new(action: :step_b, depends_on: [step_a.id]) }

  subject(:plan) do
    described_class.new(goal: 'achieve objective', steps: [step_a, step_b], priority: :high)
  end

  describe '#initialize' do
    it 'assigns a UUID id' do
      expect(plan.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'sets goal' do
      expect(plan.goal).to eq('achieve objective')
    end

    it 'sets priority' do
      expect(plan.priority).to eq(:high)
    end

    it 'defaults status to :forming' do
      expect(plan.status).to eq(:forming)
    end

    it 'copies steps array' do
      expect(plan.steps.size).to eq(2)
    end

    it 'defaults replan_count to 0' do
      expect(plan.replan_count).to eq(0)
    end

    it 'sets created_at' do
      expect(plan.created_at).not_to be_nil
    end

    it 'accepts parent_plan_id' do
      p = described_class.new(goal: 'sub', parent_plan_id: 'parent-uuid')
      expect(p.parent_plan_id).to eq('parent-uuid')
    end
  end

  describe '#progress' do
    it 'returns 0.0 for all pending steps' do
      expect(plan.progress).to eq(0.0)
    end

    it 'returns 0.0 for empty steps' do
      empty_plan = described_class.new(goal: 'empty')
      expect(empty_plan.progress).to eq(0.0)
    end

    it 'returns 0.5 when half the steps are done' do
      step_a.complete!
      expect(plan.progress).to eq(0.5)
    end

    it 'returns 1.0 when all steps are completed' do
      step_a.complete!
      step_b.complete!
      expect(plan.progress).to eq(1.0)
    end

    it 'counts skipped steps as done' do
      step_a.status = :skipped
      expect(plan.progress).to eq(0.5)
    end
  end

  describe '#active_step' do
    it 'returns nil when no active step' do
      expect(plan.active_step).to be_nil
    end

    it 'returns the active step' do
      step_a.start!
      expect(plan.active_step).to eq(step_a)
    end
  end

  describe '#completed_step_ids' do
    it 'returns empty when no steps done' do
      expect(plan.completed_step_ids).to be_empty
    end

    it 'returns ids of completed and skipped steps' do
      step_a.complete!
      step_b.status = :skipped
      expect(plan.completed_step_ids).to contain_exactly(step_a.id, step_b.id)
    end
  end

  describe '#advance!' do
    it 'marks the step completed' do
      plan.advance!(step_a.id, result: { ok: true })
      expect(step_a.status).to eq(:completed)
    end

    it 'returns the step' do
      result = plan.advance!(step_a.id)
      expect(result).to eq(step_a)
    end

    it 'returns nil for unknown step_id' do
      expect(plan.advance!('nonexistent')).to be_nil
    end

    it 'auto-completes plan when progress >= COMPLETION_THRESHOLD' do
      step_a.complete!
      plan.advance!(step_b.id)
      expect(plan.status).to eq(:completed)
    end

    it 'updates updated_at' do
      original = plan.updated_at
      sleep 0.01
      plan.advance!(step_a.id)
      expect(plan.updated_at).to be >= original
    end
  end

  describe '#fail_step!' do
    it 'marks the step failed' do
      plan.fail_step!(step_a.id, reason: 'network error')
      expect(step_a.status).to eq(:failed)
    end

    it 'returns the step' do
      expect(plan.fail_step!(step_a.id)).to eq(step_a)
    end

    it 'returns nil for unknown step_id' do
      expect(plan.fail_step!('nonexistent')).to be_nil
    end
  end

  describe '#complete?' do
    it 'returns false when status is forming' do
      expect(plan.complete?).to be false
    end

    it 'returns true when status is :completed' do
      plan.status = :completed
      expect(plan.complete?).to be true
    end

    it 'returns true when progress >= COMPLETION_THRESHOLD' do
      step_a.complete!
      step_b.complete!
      expect(plan.complete?).to be true
    end
  end

  describe '#failed?' do
    it 'returns false when not failed' do
      expect(plan.failed?).to be false
    end

    it 'returns true when status is :failed' do
      plan.status = :failed
      expect(plan.failed?).to be true
    end
  end

  describe '#stale?' do
    it 'returns false for a freshly created plan' do
      expect(plan.stale?).to be false
    end
  end

  describe '#increment_replan!' do
    it 'increments replan_count' do
      plan.increment_replan!
      expect(plan.replan_count).to eq(1)
    end

    it 'updates updated_at' do
      original = plan.updated_at
      sleep 0.01
      plan.increment_replan!
      expect(plan.updated_at).to be >= original
    end
  end

  describe '#replace_remaining_steps!' do
    let(:new_step) { Legion::Extensions::Planning::Helpers::PlanStep.new(action: :new_action) }

    before { step_a.complete! }

    it 'removes pending steps' do
      plan.replace_remaining_steps!([new_step])
      expect(plan.steps).not_to include(step_b)
    end

    it 'keeps completed steps' do
      plan.replace_remaining_steps!([new_step])
      expect(plan.steps).to include(step_a)
    end

    it 'adds new steps' do
      plan.replace_remaining_steps!([new_step])
      expect(plan.steps).to include(new_step)
    end
  end

  describe '#to_h' do
    it 'returns hash with expected keys' do
      h = plan.to_h
      expect(h).to have_key(:id)
      expect(h).to have_key(:goal)
      expect(h).to have_key(:priority)
      expect(h).to have_key(:status)
      expect(h).to have_key(:progress)
      expect(h).to have_key(:steps)
      expect(h).to have_key(:contingencies)
      expect(h).to have_key(:replan_count)
      expect(h).to have_key(:created_at)
      expect(h).to have_key(:updated_at)
    end

    it 'serializes steps as hashes' do
      expect(plan.to_h[:steps]).to all(be_a(Hash))
    end
  end
end
