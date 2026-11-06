// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_channel_checker_test.dart
// Tests for ready/valid channel verification.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class _ChannelCycle {
  final int reset;
  final LogicValue ready;
  final LogicValue valid;
  final LogicValue data;

  const _ChannelCycle(this.reset, this.ready, this.valid, this.data);
}

class _CheckerFailureTest extends Test {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final ready = Logic();
  final valid = Logic();
  final data = Logic(width: 8);

  _CheckerFailureTest() : super('checkerFailureTest', printLevel: Level.OFF) {
    ReadyValidChannelChecker<Logic, LogicValue>('checker', this,
        clk: clk,
        reset: reset,
        ready: ready,
        valid: valid,
        data: data,
        codec: LogicValueReadyValidChannelCodec());
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final objection = phase.raiseObjection('unknownControlStimulus');
    reset.inject(0);
    ready.inject(LogicValue.x);
    valid.inject(LogicValue.one);
    data.inject(LogicValue.zero);
    await clk.nextPosedge;
    objection.drop();
  }
}

Future<List<ReadyValidChannelViolation>> _runChecker(
    List<_ChannelCycle> cycles,
    ReadyValidChannelCheckConfiguration<Logic, LogicValue>
        configuration) async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final ready = Logic();
  final valid = Logic();
  final data = Logic(width: 8);
  final checker = ReadyValidChannelChecker<Logic, LogicValue>('checker', null,
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      codec: LogicValueReadyValidChannelCodec(),
      configuration: configuration,
      reportViolations: false);

  unawaited(checker.run(Phase()));
  unawaited(Simulator.run());
  for (final cycle in cycles) {
    reset.inject(cycle.reset);
    ready.inject(cycle.ready);
    valid.inject(cycle.valid);
    data.inject(cycle.data);
    await clk.nextPosedge;
  }
  await Simulator.endSimulation();
  return checker.violations;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('checker reports reset transfers and unknown controls', () async {
    final violations = await _runChecker([
      const _ChannelCycle(1, LogicValue.one, LogicValue.one, LogicValue.zero),
      const _ChannelCycle(0, LogicValue.x, LogicValue.one, LogicValue.zero)
    ], ReadyValidChannelCheckConfiguration<Logic, LogicValue>());

    expect(violations.map((violation) => violation.id),
        ['rv.no_transfer_during_reset', 'rv.controls_known']);
  });

  test('checker enforces an irrevocable stalled offer and stall bound',
      () async {
    final violations = await _runChecker(
        [
          _ChannelCycle(
              0, LogicValue.zero, LogicValue.one, LogicValue.ofInt(1, 8)),
          _ChannelCycle(
              0, LogicValue.zero, LogicValue.one, LogicValue.ofInt(2, 8)),
          _ChannelCycle(
              0, LogicValue.zero, LogicValue.zero, LogicValue.ofInt(2, 8))
        ],
        ReadyValidChannelCheckConfiguration<Logic, LogicValue>(
            validMustRemainAssertedWhileStalled: true,
            payloadMustRemainStableWhileStalled: true,
            maximumStallCycles: 1));

    expect(violations.map((violation) => violation.id), [
      'rv.payload_stable_while_stalled',
      'rv.max_stall_cycles',
      'rv.valid_held_while_stalled'
    ]);
  });

  test('reported violations fail the ROHD-VF Test lifecycle', () async {
    await expectLater(_CheckerFailureTest().start(), throwsA(isA<Exception>()));
  });
}
