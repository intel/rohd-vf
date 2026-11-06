// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_return_driver_test.dart
// Tests for the credit return driver.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class _CreditReturnDriverTest extends Test {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final creditReturn = Logic(width: 2);
  late final Sequencer<CreditTransferItem> sequencer;

  _CreditReturnDriverTest()
      : super('creditReturnDriverTest', printLevel: Level.OFF) {
    sequencer = Sequencer<CreditTransferItem>('sequencer', this);
    CreditReturnDriver(
      'driver',
      this,
      clk: clk,
      reset: reset,
      creditReturn: creditReturn,
      sequencer: sequencer,
    );
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final objection = phase.raiseObjection('stimulus');

    reset.inject(1);
    await clk.waitCycles(2);
    reset.inject(0);
    sequencer.add(
      CreditTransferItem(
        pool: 1,
        kind: CreditTransferKind.creditReturn,
        cycle: 0,
      ),
    );
    await clk.nextPosedge;
    expect(creditReturn.previousValue, LogicValue.ofInt(2, 2));
    await clk.nextPosedge;
    expect(creditReturn.previousValue, LogicValue.ofInt(0, 2));
    objection.drop();
  }
}

void main() {
  tearDown(() async {
    await Test.reset();
  });

  test('credit return driver emits a one-hot return pulse', () async {
    await _CreditReturnDriverTest().start();
  });
}
