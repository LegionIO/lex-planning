# frozen_string_literal: true

module Legion
  module Extensions
    module Planning
      module Runners
        module Planning
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def update_planning(tick_results: {}, **)
            check_stale_plans
            advance_ready_steps(tick_results)

            active = plan_store.active_plans
            Legion::Logging.debug "[planning] active_plans=#{active.size} stats=#{plan_store.stats[:by_status]}"

            {
              active_plans:  active.size,
              total_steps:   active.sum { |p| p.steps.size },
              stale_checked: true
            }
          end

          def create_plan(goal:, steps: [], priority: :medium, contingencies: {}, parent_plan_id: nil, **)
            steps_data = steps.map { |s| s.is_a?(Hash) ? s : s.to_h }
            plan = plan_store.create_plan(
              goal:           goal,
              steps:          steps_data,
              priority:       priority,
              contingencies:  contingencies,
              parent_plan_id: parent_plan_id
            )
            Legion::Logging.info "[planning] created plan=#{plan.id} goal=#{goal} steps=#{plan.steps.size}"
            { success: true, plan_id: plan.id, goal: goal, steps: plan.steps.size }
          end

          def advance_plan(plan_id:, step_id:, result: {}, **)
            outcome = plan_store.advance_step(plan_id: plan_id, step_id: step_id, result: result)
            Legion::Logging.debug "[planning] advance plan=#{plan_id} step=#{step_id} outcome=#{outcome[:plan_status]}"
            outcome
          end

          def fail_plan_step(plan_id:, step_id:, reason: nil, **)
            outcome = plan_store.fail_step(plan_id: plan_id, step_id: step_id, reason: reason)
            Legion::Logging.warn "[planning] step failed plan=#{plan_id} step=#{step_id} reason=#{reason}"
            outcome
          end

          def replan(plan_id:, new_steps: [], reason: nil, **)
            steps_data = new_steps.map { |s| s.is_a?(Hash) ? s : s.to_h }
            outcome = plan_store.replan(plan_id: plan_id, new_steps: steps_data, reason: reason)
            if outcome[:success]
              Legion::Logging.info "[planning] replan plan=#{plan_id} count=#{outcome[:replan_count]} reason=#{reason}"
            else
              Legion::Logging.warn "[planning] replan rejected plan=#{plan_id} reason=#{outcome[:error]}"
            end
            outcome
          end

          def abandon_plan(plan_id:, reason: nil, **)
            outcome = plan_store.abandon_plan(plan_id: plan_id, reason: reason)
            Legion::Logging.info "[planning] abandoned plan=#{plan_id} reason=#{reason}"
            outcome
          end

          def plan_status(plan_id:, **)
            outcome = plan_store.plan_progress(plan_id)
            Legion::Logging.debug "[planning] status plan=#{plan_id} progress=#{outcome[:progress]}"
            outcome
          end

          def active_plans(**)
            plans = plan_store.active_plans
            Legion::Logging.debug "[planning] active_plans=#{plans.size}"
            {
              plans: plans.map(&:to_h),
              count: plans.size
            }
          end

          def planning_stats(**)
            stats = plan_store.stats
            Legion::Logging.debug "[planning] stats=#{stats}"
            stats
          end

          private

          def plan_store
            @plan_store ||= Helpers::PlanStore.new
          end

          def check_stale_plans
            plan_store.active_plans.each do |plan|
              Legion::Logging.warn "[planning] stale plan detected plan=#{plan.id} goal=#{plan.goal}" if plan.stale?
            end
          end

          def advance_ready_steps(tick_results)
            completed_actions = tick_results.dig(:action_selection, :completed_actions)
            return unless completed_actions.is_a?(Array)

            plan_store.active_plans.each do |plan|
              ready_ids = plan.completed_step_ids
              plan.steps.each do |step|
                next unless step.status == :pending && step.ready?(ready_ids)
                next unless completed_actions.any? { |a| a[:action] == step.action }

                result = completed_actions.find { |a| a[:action] == step.action }
                plan_store.advance_step(plan_id: plan.id, step_id: step.id, result: result)
              end
            end
          end
        end
      end
    end
  end
end
