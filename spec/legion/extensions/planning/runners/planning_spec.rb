# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Planning::Runners::Planning do
  let(:store) { Legion::Extensions::Planning::Helpers::PlanStore.new }

  let(:host) do
    Object.new.tap do |obj|
      obj.extend(described_class)
      obj.instance_variable_set(:@plan_store, store)
    end
  end

  let(:basic_steps) do
    [
      { action: :step_one },
      { action: :step_two }
    ]
  end

  describe '#create_plan' do
    it 'returns success' do
      result = host.create_plan(goal: 'test goal', steps: basic_steps)
      expect(result[:success]).to be true
    end

    it 'returns plan_id' do
      result = host.create_plan(goal: 'test goal', steps: basic_steps)
      expect(result[:plan_id]).to be_a(String)
    end

    it 'returns goal' do
      result = host.create_plan(goal: 'test goal', steps: basic_steps)
      expect(result[:goal]).to eq('test goal')
    end

    it 'returns step count' do
      result = host.create_plan(goal: 'test goal', steps: basic_steps)
      expect(result[:steps]).to eq(2)
    end

    it 'creates a plan in the store' do
      result = host.create_plan(goal: 'test goal', steps: basic_steps)
      expect(store.find_plan(result[:plan_id])).not_to be_nil
    end

    it 'accepts priority parameter' do
      result = host.create_plan(goal: 'urgent', steps: basic_steps, priority: :critical)
      plan = store.find_plan(result[:plan_id])
      expect(plan.priority).to eq(:critical)
    end

    it 'accepts parent_plan_id' do
      result = host.create_plan(goal: 'sub', steps: [], parent_plan_id: 'parent-id')
      plan = store.find_plan(result[:plan_id])
      expect(plan.parent_plan_id).to eq('parent-id')
    end
  end

  describe '#advance_plan' do
    let(:plan) { store.create_plan(goal: 'test', steps: basic_steps) }
    let(:step_id) { plan.steps.first.id }

    it 'returns success' do
      result = host.advance_plan(plan_id: plan.id, step_id: step_id)
      expect(result[:success]).to be true
    end

    it 'returns updated progress' do
      result = host.advance_plan(plan_id: plan.id, step_id: step_id)
      expect(result[:plan_progress]).to eq(0.5)
    end

    it 'returns error for unknown plan' do
      result = host.advance_plan(plan_id: 'bad', step_id: step_id)
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#fail_plan_step' do
    let(:plan) { store.create_plan(goal: 'test', steps: basic_steps) }
    let(:step_id) { plan.steps.first.id }

    it 'returns success' do
      result = host.fail_plan_step(plan_id: plan.id, step_id: step_id, reason: 'timeout')
      expect(result[:success]).to be true
    end

    it 'marks the step as failed' do
      host.fail_plan_step(plan_id: plan.id, step_id: step_id)
      expect(plan.steps.first.status).to eq(:failed)
    end

    it 'returns error for unknown plan' do
      result = host.fail_plan_step(plan_id: 'bad', step_id: step_id)
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#replan' do
    let(:plan) { store.create_plan(goal: 'test', steps: basic_steps) }
    let(:new_steps) { [{ action: :revised }] }

    it 'returns success' do
      result = host.replan(plan_id: plan.id, new_steps: new_steps)
      expect(result[:success]).to be true
    end

    it 'returns updated replan_count' do
      result = host.replan(plan_id: plan.id, new_steps: new_steps)
      expect(result[:replan_count]).to eq(1)
    end

    it 'includes reason in result' do
      result = host.replan(plan_id: plan.id, new_steps: new_steps, reason: 'pivot')
      expect(result[:reason]).to eq('pivot')
    end

    it 'returns error when limit reached' do
      Legion::Extensions::Planning::Helpers::Constants::REPLAN_LIMIT.times do
        host.replan(plan_id: plan.id, new_steps: new_steps)
      end
      result = host.replan(plan_id: plan.id, new_steps: new_steps)
      expect(result[:error]).to eq('replan limit reached')
    end
  end

  describe '#abandon_plan' do
    let(:plan) { store.create_plan(goal: 'test', steps: basic_steps) }

    it 'returns success' do
      result = host.abandon_plan(plan_id: plan.id, reason: 'cancelled')
      expect(result[:success]).to be true
    end

    it 'moves plan to history' do
      host.abandon_plan(plan_id: plan.id)
      expect(store.plans).not_to have_key(plan.id)
    end

    it 'returns error for unknown plan' do
      result = host.abandon_plan(plan_id: 'bad')
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#plan_status' do
    let(:plan) { store.create_plan(goal: 'test', steps: basic_steps) }

    it 'returns plan progress hash' do
      result = host.plan_status(plan_id: plan.id)
      expect(result[:plan_id]).to eq(plan.id)
      expect(result[:goal]).to eq('test')
      expect(result[:progress]).to eq(0.0)
    end

    it 'returns error for unknown plan' do
      result = host.plan_status(plan_id: 'bad')
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#active_plans' do
    it 'returns empty when no plans' do
      result = host.active_plans
      expect(result[:count]).to eq(0)
      expect(result[:plans]).to be_empty
    end

    it 'returns count and plan hashes' do
      store.create_plan(goal: 'plan1', steps: basic_steps)
      store.create_plan(goal: 'plan2', steps: [])
      result = host.active_plans
      expect(result[:count]).to eq(2)
      expect(result[:plans]).to all(be_a(Hash))
    end
  end

  describe '#planning_stats' do
    it 'returns stats hash' do
      store.create_plan(goal: 'test', steps: basic_steps)
      result = host.planning_stats
      expect(result[:active_plan_count]).to eq(1)
      expect(result).to have_key(:by_status)
      expect(result).to have_key(:avg_progress)
    end
  end

  describe '#update_planning' do
    it 'returns summary hash' do
      result = host.update_planning(tick_results: {})
      expect(result).to have_key(:active_plans)
      expect(result).to have_key(:total_steps)
      expect(result[:stale_checked]).to be true
    end

    it 'auto-advances steps from tick completed_actions' do
      plan = store.create_plan(goal: 'auto', steps: basic_steps)
      step_id = plan.steps.first.id
      tick_results = {
        action_selection: {
          completed_actions: [{ action: :step_one, result: 'ok' }]
        }
      }
      host.update_planning(tick_results: tick_results)
      expect(plan.steps.first.status).to eq(:completed)
      _ = step_id
    end

    it 'does nothing when no completed_actions in tick_results' do
      store.create_plan(goal: 'manual', steps: basic_steps)
      result = host.update_planning(tick_results: {})
      expect(result[:stale_checked]).to be true
    end
  end
end
