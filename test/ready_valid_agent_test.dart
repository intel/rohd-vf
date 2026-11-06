// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_agent_test.dart
// Tests for ready/valid agents.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class _ReadyValidAgentTest extends Test {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final ready = Logic();
  final valid = Logic();
  final data = Logic(width: 8);
  final expected = [
    0x11,
    0x22,
    0x33,
  ].map((value) => LogicValue.ofInt(value, 8)).toList(growable: false);
  late final FlowScoreboard<LogicValue, Never> scoreboard;
  late final ReadyValidChannelSourceAgent<Logic, LogicValue> transmitter;

  _ReadyValidAgentTest() : super('readyValidAgentTest', printLevel: Level.OFF) {
    final codec = LogicValueReadyValidChannelCodec<Logic>();
    scoreboard = FlowScoreboard<LogicValue, Never>.strict()
      ..expectAll(expected);
    transmitter = ReadyValidChannelSourceAgent<Logic, LogicValue>(
      'transmitter',
      this,
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      codec: codec,
    );
    ReadyValidChannelSinkAgent(
      'receiver',
      this,
      clk: clk,
      reset: reset,
      ready: ready,
    );
    final monitor = ReadyValidChannelMonitor<Logic, LogicValue>(
      'monitor',
      this,
      clk: clk,
      reset: reset,
      ready: ready,
      valid: valid,
      data: data,
      codec: codec,
    );
    monitor.stream.listen((transfer) {
      scoreboard.observe(
        transfer.payload,
        cycle: transfer.cycle!,
        endpoint: 'monitor',
      );
    });
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final objection = phase.raiseObjection('stimulus');

    reset.inject(1);
    await clk.waitCycles(2);
    reset.inject(0);
    await clk.waitCycles(1);
    for (final value in expected) {
      transmitter.sequencer.add(ReadyValidChannelItem(value));
    }
    objection.drop();
  }

  @override
  void check() {
    expect(scoreboard.failures, isEmpty);
    expect(scoreboard.verifyComplete(), isEmpty);
  }
}

void main() {
  tearDown(() async {
    await Test.reset();
  });

  test('ready/valid VF agents deliver sequenced transfers', () async {
    await _ReadyValidAgentTest().start();
  });
}
