# lex-planning

Goal-directed planning engine for the LegionIO cognitive architecture. Creates and tracks multi-step plans with dependency-aware execution and automatic replanning.

## What It Does

Maintains a store of goal-oriented plans. Each plan contains ordered steps with dependency tracking — a step becomes ready only when all its `depends_on` steps are completed. Plans advance automatically each tick as completed actions are matched to ready steps. Plans can be replanned up to 3 times when conditions change, and stale plans (not updated for 1 hour) are detected and flagged. Completed plans are archived for history.

## Usage

```ruby
client = Legion::Extensions::Planning::Client.new

# Create a plan with steps
result = client.create_plan(
  goal: 'Deploy authentication service',
  priority: :high,
  steps: [
    { action: :build_image, description: 'Build Docker image' },
    { action: :run_tests, description: 'Run test suite', depends_on: [] },
    { action: :push_image, description: 'Push to registry', depends_on: [:build_image] },
    { action: :deploy, description: 'Deploy to production', depends_on: [:push_image, :run_tests] }
  ],
  contingencies: { deploy: 'rollback_to_previous' }
)
plan_id = result[:plan_id]

# Advance steps as they complete
client.advance_plan(plan_id: plan_id, step_id: step_id, result: { exit_code: 0 })

# Handle step failure
client.fail_plan_step(plan_id: plan_id, step_id: step_id, reason: 'network timeout')
# => { success: true, step_id: ..., contingency: 'rollback_to_previous', plan_status: :active }

# Replan with new steps
client.replan(plan_id: plan_id, new_steps: [...], reason: 'requirements changed')

# Check plan progress
client.plan_status(plan_id: plan_id)
# => { status: :active, progress: 0.5, total_steps: 4, completed: 2,
#      next_ready: [...], replan_count: 0, stale: false }

# Get all active plans
client.active_plans
client.planning_stats
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
