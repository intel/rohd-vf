// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waiter.dart
// Utilities for waiting for things.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';

/// A type of edge on a signal.
enum Edge {
  /// A positive edge.
  pos,

  /// A negative edge.
  neg,

  /// Either a positive or negative edge.
  both
}

/// Returns a [Future] which completes after the specified [numCycles],
/// where each cycle is defined as the next occurence of the specified [edge].
Future<void> waitCycles(Logic clk, int numCycles,
    {Edge edge = Edge.pos}) async {
  for (var i = 0; i < numCycles; i++) {
    switch (edge) {
      case Edge.pos:
        await clk.nextPosedge;
        break;
      case Edge.neg:
        await clk.nextNegedge;
        break;
      case Edge.both:
        await clk.nextChanged;
        break;
    }
  }
}
