// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_channel_monitor.dart
// Monitors credit channel activity.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Samples one-hot credit debits and credit returns at [clk] posedges.
class CreditChannelMonitor extends Monitor<CreditTransferItem> {
  /// Clock used to sample the credit signals.
  final Logic clk;

  /// Active-high reset that suppresses credit events.
  final Logic reset;

  /// One-hot-or-zero debit vector, one bit for each credit pool.
  final Logic debit;

  /// Credit-return vector, one bit for each credit pool.
  final Logic creditReturn;

  /// Creates a credit channel monitor.
  CreditChannelMonitor(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.debit,
      required this.creditReturn}) {
    if (debit.width != creditReturn.width) {
      throw ArgumentError('Debit and credit-return widths must match.');
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    var cycle = 0;
    while (!Simulator.simulationHasEnded) {
      await clk.nextPosedge;
      if (Simulator.simulationHasEnded) {
        return;
      }

      final resetValue = reset.previousValue;
      final debitValue = debit.previousValue;
      final creditReturnValue = creditReturn.previousValue;
      final inReset =
          resetValue != null && resetValue.isValid && resetValue.toBool();
      if (!inReset &&
          debitValue != null &&
          creditReturnValue != null &&
          debitValue.isValid &&
          creditReturnValue.isValid) {
        for (var pool = 0; pool < debit.width; pool++) {
          if (debitValue[pool].toBool()) {
            add(CreditTransferItem(
                pool: pool, kind: CreditTransferKind.debit, cycle: cycle));
          }
          if (creditReturnValue[pool].toBool()) {
            add(CreditTransferItem(
                pool: pool,
                kind: CreditTransferKind.creditReturn,
                cycle: cycle));
          }
        }
      }
      cycle++;
    }
  }
}
