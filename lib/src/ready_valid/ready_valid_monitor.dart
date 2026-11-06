// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_monitor.dart
// Monitors ready/valid transfers.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Samples accepted transfers from a ready/valid channel at [clk] posedges.
class ReadyValidChannelMonitor<LogicType extends Logic, ValueType>
    extends Monitor<ReadyValidChannelItem<ValueType>> {
  /// Clock used to sample channel controls and payload.
  final Logic clk;

  /// Active-high reset that suppresses transfer events.
  final Logic reset;

  /// Consumer handshake control.
  final Logic ready;

  /// Provider handshake control.
  final Logic valid;

  /// Payload sampled with the accepted controls.
  final LogicType data;

  /// Conversion between [data] and semantic transaction values.
  final ReadyValidChannelCodec<LogicType, ValueType> codec;

  /// Creates a ready/valid monitor.
  ReadyValidChannelMonitor(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.ready,
      required this.valid,
      required this.data,
      required this.codec});

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
      final readyValue = ready.previousValue;
      final validValue = valid.previousValue;
      final inReset =
          resetValue != null && resetValue.isValid && resetValue.toBool();
      final accepted = !inReset &&
          readyValue != null &&
          validValue != null &&
          readyValue.isValid &&
          validValue.isValid &&
          readyValue.toBool() &&
          validValue.toBool();
      if (accepted) {
        add(ReadyValidChannelItem(codec.sample(data, previous: true),
            cycle: cycle));
      }
      cycle++;
    }
  }
}
