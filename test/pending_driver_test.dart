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

class MyPendingDriver extends PendingClockedDriver<MySeqItem> {
  MyPendingDriver({
    required Component parent,
    required super.sequencer,
    required super.clk,
    super.timeoutCycles,
    super.dropDelayCycles,
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
    int? timeout,
    int? dropDelay,
    this.interAddDelay = 0,
    this.numItems = 100,
  }) : super('myTest') {
    seqr = Sequencer<MySeqItem>('seqr', this);
    MyPendingDriver(
        clk: clk,
        parent: this,
        sequencer: seqr,
        timeoutCycles: timeout,
        dropDelayCycles: dropDelay);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    for (var i = 0; i < numItems; i++) {
      seqr.add(MySeqItem());
      await clk.waitCycles(interAddDelay);
    }
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
    await MyTest(clk: clk!, dropDelay: 10).start();

    expect(Simulator.time, 1100);
  });

  test('pending driver with delay and sometimes empty queue', () async {
    await MyTest(
      clk: clk!,
      dropDelay: 10,
      interAddDelay: 8,
      numItems: 5,
    ).start();

    expect(Simulator.time, 420);
  });

  test('pending driver never timeout', () async {
    await MyTest(
      clk: clk!,
      dropDelay: 9,
      timeout: 10,
      interAddDelay: 8,
      numItems: 5,
    ).start();
  });

  test('pending driver times out', () async {
    final myTest = MyTest(
      clk: clk!,
      dropDelay: 30,
      timeout: 10,
      interAddDelay: 20,
      numItems: 5,
    )..printLevel = Level.OFF;

    try {
      await myTest.start();
      fail('Did not see severe');
    } on Exception catch (_) {
      expect(myTest.failureDetected, true);
    }
  });
}
