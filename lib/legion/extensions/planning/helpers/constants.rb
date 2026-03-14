# frozen_string_literal: true

module Legion
  module Extensions
    module Planning
      module Helpers
        module Constants
          PLAN_STATUSES  = %i[forming active executing completed failed abandoned].freeze
          STEP_STATUSES  = %i[pending active completed failed skipped blocked].freeze
          PRIORITIES     = { critical: 1.0, high: 0.75, medium: 0.5, low: 0.25 }.freeze
          MAX_PLANS      = 50
          MAX_STEPS_PER_PLAN  = 100
          MAX_CONTINGENCIES   = 20
          REPLAN_LIMIT        = 3
          STALE_PLAN_THRESHOLD   = 3600
          COMPLETION_THRESHOLD   = 0.95
          PLANNING_HORIZON       = 10
        end
      end
    end
  end
end
