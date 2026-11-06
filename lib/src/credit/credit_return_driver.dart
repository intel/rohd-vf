// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_return_driver.dart
// Driver for credit return events.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Drives one-cycle one-hot returned-credit pulses from a sequencer.
class CreditReturnDriver extends PendingClockedDriver<CreditTransferItem> {
  /// Active-high reset.
  final Logic reset;

  /// One bit per credit pool.
  final Logic creditReturn;

  /// Creates a sequencer-backed credit-return driver.
  CreditReturnDriver(super.name, super.parent,
      {required super.clk,
      required this.reset,
      required this.creditReturn,
      required super.sequencer,
      super.dropDelayCycles = 30});

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    creditReturn.inject(0);
    await reset.nextNegedge;
    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isEmpty) {
        await clk.nextPosedge;
        continue;
      }

      final item = pendingSeqItems.removeFirst();
      if (item.kind != CreditTransferKind.creditReturn) {
        throw ArgumentError.value(
            item, 'item', 'Credit return driver accepts only return items.');
      }
      if (item.pool < 0 || item.pool >= creditReturn.width) {
        throw ArgumentError.value(item.pool, 'item.pool',
            'Must identify a bit in the credit-return vector.');
      }
      creditReturn.inject(1 << item.pool);
      await clk.nextPosedge;
      creditReturn.inject(0);
    }
  }
}
