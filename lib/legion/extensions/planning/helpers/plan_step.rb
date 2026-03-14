# frozen_string_literal: true

require 'securerandom'

module Legion
  module Extensions
    module Planning
      module Helpers
        class PlanStep
          attr_reader :id, :action, :description, :depends_on, :estimated_effort,
                      :started_at, :completed_at, :result
          attr_accessor :status, :actual_effort

          def initialize(action:, description: nil, depends_on: [], estimated_effort: 1, **)
            @id               = SecureRandom.uuid
            @action           = action
            @description      = description
            @status           = :pending
            @depends_on       = Array(depends_on).dup
            @estimated_effort = estimated_effort
            @actual_effort    = nil
            @result           = nil
            @started_at       = nil
            @completed_at     = nil
          end

          def ready?(completed_step_ids)
            return false if %i[completed failed skipped].include?(@status)

            @depends_on.all? { |dep_id| completed_step_ids.include?(dep_id) }
          end

          def duration
            return nil unless @started_at && @completed_at

            @completed_at - @started_at
          end

          def blocked?
            @status == :blocked
          end

          def complete!(result: nil)
            @status       = :completed
            @result       = result
            @completed_at = Time.now.utc
          end

          def fail!(reason: nil)
            @status       = :failed
            @result       = { reason: reason }
            @completed_at = Time.now.utc
          end

          def start!
            @status     = :active
            @started_at = Time.now.utc
          end

          def to_h
            {
              id:               @id,
              action:           @action,
              description:      @description,
              status:           @status,
              depends_on:       @depends_on,
              estimated_effort: @estimated_effort,
              actual_effort:    @actual_effort,
              result:           @result,
              started_at:       @started_at,
              completed_at:     @completed_at
            }
          end
        end
      end
    end
  end
end
