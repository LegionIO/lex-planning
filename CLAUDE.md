# lex-planning

**Level 3 Leaf Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Gem**: `lex-planning`
- **Version**: 0.1.1
- **Namespace**: `Legion::Extensions::Planning`

## Purpose

Goal-directed planning engine. Maintains a store of `Plan` objects, each containing an ordered set of `PlanStep` objects with dependency tracking. Plans advance as steps complete, can be replanned up to `REPLAN_LIMIT` times, and are automatically detected as stale after `STALE_PLAN_THRESHOLD` seconds. On each tick, `update_planning` checks for stale plans and auto-advances steps whose dependencies are satisfied by completed actions from the tick.

## Gem Info

- **Homepage**: https://github.com/LegionIO/lex-planning
- **License**: MIT
- **Ruby**: >= 3.4

## File Structure

```
lib/legion/extensions/planning/
  version.rb
  client.rb
  helpers/
    constants.rb      # Statuses, priorities, limits, thresholds
    plan_step.rb      # PlanStep class — single action with dependency tracking
    plan.rb           # Plan class — goal + steps + progress
    plan_store.rb     # PlanStore — creates, advances, archives plans
  runners/
    planning.rb       # Runner module
spec/
  helpers/constants_spec.rb
  helpers/plan_step_spec.rb
  helpers/plan_spec.rb
  helpers/plan_store_spec.rb
  runners/planning_spec.rb
  client_spec.rb
```

## Key Constants

From `Helpers::Constants`:
- `PLAN_STATUSES = %i[forming active executing completed failed abandoned]`
- `STEP_STATUSES = %i[pending active completed failed skipped blocked]`
- `PRIORITIES = { critical: 1.0, high: 0.75, medium: 0.5, low: 0.25 }`
- `MAX_PLANS = 50`, `MAX_STEPS_PER_PLAN = 100`, `MAX_CONTINGENCIES = 20`
- `REPLAN_LIMIT = 3`, `STALE_PLAN_THRESHOLD = 3600` (seconds)
- `COMPLETION_THRESHOLD = 0.95` (progress fraction to auto-complete)
- `PLANNING_HORIZON = 10`

## Runners

| Method | Key Parameters | Returns |
|---|---|---|
| `update_planning` | `tick_results: {}` | `{ active_plans:, total_steps:, stale_checked: }` |
| `create_plan` | `goal:`, `steps:`, `priority:`, `contingencies:`, `parent_plan_id:` | `{ success:, plan_id:, goal:, steps: }` |
| `advance_plan` | `plan_id:`, `step_id:`, `result: {}` | `{ success:, step_id:, plan_progress:, plan_status: }` |
| `fail_plan_step` | `plan_id:`, `step_id:`, `reason:` | `{ success:, step_id:, contingency:, plan_status: }` |
| `replan` | `plan_id:`, `new_steps:`, `reason:` | `{ success:, plan_id:, replan_count:, reason: }` |
| `abandon_plan` | `plan_id:`, `reason:` | `{ success:, plan_id:, reason: }` |
| `plan_status` | `plan_id:` | progress details with step counts, next_ready IDs, stale flag |
| `active_plans` | — | `{ plans:, count: }` |
| `planning_stats` | — | active/archived counts, by_status, avg_progress, replan_rate |

## Helpers

### `Helpers::PlanStep`
Single action node: `id`, `action`, `description`, `status`, `depends_on` (array of step IDs), `estimated_effort`, `actual_effort`, `result`, `started_at`, `completed_at`. `ready?(completed_step_ids)` = all `depends_on` IDs are in the completed set. `complete!(result:)`, `fail!(reason:)`, `start!` transition status. `duration` = elapsed time if both timestamps set.

### `Helpers::Plan`
Goal container: `id`, `goal`, `description`, `priority`, `status`, `steps` (array of PlanStep), `contingencies` (hash), `parent_plan_id`, `replan_count`, timestamps. `progress` = completed+skipped steps / total. `advance!(step_id, result:)` completes step and auto-sets plan status to `:completed` if progress >= `COMPLETION_THRESHOLD`. `fail_step!(step_id, reason:)`. `stale?` = `updated_at` > `STALE_PLAN_THRESHOLD` seconds ago. `replace_remaining_steps!(new_steps)` removes pending/active steps and appends new ones.

### `Helpers::PlanStore`
In-memory `@plans` hash + `@plan_history` array. `create_plan` converts step hashes to `PlanStep` objects. `advance_step` auto-archives completed plans. `fail_step` returns contingency if defined in plan's `contingencies` hash. `replan` enforces `REPLAN_LIMIT`. `abandon_plan` archives with `:abandoned` status. `plan_progress` looks up both active and archived plans. `plans_by_priority` sorts by priority value descending. Oldest plan evicted when count exceeds `MAX_PLANS`.

## Integration Points

- `update_planning` reads `tick_results[:action_selection][:completed_actions]` to auto-advance ready steps
- `create_plan` output feeds `lex-volition` for intention tracking
- `plan_status` progress can gate `lex-consent` tier advancement
- Stale plan detection logs to `lex-reflection`'s cognitive health monitor
- `parent_plan_id` supports hierarchical planning for `lex-cortex` multi-level goal decomposition
- Contingency map in `fail_plan_step` can trigger `lex-conflict` resolution workflows

## Development Notes

- `replan` replaces only pending/active steps; completed steps are preserved
- `COMPLETION_THRESHOLD = 0.95` means a plan can complete with up to 5% of steps skipped/failed
- `plans_by_priority` uses `PRIORITIES` hash with fallback to 0.5 for unknown priority symbols
- `plan_progress` can retrieve archived plans from `@plan_history` by linear search
- `update_planning` uses `tick_results.dig(:action_selection, :completed_actions)` — returns early if not an Array
- `update_planning` scopes stale checks and auto-advance to `PLANNING_HORIZON` (10) highest-priority plans per tick
- `create_plan` rejects steps arrays exceeding `MAX_STEPS_PER_PLAN` (100) and contingency hashes exceeding `MAX_CONTINGENCIES` (20)
- All state is in-memory; reset on process restart
