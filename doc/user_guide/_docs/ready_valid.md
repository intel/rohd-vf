---
title: "Ready/Valid Verification"
permalink: /docs/ready-valid/
last_modified_at: 2026-8-2
toc: true
---

ROHD-VF provides protocol-neutral testbench utilities for ready/valid channels.
The utilities operate on raw `clk`, `reset`, `ready`, `valid`, and payload
signals, so they can verify a channel from any ROHD component library without
depending on its interface types.

## Basic Flow

Use a `ReadyValidChannelCodec` to convert between the hardware payload and a
semantic Dart value. `LogicValueReadyValidChannelCodec` is suitable for packed
`Logic` payloads.

`ReadyValidChannelSourceAgent` contains a sequencer and source driver. Add
`ReadyValidChannelItem` values to its `sequencer` to offer transactions. The
source holds an offered item until its `ready` input accepts it.

`ReadyValidChannelSinkAgent` drives consumer backpressure. Set `blockRate` for
randomized backpressure, or supply a `ReadyValidChannelActivity` for directed,
scripted, alternating, burst, or seeded-random activity.

```dart
final codec = LogicValueReadyValidChannelCodec<Logic>();
final source = ReadyValidChannelSourceAgent<Logic, LogicValue>(
    'source', testbench,
    clk: clk,
    reset: reset,
    ready: ready,
    valid: valid,
    data: data,
    codec: codec);
ReadyValidChannelSinkAgent('sink', testbench,
    clk: clk, reset: reset, ready: ready);

source.sequencer.add(ReadyValidChannelItem(LogicValue.ofInt(0x2a, 8)));
```

The complete executable composition is covered by
[`ready_valid_agent_test.dart`](../../../test/ready_valid_agent_test.dart).

## Monitoring And Ordering

`ReadyValidChannelMonitor` emits `ReadyValidChannelItem` events only for
accepted transfers. Feed its stream into `FlowScoreboard` to compare a flow:

- `FlowScoreboard.strict` requires one global FIFO order.
- `FlowScoreboard.perKey` requires FIFO order independently for each key.
- `FlowScoreboard.unordered` compares an unordered multiset.

Construct expectations before or during simulation, observe each monitored
event with its cycle and endpoint, then call `verifyComplete` from `Test.check`.

```dart
final expected = FlowScoreboard<LogicValue, Never>.strict()
  ..expectAll(values);
monitor.stream.listen((item) {
  expected.observe(item.payload, cycle: item.cycle!, endpoint: 'output');
});
```

Drivers establish `valid`, payload, and `ready` before a rising edge. Monitors
sample `previousValue` after `clk.nextPosedge`, which captures the values that
participated in that edge rather than the next sequential state.

## Channel Protocol Checks

`ReadyValidChannelChecker` samples one channel boundary and records structured
violations. Its default checks require known controls after reset and reject a
transfer during reset. Enable stalled-offer checks only when the channel
contract guarantees those properties:

- `validMustRemainAssertedWhileStalled`
- `payloadMustRemainStableWhileStalled`
- `maximumStallCycles`

The checker reports `rv.controls_known`, `rv.no_transfer_during_reset`,
`rv.valid_held_while_stalled`, `rv.payload_stable_while_stalled`, and
`rv.max_stall_cycles`. Violations log at `SEVERE` by default, allowing the
standard ROHD-VF `Test` lifecycle to fail the test. Set `reportViolations` to
false when a test needs to inspect `violations` directly.

## Retained Storage Status

`ReadyValidStorageStatusChecker` verifies the observable status of a
single-clock storage component. Connect its `capacity`, `occupancy`, `empty`,
and `full` inputs to the component's exported status signals.

```dart
ReadyValidStorageStatusChecker('status', testbench,
    clk: clk,
    reset: reset,
    capacity: fifoCapacity,
    occupancy: fifoOccupancy,
    empty: fifoEmpty,
    full: fifoFull);
```

After reset, the checker requires known status signals, enforces
$0 \le occupancy \le capacity$, and requires `empty` to match zero occupancy
and `full` to match capacity occupancy. Its rule IDs are `storage.status_known`,
`storage.occupancy_in_range`, `storage.empty_matches_occupancy`, and
`storage.full_matches_occupancy`.

The checker intentionally does not infer occupancy transitions from ready/valid
handshakes. Flushes, fall-through paths, and component-specific state changes
need an explicit component-level policy. It therefore composes well with the
channel monitor and scoreboard instead of replacing them. The complete checker
fixture is in
[`ready_valid_storage_status_checker_test.dart`](../../../test/ready_valid_storage_status_checker_test.dart).

## Library Boundaries

ROHD-VF owns reusable testbench behavior. Hardware-specific interface
contracts, exact storage semantics, and clock-domain rules remain documented by
the component library that defines them. For example, an HCL fall-through
buffer's retained-only occupancy semantics are an HCL contract; this checker
only verifies that the exposed status signals agree with that declared contract.
