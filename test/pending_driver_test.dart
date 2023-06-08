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
  MyPendingDriver(this.clk,
      {required Component parent, required super.sequencer})
      : super('myPendingDriver', parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    clk.negedge.listen((event) {
      pendingSeqItems.removeFirst();
    });
  }
}

class MyTest extends Test {
  late final Sequencer<MySeqItem> seqr;
  MyTest([super.name = 'myTest']) {
    final clk = SimpleClockGenerator(10).clk;

    seqr = Sequencer<MySeqItem>('seqr', this);
    MyPendingDriver(clk, parent: this, sequencer: seqr);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    for (var i = 0; i < 100; i++) {
      seqr.add(MySeqItem());
    }
  }
}

void main() {
  test('pending driver', () async {
    Logger.root.level = Level.ALL;
    await MyTest().start();

    expect(Simulator.time, 1005);
  });
}
