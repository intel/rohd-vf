// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pending_driver_test.dart
// Tests for `PendingDriver`
//
// 2023 June 8
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class MySeqItem extends SequenceItem {}

class MyPendingDriver extends PendingDriver<MySeqItem> {
  final Logic clk;
  MyPendingDriver(
    this.clk, {
    required Component parent,
    required super.sequencer,
    super.timeout,
    super.dropDelay,
  }) : super('myPendingDriver', parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    clk.negedge.listen((event) {
      if (pendingSeqItems.isNotEmpty) {
        pendingSeqItems.removeFirst();
      }
    });
  }
}

class MyTest extends Test {
  late final Sequencer<MySeqItem> seqr;

  final Logic clk;

  final int interAddDelay;

  final int numItems;

  MyTest({
    required this.clk,
    Future<void> Function()? timeout,
    Future<void> Function()? dropDelay,
    this.interAddDelay = 0,
    this.numItems = 100,
  }) : super('myTest') {
    seqr = Sequencer<MySeqItem>('seqr', this);
    MyPendingDriver(clk,
        parent: this, sequencer: seqr, timeout: timeout, dropDelay: dropDelay);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    for (var i = 0; i < numItems; i++) {
      seqr.add(MySeqItem());
      await waitCycles(clk, interAddDelay);
    }
  }
}

Future<void> waitCycles(Logic clk, [int numCycles = 1]) async {
  for (var i = 0; i < numCycles; i++) {
    await clk.nextPosedge;
  }
}

void main() {
  Logic? clk;
  setUp(() {
    clk = SimpleClockGenerator(10).clk;
  });

  tearDown(() async {
    await Simulator.reset();
  });

  test('pending driver simple', () async {
    await MyTest(clk: clk!).start();

    expect(Simulator.time, 1005);
  });

  test('pending driver with delay', () async {
    await MyTest(clk: clk!, dropDelay: () async => waitCycles(clk!, 10))
        .start();

    expect(Simulator.time, 1100);
  });

  test('pending driver with delay and sometimes empty queue', () async {
    await MyTest(
      clk: clk!,
      dropDelay: () async => waitCycles(clk!, 10),
      interAddDelay: 8,
      numItems: 5,
    ).start();

    expect(Simulator.time, 420);
  });
}
