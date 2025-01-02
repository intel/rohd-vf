## 0.6.0

- Updates ROHD dependency to at least v0.5.0.
- Fixed a bug where exceptions triggered via the ROHD simulator could cause a `Test` to hang (<https://github.com/intel/rohd-vf/pull/59>).
- Increased minimum Dart SDK version to 3.0.0.

## 0.5.0

- Updates ROHD dependency to at least v0.5.0.
- Breaking: `Test.instance` is now nullable and `null` when no `Test` is active, which also impacts `Test.random`. Use `Test.reset` instead of `Simulator.reset` in ROHD-VF testbenches to reset.
- Added `QuiesceObjector`, `PendingDriver`, and `PendingClockedDriver` to make it easier to develop typical drivers.
- Added `waitCycles` function as an extension to `Logic` to make it easier to wait for a variable number of clock edges.
- Fixed a bug where `Component`s directly under the `Test` could run the `check` phase multiple times (<https://github.com/intel/rohd-vf/issues/45>).
- Updated the example, leveraging some new APIs in ROHD-VF and ROHD and demonstrating best practices.
- Exposed `randomSeed` accessor in `Test` to make it easier to reproduce randomized tests.

## 0.4.1

- Fix a bug where `defaults` were not used in `Tracker.record` (<https://github.com/intel/rohd-vf/pull/27>).
- Added ability to view sub-components in a `Component` via `components`.
- The `check` phase now runs synchronously at the end of the `Test` rather than triggered through the ROHD Simulator, giving greater control when handling error conditions.
- Added `printLevel` to control printing independently of `Logger` level.  Decreasing verbosity at the `Logger` will disable failures/kills if those messages are supressed.
- Made handling of test failures/kills more robust and easier to handle.
- Fixed a bug where `Logger` subscriptions could persist across tests.
- Fixed a bug where failures reported via the `Logger` and found during `check` phase would sometimes not cause a test to fail.

## 0.4.0

- Updates ROHD dependency to at least v0.4.0.
- Breaking: made `columnWidth` an optional named argument in `TrackerField` (<https://github.com/intel/rohd-vf/issues/10>).
- Increased minimum Dart SDK version to 2.18.0.
- Upgraded and made lints more strict within ROHD-VF, leading to some quality and documentation improvements.

## 0.3.1

- `Stream`s in `Monitor` and `Sequencer` are now synchronous (fix <https://github.com/intel/rohd-vf/issues/8>).
- `Tracker` now writes to files asynchronously to improve performance (fix <https://github.com/intel/rohd-vf/issues/12>).
- Fixed bugs related to test, simulation, and objection completions (<https://github.com/intel/rohd-vf/pull/15>).

## 0.3.0

- Updates ROHD dependency to at least v0.3.0.

## 0.2.0

- Updates ROHD dependency to at least v0.2.0.
- Adds `Tracker` to make logging events during a test simple for reading or parsing.

## 0.1.1

- Fix documentation issues.

## 0.1.0

- The first formally versioned release of ROHD Verification Framework.
