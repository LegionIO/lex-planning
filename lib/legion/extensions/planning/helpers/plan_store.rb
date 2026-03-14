# frozen_string_literal: true

module Legion
  module Extensions
    module Planning
      module Helpers
        class PlanStore
          attr_reader :plans, :plan_history

          def initialize
            @plans        = {}
            @plan_history = []
          end

          def create_plan(goal:, steps: [], priority: :medium, contingencies: {}, parent_plan_id: nil, **)
            step_objects = steps.map do |s|
              s.is_a?(PlanStep) ? s : PlanStep.new(**s)
            end
            plan = Plan.new(
              goal:           goal,
              steps:          step_objects,
              priority:       priority,
              contingencies:  contingencies,
              parent_plan_id: parent_plan_id
            )
            plan.status = :active
            @plans[plan.id] = plan
            trim_history
            plan
          end

          def find_plan(plan_id)
            @plans[plan_id]
          end

          def advance_step(plan_id:, step_id:, result: {})
            plan = @plans[plan_id]
            return { error: 'plan not found' } unless plan

            step = plan.advance!(step_id, result: result)
            return { error: 'step not found' } unless step

            if plan.complete?
              plan.status = :completed
              archive_plan(plan_id)
            end

            { success: true, step_id: step_id, plan_progress: plan.progress.round(4), plan_status: plan.status }
          end

          def fail_step(plan_id:, step_id:, reason: nil)
            plan = @plans[plan_id]
            return { error: 'plan not found' } unless plan

            step = plan.fail_step!(step_id, reason: reason)
            return { error: 'step not found' } unless step

            contingency = plan.contingencies[step.action] || plan.contingencies[step_id]
            { success: true, step_id: step_id, contingency: contingency, plan_status: plan.status }
          end

          def replan(plan_id:, new_steps:, reason: nil)
            plan = @plans[plan_id]
            return { error: 'plan not found' } unless plan
            return { error: 'replan limit reached' } if plan.replan_count >= Constants::REPLAN_LIMIT

            step_objects = new_steps.map do |s|
              s.is_a?(PlanStep) ? s : PlanStep.new(**s)
            end
            plan.increment_replan!
            plan.replace_remaining_steps!(step_objects)
            plan.status = :active

            { success: true, plan_id: plan_id, replan_count: plan.replan_count, reason: reason }
          end

          def abandon_plan(plan_id:, reason: nil)
            plan = @plans[plan_id]
            return { error: 'plan not found' } unless plan

            plan.status = :abandoned
            archive_plan(plan_id)
            { success: true, plan_id: plan_id, reason: reason }
          end

          def active_plans
            @plans.values.select { |p| %i[active executing].include?(p.status) }
          end

          def completed_plans(limit: 10)
            @plan_history.last(limit)
          end

          def plan_progress(plan_id)
            plan = @plans[plan_id] || @plan_history.find { |p| p.id == plan_id }
            return { error: 'plan not found' } unless plan

            ready_ids = plan.completed_step_ids
            {
              plan_id:      plan_id,
              goal:         plan.goal,
              status:       plan.status,
              progress:     plan.progress.round(4),
              total_steps:  plan.steps.size,
              completed:    plan.steps.count { |s| s.status == :completed },
              failed:       plan.steps.count { |s| s.status == :failed },
              pending:      plan.steps.count { |s| s.status == :pending },
              blocked:      plan.steps.count { |s| s.status == :blocked },
              next_ready:   plan.steps.select { |s| s.status == :pending && s.ready?(ready_ids) }.map(&:id),
              replan_count: plan.replan_count,
              stale:        plan.stale?
            }
          end

          def plans_by_priority
            priority_value = ->(p) { Constants::PRIORITIES.fetch(p.priority, 0.5) }
            @plans.values.sort_by { |p| -priority_value.call(p) }
          end

          def stats
            all = @plans.values
            total = all.size + @plan_history.size
            by_status = Constants::PLAN_STATUSES.to_h { |s| [s, all.count { |p| p.status == s }] }
            replanned = all.count { |p| p.replan_count.positive? }
            avg_progress = all.empty? ? 0.0 : (all.sum(&:progress) / all.size).round(4)
            replan_rate = total.zero? ? 0.0 : (replanned.to_f / [all.size, 1].max).round(4)

            {
              active_plan_count:   all.size,
              archived_plan_count: @plan_history.size,
              by_status:           by_status,
              avg_progress:        avg_progress,
              replan_rate:         replan_rate
            }
          end

          def trim_history
            return unless @plans.size > Constants::MAX_PLANS

            oldest_id = @plans.keys.min_by { |k| @plans[k].created_at }
            archive_plan(oldest_id)
          end

          private

          def archive_plan(plan_id)
            plan = @plans.delete(plan_id)
            return unless plan

            @plan_history << plan
            @plan_history.shift while @plan_history.size > Constants::MAX_PLANS
          end
        end
      end
    end
  end
end
