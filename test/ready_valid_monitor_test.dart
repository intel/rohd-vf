// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_monitor_test.dart
// Tests for the ready/valid monitor.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('ReadyValidChannelMonitor samples accepted pre-edge payloads', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final ready = Logic();
    final valid = Logic();
    final data = Logic(width: 8);
    final monitor = ReadyValidChannelMonitor<Logic, LogicValue>('monitor', null,
        clk: clk,
        reset: reset,
        ready: ready,
        valid: valid,
        data: data,
        codec: LogicValueReadyValidChannelCodec());
    final transfers = <ReadyValidChannelItem<LogicValue>>[];
    final subscription = monitor.stream.listen(transfers.add);

    unawaited(monitor.run(Phase()));
    unawaited(Simulator.run());

    reset.inject(1);
    ready.inject(1);
    valid.inject(1);
    data.inject(0x00);
    await clk.nextPosedge;

    reset.inject(0);
    data.inject(0x5a);
    await clk.nextPosedge;

    valid.inject(0);
    await clk.nextPosedge;
    await Simulator.endSimulation();
    await subscription.cancel();

    expect(transfers, hasLength(1));
    expect(transfers.single.cycle, 1);
    expect(transfers.single.payload, LogicValue.ofInt(0x5a, 8));
  });
}
