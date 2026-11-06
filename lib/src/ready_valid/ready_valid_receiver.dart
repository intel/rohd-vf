// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_receiver.dart
// Ready/valid receiver driver.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Drives the consumer side of a ready/valid channel.
class ReadyValidChannelSink extends Component {
  /// Clock used to update [ready].
  final Logic clk;

  /// Active-high reset.
  final Logic reset;

  /// Consumer handshake control.
  final Logic ready;

  /// Probability from zero through one of applying backpressure.
  final double blockRate;

  /// Optional deterministic policy for driving ready.
  final ReadyValidChannelActivity? activity;

  /// Creates a ready/valid receiver.
  ReadyValidChannelSink(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.ready,
      this.blockRate = 0,
      this.activity}) {
    if (blockRate < 0 || blockRate > 1) {
      throw ArgumentError.value(
          blockRate, 'blockRate', 'Must be between zero and one.');
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final random = Test.random ?? Random();
    ready.inject(0);
    await reset.nextNegedge;
    var cycle = 0;
    while (!Simulator.simulationHasEnded) {
      final active =
          activity?.isActive(cycle) ?? random.nextDouble() >= blockRate;
      ready.inject(active ? 1 : 0);
      await clk.nextPosedge;
      cycle++;
    }
  }
}
