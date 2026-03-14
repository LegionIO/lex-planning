# frozen_string_literal: true

require 'legion/extensions/planning/version'
require 'legion/extensions/planning/helpers/constants'
require 'legion/extensions/planning/helpers/plan_step'
require 'legion/extensions/planning/helpers/plan'
require 'legion/extensions/planning/helpers/plan_store'
require 'legion/extensions/planning/runners/planning'
require 'legion/extensions/planning/client'

module Legion
  module Extensions
    module Planning
      extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core)
    end
  end
end
