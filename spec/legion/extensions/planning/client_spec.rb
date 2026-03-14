# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Planning::Client do
  describe '#initialize' do
    it 'creates a default plan store' do
      client = described_class.new
      expect(client.plan_store).to be_a(Legion::Extensions::Planning::Helpers::PlanStore)
    end

    it 'accepts an injected plan store' do
      store = Legion::Extensions::Planning::Helpers::PlanStore.new
      client = described_class.new(plan_store: store)
      expect(client.plan_store).to equal(store)
    end

    it 'ignores unknown keyword arguments' do
      expect { described_class.new(unknown: true) }.not_to raise_error
    end
  end

  describe 'runner integration' do
    subject(:client) { described_class.new }

    %i[
      create_plan
      advance_plan
      fail_plan_step
      replan
      abandon_plan
      plan_status
      active_plans
      planning_stats
      update_planning
    ].each do |method_name|
      it "responds to ##{method_name}" do
        expect(client).to respond_to(method_name)
      end
    end

    it 'can run a full planning workflow' do
      result = client.create_plan(
        goal:     'deliver feature',
        steps:    [
          { action: :design },
          { action: :implement },
          { action: :review }
        ],
        priority: :high
      )
      expect(result[:success]).to be true

      plan_id = result[:plan_id]
      plan    = client.plan_store.find_plan(plan_id)
      first_step  = plan.steps[0]
      second_step = plan.steps[1]

      adv1 = client.advance_plan(plan_id: plan_id, step_id: first_step.id, result: { done: true })
      expect(adv1[:success]).to be true
      expect(adv1[:plan_progress]).to be_within(0.01).of(0.333)

      adv2 = client.advance_plan(plan_id: plan_id, step_id: second_step.id)
      expect(adv2[:success]).to be true

      status = client.plan_status(plan_id: plan_id)
      expect(status[:completed]).to eq(2)

      stats = client.planning_stats
      expect(stats[:active_plan_count]).to be >= 1
    end

    it 'handles replan workflow' do
      result = client.create_plan(goal: 'replan test', steps: [{ action: :old_step }])
      plan_id = result[:plan_id]

      step_id = client.plan_store.find_plan(plan_id).steps.first.id
      client.fail_plan_step(plan_id: plan_id, step_id: step_id, reason: 'failed')

      replan_result = client.replan(plan_id: plan_id, new_steps: [{ action: :new_step }], reason: 'retry')
      expect(replan_result[:success]).to be true
      expect(replan_result[:replan_count]).to eq(1)
    end

    it 'handles abandon workflow' do
      result = client.create_plan(goal: 'to abandon', steps: [])
      abandon = client.abandon_plan(plan_id: result[:plan_id], reason: 'cancelled')
      expect(abandon[:success]).to be true
    end
  end
end
