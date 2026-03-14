# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module Planning
      module Helpers
        class Plan
          attr_reader :id, :goal, :description, :priority, :steps, :contingencies,
                      :parent_plan_id, :created_at, :replan_count
          attr_accessor :status, :updated_at

          def initialize(goal:, steps: [], priority: :medium, contingencies: {}, parent_plan_id: nil, description: nil, **)
            @id             = SecureRandom.uuid
            @goal           = goal
            @description    = description
            @priority       = priority
            @status         = :forming
            @steps          = steps.dup
            @contingencies  = contingencies.dup
            @parent_plan_id = parent_plan_id
            @created_at     = Time.now.utc
            @updated_at     = Time.now.utc
            @replan_count   = 0
          end

          def progress
            return 0.0 if @steps.empty?

            done = @steps.count { |s| %i[completed skipped].include?(s.status) }
            done.to_f / @steps.size
          end

          def active_step
            @steps.find { |s| s.status == :active }
          end

          def completed_step_ids
            @steps.select { |s| %i[completed skipped].include?(s.status) }.map(&:id)
          end

          def advance!(step_id, result: nil)
            step = @steps.find { |s| s.id == step_id }
            return nil unless step

            step.complete!(result: result)
            @updated_at = Time.now.utc
            @status = :completed if progress >= Constants::COMPLETION_THRESHOLD
            step
          end

          def fail_step!(step_id, reason: nil)
            step = @steps.find { |s| s.id == step_id }
            return nil unless step

            step.fail!(reason: reason)
            @updated_at = Time.now.utc
            step
          end

          def complete?
            @status == :completed || progress >= Constants::COMPLETION_THRESHOLD
          end

          def failed?
            @status == :failed
          end

          def stale?
            (Time.now.utc - @updated_at) > Constants::STALE_PLAN_THRESHOLD
          end

          def increment_replan!
            @replan_count += 1
            @updated_at = Time.now.utc
          end

          def replace_remaining_steps!(new_steps)
            pending = @steps.reject { |s| %i[completed skipped failed].include?(s.status) }
            pending.each { |s| @steps.delete(s) }
            new_steps.each { |s| @steps << s }
            @updated_at = Time.now.utc
          end

          def to_h
            {
              id:             @id,
              goal:           @goal,
              description:    @description,
              priority:       @priority,
              status:         @status,
              progress:       progress.round(4),
              steps:          @steps.map(&:to_h),
              contingencies:  @contingencies,
              parent_plan_id: @parent_plan_id,
              replan_count:   @replan_count,
              created_at:     @created_at,
              updated_at:     @updated_at
            }
          end
        end
      end
    end
  end
end
