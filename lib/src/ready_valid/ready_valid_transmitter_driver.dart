// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_transmitter_driver.dart
// Driver for ready/valid transmitters.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Drives sequenced values onto the provider side of a ready/valid channel.
class ReadyValidChannelSourceDriver<LogicType extends Logic, ValueType>
    extends PendingClockedDriver<ReadyValidChannelItem<ValueType>> {
  /// Active-high reset.
  final Logic reset;

  /// Consumer handshake control.
  final Logic ready;

  /// Provider handshake control.
  final Logic valid;

  /// Provider payload.
  final LogicType data;

  /// Codec used to drive [data].
  final ReadyValidChannelCodec<LogicType, ValueType> codec;

  /// Probability from zero through one of withholding a new offer.
  final double blockRate;

  /// Optional deterministic policy for beginning new offers.
  final ReadyValidChannelActivity? activity;

  /// Creates a sequencer-backed ready/valid source driver.
  ReadyValidChannelSourceDriver(super.name, super.parent,
      {required super.clk,
      required this.reset,
      required this.ready,
      required this.valid,
      required this.data,
      required this.codec,
      required super.sequencer,
      this.blockRate = 0,
      this.activity,
      super.dropDelayCycles = 30}) {
    if (blockRate < 0 || blockRate > 1) {
      throw ArgumentError.value(
          blockRate, 'blockRate', 'Must be between zero and one.');
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final random = Test.random ?? Random();
    valid.inject(0);
    await reset.nextNegedge;

    var cycle = 0;
    while (!Simulator.simulationHasEnded) {
      final mayOffer =
          activity?.isActive(cycle) ?? random.nextDouble() >= blockRate;
      if (pendingSeqItems.isEmpty || !mayOffer) {
        valid.inject(0);
        await clk.nextPosedge;
        cycle++;
        continue;
      }

      final transfer = pendingSeqItems.first;
      valid.inject(1);
      codec.drive(data, transfer.payload);
      do {
        await clk.nextPosedge;
        cycle++;
      } while (!Simulator.simulationHasEnded && !_wasAccepted());
      if (!Simulator.simulationHasEnded) {
        pendingSeqItems.removeFirst();
      }
    }
  }

  bool _wasAccepted() {
    final readyValue = ready.previousValue;
    return readyValue != null && readyValue.isValid && readyValue.toBool();
  }
}
