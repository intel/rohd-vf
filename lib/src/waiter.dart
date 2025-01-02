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
  any
}

/// An `extension` on [Logic] for waiting for things.
extension LogicWaiter on Logic {
  /// Returns a [Future] which completes after the specified [numCycles],
  /// where each cycle is defined as the next occurence of the specified [edge].
  ///
  /// [width] must be 1 or an [Exception] will be thrown.
  ///
  /// Like [nextNegedge] and [nextPosedge], this will only detect valid edge
  /// transitions. If the value is invalid (`x` or `z`) before or after the
  /// transition, it will not count as a cycle.
  Future<void> waitCycles(int numCycles, {Edge edge = Edge.pos}) async {
    if (width != 1) {
      throw Exception('Must be a 1-bit signal, but was $width bits.');
    }

    for (var i = 0; i < numCycles; i++) {
      switch (edge) {
        case Edge.pos:
          await nextPosedge;
        case Edge.neg:
          await nextNegedge;
        case Edge.any:
          await Future.any([
            nextPosedge,
            nextNegedge,
          ]);
      }
    }
  }
}
