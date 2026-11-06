// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_safety_checker.dart
// Signal-level FIFO safety verification.
//
// 2026 August 3
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Checks FIFO control and status signals for common safety violations.
///
/// The checker is deliberately signal based and can verify any FIFO-like
/// implementation without importing a component-library-specific FIFO type.
class FifoSafetyChecker extends Component {
  /// Clock used to sample FIFO controls and status.
  final Logic clk;

  /// Active-high reset that suppresses checks while asserted.
  final Logic reset;

  /// Write request sampled at [clk] rising edges.
  final Logic writeEnable;

  /// Read request sampled at [clk] rising edges.
  final Logic readEnable;

  /// High when no entries are retained.
  final Logic empty;

  /// High when no additional entries can be retained.
  final Logic full;

  /// Optional FIFO error indication.
  final Logic? error;

  /// Whether a same-cycle write makes an empty FIFO read legal.
  final bool allowReadWhenEmptyWithWrite;

  /// Whether to require [empty] at test completion.
  final bool enableEndOfTestEmptyCheck;

  /// Whether to report reads from an empty FIFO.
  final bool enableUnderflowCheck;

  /// Whether to report writes to a full FIFO.
  final bool enableOverflowCheck;

  /// Whether to report an asserted [error] signal.
  final bool enableErrorCheck;

  /// Creates a signal-level FIFO safety checker.
  FifoSafetyChecker(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.writeEnable,
      required this.readEnable,
      required this.empty,
      required this.full,
      this.error,
      this.allowReadWhenEmptyWithWrite = false,
      this.enableEndOfTestEmptyCheck = true,
      this.enableUnderflowCheck = true,
      this.enableOverflowCheck = true,
      this.enableErrorCheck = true}) {
    for (final signal in [
      clk,
      reset,
      writeEnable,
      readEnable,
      empty,
      full,
      if (error != null) error!,
    ]) {
      if (signal.width != 1) {
        throw ArgumentError.value(signal, 'signal', 'Must be one bit wide.');
      }
    }

    clk.posedge.listen((_) => _checkCycle());
  }

  bool _hasReset = false;

  void _checkCycle() {
    final resetValue = reset.previousValue;
    if (resetValue == null || !resetValue.isValid) {
      _hasReset = false;
      return;
    }
    if (resetValue.toBool()) {
      _hasReset = true;
      return;
    }
    if (!_hasReset) {
      return;
    }

    final signals = [
      writeEnable,
      readEnable,
      empty,
      full,
      if (error != null) error!,
    ];
    if (signals.any((signal) => signal.previousValue?.isValid != true)) {
      final values = Map.fromEntries(signals.map(
        (signal) => MapEntry(signal.name, signal.previousValue),
      ));
      logger.severe('FIFO control or status signal has an invalid value after '
          'reset. Signal values: $values');
      return;
    }

    final wrote = writeEnable.previousValue!.toBool();
    final read = readEnable.previousValue!.toBool();
    if (full.previousValue!.toBool() && wrote && !read) {
      if (enableOverflowCheck) {
        logger.severe('FIFO received a write that caused an overflow.');
      }
    } else if (empty.previousValue!.toBool() &&
        read &&
        !(allowReadWhenEmptyWithWrite && wrote)) {
      if (enableUnderflowCheck) {
        logger.severe('FIFO received a read that caused an underflow.');
      }
    }

    if (error != null && enableErrorCheck && error!.previousValue!.toBool()) {
      logger.severe('FIFO error signal was asserted.');
    }
  }

  @override
  void check() {
    if (!enableEndOfTestEmptyCheck) {
      return;
    }
    if (!empty.value.isValid) {
      logger.severe('FIFO empty signal has an invalid value at end of test.');
    } else if (!empty.value.toBool()) {
      logger.severe('FIFO is not empty at the end of the test.');
    }
  }
}
