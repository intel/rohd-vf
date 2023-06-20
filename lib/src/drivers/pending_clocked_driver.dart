// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pending_cyles_driver.dart
// A driver that keeps a queue of pending packets and can count cycles.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A type of [PendingDriver] that requires a [clk] and will wait for cycles
/// on that clock for timeouts and drop delays.
abstract class PendingClockedDriver<SequenceItemType extends SequenceItem>
    extends PendingDriver<SequenceItemType> {
  /// Number of cycles before triggering a timeout error.
  final int? timeoutCycles;

  /// Number of cycles to hold an objection even when no packets are pending.
  final int? dropDelayCycles;

  /// The clock for this driver.
  final Logic clk;

  /// The [Edge] to wait on when counting cycles for [timeoutCycles] and
  /// [dropDelayCycles].
  final Edge waitEdge;

  /// Creates a new [PendingClockedDriver] attached to [sequencer] with the
  /// specified [timeoutCycles] and [dropDelayCycles].
  PendingClockedDriver(
    super.name,
    super.parent, {
    required super.sequencer,
    required this.clk,
    this.timeoutCycles,
    this.dropDelayCycles,
    this.waitEdge = Edge.pos,
  }) : super(
          timeout: timeoutCycles != null
              ? () async {
                  await clk.waitCycles(timeoutCycles, edge: waitEdge);
                }
              : null,
          dropDelay: dropDelayCycles != null
              ? () async {
                  await clk.waitCycles(dropDelayCycles, edge: waitEdge);
                }
              : null,
        );
}
