// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_transfer.dart
// Credit transfer events.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_vf/rohd_vf.dart';

/// The direction of a credit-accounting event.
enum CreditTransferKind {
  /// A sender consumed one credit from a pool.
  debit,

  /// A receiver returned one credit to a pool.
  creditReturn,
}

/// One credit event observed at a channel boundary.
class CreditTransferItem extends SequenceItem {
  /// Pool, virtual channel, or resource plane associated with this event.
  final int pool;

  /// Whether the event consumed or returned a credit.
  final CreditTransferKind kind;

  /// Zero-based monitor cycle on which the event occurred.
  final int cycle;

  /// Creates a credit event.
  CreditTransferItem({
    required this.pool,
    required this.kind,
    required this.cycle,
  });

  @override
  String toString() => 'CreditTransferItem('
      'pool: $pool, kind: $kind, cycle: $cycle)';
}
