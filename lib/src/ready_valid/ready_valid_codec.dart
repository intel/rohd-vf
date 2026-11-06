// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_codec.dart
// Ready/valid payload encoding and decoding.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';

/// Converts between a ready/valid payload signal and a semantic value.
class ReadyValidChannelCodec<LogicType extends Logic, ValueType> {
  /// Drives a value onto a signal.
  // Callers must provide values compatible with the configured callback.
  // ignore: unsafe_variance
  final void Function(LogicType signal, ValueType value) drive;

  /// Samples a value from a signal.
  // ignore: unsafe_variance
  final ValueType Function(LogicType signal, {required bool previous}) sample;

  /// Creates a payload codec.
  const ReadyValidChannelCodec({required this.drive, required this.sample});
}

/// A packed [LogicValue] codec for any [Logic] payload.
class LogicValueReadyValidChannelCodec<LogicType extends Logic>
    extends ReadyValidChannelCodec<LogicType, LogicValue> {
  /// Creates a packed logic-value codec.
  LogicValueReadyValidChannelCodec()
      : super(
            drive: (signal, value) => signal.inject(value),
            sample: (signal, {required previous}) {
              if (!previous) {
                return signal.value;
              }

              final value = signal.previousValue;
              if (value == null) {
                throw StateError(
                    'Signal ${signal.name} has no previous value.');
              }
              return value;
            });
}
