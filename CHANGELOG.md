# Changelog

## [0.1.1] - 2026-03-18

### Fixed
- Enforce `MAX_STEPS_PER_PLAN` (100) in `PlanStore#create_plan` — rejects plans with more than 100 steps
- Enforce `MAX_CONTINGENCIES` (20) in `PlanStore#create_plan` — rejects plans with more than 20 contingencies
- Scope `update_planning` stale checks and auto-advance to top `PLANNING_HORIZON` (10) plans by priority — prevents unbounded iteration over all active plans per tick

## [0.1.0] - 2026-03-13

### Added
- Initial release: goal-directed planning engine with ordered step dependency graphs
- Plan lifecycle (forming, active, executing, completed, failed, abandoned)
- Replan support with configurable limit, contingency fallback
- Stale plan detection, auto-advance from tick completed actions
- Standalone Client
