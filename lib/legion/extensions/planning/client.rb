# frozen_string_literal: true

require 'legion/extensions/planning/helpers/constants'
require 'legion/extensions/planning/helpers/plan_step'
require 'legion/extensions/planning/helpers/plan'
require 'legion/extensions/planning/helpers/plan_store'
require 'legion/extensions/planning/runners/planning'

module Legion
  module Extensions
    module Planning
      class Client
        include Runners::Planning

        attr_reader :plan_store

        def initialize(plan_store: nil, **)
          @plan_store = plan_store || Helpers::PlanStore.new
        end
      end
    end
  end
end
