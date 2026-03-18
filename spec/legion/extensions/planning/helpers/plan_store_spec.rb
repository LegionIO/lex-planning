# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Planning::Helpers::PlanStore do
  subject(:store) { described_class.new }

  let(:basic_steps) do
    [
      { action: :step_one, description: 'First step' },
      { action: :step_two, description: 'Second step' }
    ]
  end

  def create_basic_plan(goal: 'test goal', steps: basic_steps, priority: :medium)
    store.create_plan(goal: goal, steps: steps, priority: priority)
  end

  describe '#initialize' do
    it 'starts with empty plans' do
      expect(store.plans).to be_empty
    end

    it 'starts with empty plan_history' do
      expect(store.plan_history).to be_empty
    end
  end

  describe '#create_plan' do
    it 'creates a plan and stores it' do
      plan = create_basic_plan
      expect(store.plans).to have_key(plan.id)
    end

    it 'returns a Plan instance' do
      expect(create_basic_plan).to be_a(Legion::Extensions::Planning::Helpers::Plan)
    end

    it 'sets plan status to :active' do
      plan = create_basic_plan
      expect(plan.status).to eq(:active)
    end

    it 'creates PlanStep objects from hashes' do
      plan = create_basic_plan
      expect(plan.steps).to all(be_a(Legion::Extensions::Planning::Helpers::PlanStep))
    end

    it 'accepts PlanStep objects directly' do
      step = Legion::Extensions::Planning::Helpers::PlanStep.new(action: :direct)
      plan = store.create_plan(goal: 'direct', steps: [step])
      expect(plan.steps.first).to eq(step)
    end

    it 'stores contingencies' do
      plan = store.create_plan(goal: 'goal', contingencies: { step_one: :retry })
      expect(plan.contingencies).to eq({ step_one: :retry })
    end

    it 'stores parent_plan_id' do
      plan = store.create_plan(goal: 'sub', parent_plan_id: 'parent-id')
      expect(plan.parent_plan_id).to eq('parent-id')
    end

    it 'rejects when steps exceed MAX_STEPS_PER_PLAN' do
      oversized = Array.new(Legion::Extensions::Planning::Helpers::Constants::MAX_STEPS_PER_PLAN + 1) do |i|
        { action: :"step_#{i}" }
      end
      result = store.create_plan(goal: 'too many steps', steps: oversized)
      expect(result[:error]).to include('steps exceed limit')
    end

    it 'rejects when contingencies exceed MAX_CONTINGENCIES' do
      oversized = (1..(Legion::Extensions::Planning::Helpers::Constants::MAX_CONTINGENCIES + 1)).to_h do |i|
        [:"action_#{i}", :retry]
      end
      result = store.create_plan(goal: 'too many contingencies', contingencies: oversized)
      expect(result[:error]).to include('contingencies exceed limit')
    end

    it 'accepts steps at exactly MAX_STEPS_PER_PLAN' do
      exact = Array.new(Legion::Extensions::Planning::Helpers::Constants::MAX_STEPS_PER_PLAN) do |i|
        { action: :"step_#{i}" }
      end
      plan = store.create_plan(goal: 'max steps', steps: exact)
      expect(plan).to be_a(Legion::Extensions::Planning::Helpers::Plan)
    end

    it 'accepts contingencies at exactly MAX_CONTINGENCIES' do
      exact = (1..Legion::Extensions::Planning::Helpers::Constants::MAX_CONTINGENCIES).to_h do |i|
        [:"action_#{i}", :retry]
      end
      plan = store.create_plan(goal: 'max contingencies', contingencies: exact)
      expect(plan).to be_a(Legion::Extensions::Planning::Helpers::Plan)
    end
  end

  describe '#find_plan' do
    it 'returns the plan by id' do
      plan = create_basic_plan
      expect(store.find_plan(plan.id)).to eq(plan)
    end

    it 'returns nil for unknown id' do
      expect(store.find_plan('nonexistent')).to be_nil
    end
  end

  describe '#advance_step' do
    let(:plan) { create_basic_plan }
    let(:step_id) { plan.steps.first.id }

    it 'returns success' do
      result = store.advance_step(plan_id: plan.id, step_id: step_id)
      expect(result[:success]).to be true
    end

    it 'returns the updated progress' do
      result = store.advance_step(plan_id: plan.id, step_id: step_id)
      expect(result[:plan_progress]).to eq(0.5)
    end

    it 'returns error for unknown plan' do
      result = store.advance_step(plan_id: 'bad', step_id: step_id)
      expect(result[:error]).to eq('plan not found')
    end

    it 'returns error for unknown step' do
      result = store.advance_step(plan_id: plan.id, step_id: 'bad-step')
      expect(result[:error]).to eq('step not found')
    end

    it 'archives plan when all steps complete' do
      plan.steps.each do |s|
        store.advance_step(plan_id: plan.id, step_id: s.id)
      end
      expect(store.plans).not_to have_key(plan.id)
      expect(store.plan_history).to include(plan)
    end
  end

  describe '#fail_step' do
    let(:plan) { create_basic_plan }
    let(:step_id) { plan.steps.first.id }

    it 'returns success' do
      result = store.fail_step(plan_id: plan.id, step_id: step_id, reason: 'error')
      expect(result[:success]).to be true
    end

    it 'returns contingency when defined' do
      plan_with_cont = store.create_plan(
        goal:          'contingent',
        steps:         basic_steps,
        contingencies: { step_one: :retry }
      )
      step = plan_with_cont.steps.first
      result = store.fail_step(plan_id: plan_with_cont.id, step_id: step.id)
      expect(result[:contingency]).to eq(:retry)
    end

    it 'returns nil contingency when not defined' do
      result = store.fail_step(plan_id: plan.id, step_id: step_id)
      expect(result[:contingency]).to be_nil
    end

    it 'returns error for unknown plan' do
      result = store.fail_step(plan_id: 'bad', step_id: step_id)
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#replan' do
    let(:plan) { create_basic_plan }
    let(:new_steps) { [{ action: :revised_step }] }

    it 'returns success' do
      result = store.replan(plan_id: plan.id, new_steps: new_steps)
      expect(result[:success]).to be true
    end

    it 'increments replan_count' do
      store.replan(plan_id: plan.id, new_steps: new_steps)
      expect(plan.replan_count).to eq(1)
    end

    it 'replaces pending steps' do
      store.replan(plan_id: plan.id, new_steps: new_steps)
      actions = plan.steps.select { |s| s.status == :pending }.map(&:action)
      expect(actions).to include(:revised_step)
    end

    it 'rejects when replan limit exceeded' do
      Legion::Extensions::Planning::Helpers::Constants::REPLAN_LIMIT.times do
        store.replan(plan_id: plan.id, new_steps: new_steps)
      end
      result = store.replan(plan_id: plan.id, new_steps: new_steps)
      expect(result[:error]).to eq('replan limit reached')
    end

    it 'returns error for unknown plan' do
      result = store.replan(plan_id: 'bad', new_steps: new_steps)
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#abandon_plan' do
    let(:plan) { create_basic_plan }

    it 'returns success' do
      result = store.abandon_plan(plan_id: plan.id)
      expect(result[:success]).to be true
    end

    it 'sets plan status to :abandoned' do
      store.abandon_plan(plan_id: plan.id)
      expect(plan.status).to eq(:abandoned)
    end

    it 'moves plan to history' do
      store.abandon_plan(plan_id: plan.id)
      expect(store.plans).not_to have_key(plan.id)
      expect(store.plan_history).to include(plan)
    end

    it 'returns error for unknown plan' do
      result = store.abandon_plan(plan_id: 'bad')
      expect(result[:error]).to eq('plan not found')
    end
  end

  describe '#active_plans' do
    it 'returns empty when no active plans' do
      expect(store.active_plans).to be_empty
    end

    it 'returns plans with :active status' do
      plan = create_basic_plan
      expect(store.active_plans).to include(plan)
    end

    it 'includes :executing plans' do
      plan = create_basic_plan
      plan.status = :executing
      expect(store.active_plans).to include(plan)
    end

    it 'excludes completed plans' do
      plan = create_basic_plan
      plan.status = :completed
      expect(store.active_plans).not_to include(plan)
    end
  end

  describe '#completed_plans' do
    it 'returns empty when no history' do
      expect(store.completed_plans).to be_empty
    end

    it 'returns archived plans' do
      plan = create_basic_plan
      plan.steps.each { |s| store.advance_step(plan_id: plan.id, step_id: s.id) }
      expect(store.completed_plans).to include(plan)
    end

    it 'respects the limit parameter' do
      3.times { |i| store.abandon_plan(plan_id: create_basic_plan(goal: "goal_#{i}").id) }
      expect(store.completed_plans(limit: 2).size).to eq(2)
    end
  end

  describe '#plan_progress' do
    let(:plan) { create_basic_plan }

    it 'returns progress hash' do
      result = store.plan_progress(plan.id)
      expect(result[:plan_id]).to eq(plan.id)
      expect(result[:goal]).to eq('test goal')
      expect(result[:progress]).to eq(0.0)
      expect(result[:total_steps]).to eq(2)
    end

    it 'counts completed steps' do
      store.advance_step(plan_id: plan.id, step_id: plan.steps.first.id)
      expect(store.plan_progress(plan.id)[:completed]).to eq(1)
    end

    it 'includes next_ready step ids' do
      result = store.plan_progress(plan.id)
      expect(result[:next_ready]).to include(plan.steps.first.id)
    end

    it 'returns error for unknown plan' do
      result = store.plan_progress('nonexistent')
      expect(result[:error]).to eq('plan not found')
    end

    it 'can look up archived plans' do
      store.abandon_plan(plan_id: plan.id)
      result = store.plan_progress(plan.id)
      expect(result[:plan_id]).to eq(plan.id)
    end
  end

  describe '#plans_by_priority' do
    it 'returns plans sorted highest priority first' do
      store.create_plan(goal: 'low', steps: [], priority: :low)
      store.create_plan(goal: 'critical', steps: [], priority: :critical)
      store.create_plan(goal: 'medium', steps: [], priority: :medium)
      sorted = store.plans_by_priority
      expect(sorted.first.goal).to eq('critical')
      expect(sorted.last.goal).to eq('low')
    end
  end

  describe '#stats' do
    it 'returns a stats hash' do
      result = store.stats
      expect(result).to have_key(:active_plan_count)
      expect(result).to have_key(:archived_plan_count)
      expect(result).to have_key(:by_status)
      expect(result).to have_key(:avg_progress)
      expect(result).to have_key(:replan_rate)
    end

    it 'counts active plans' do
      create_basic_plan
      expect(store.stats[:active_plan_count]).to eq(1)
    end

    it 'counts archived plans' do
      plan = create_basic_plan
      store.abandon_plan(plan_id: plan.id)
      expect(store.stats[:archived_plan_count]).to eq(1)
    end

    it 'returns 0.0 avg_progress with no plans' do
      expect(store.stats[:avg_progress]).to eq(0.0)
    end
  end

  describe '#trim_history' do
    it 'archives oldest plan when MAX_PLANS is exceeded' do
      max = Legion::Extensions::Planning::Helpers::Constants::MAX_PLANS
      (max + 2).times { |i| store.create_plan(goal: "goal_#{i}", steps: []) }
      expect(store.plans.size).to eq(max)
    end
  end
end
