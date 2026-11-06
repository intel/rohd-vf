// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_transfer.dart
// Ready/valid transfer sequence items.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_vf/rohd_vf.dart';

/// A payload accepted across a ready/valid channel.
class ReadyValidChannelItem<PayloadType> extends SequenceItem {
  /// Payload sampled at the accepted edge.
  final PayloadType payload;

  /// Zero-based monitor cycle at which the transfer occurred, when observed.
  final int? cycle;

  /// Creates an accepted ready/valid [payload].
  ReadyValidChannelItem(this.payload, {this.cycle});

  @override
  String toString() =>
      'ReadyValidChannelItem(cycle: $cycle, payload: $payload)';
}
