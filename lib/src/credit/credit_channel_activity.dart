// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_channel_activity.dart
// Deterministic multi-pool credit traffic generation for verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

/// One cycle of pool-attributed credit traffic.
class CreditChannelActivityEvent {
  /// Pool that consumes a credit on this cycle, if any.
  final int? debitPool;

  /// Pool that receives a returned credit on this cycle, if any.
  final int? returnPool;

  /// Creates a pool-attributed credit activity event.
  const CreditChannelActivityEvent({this.debitPool, this.returnPool});

  /// An inactive credit activity event.
  static const idle = CreditChannelActivityEvent();

  /// One-hot debit vector for [poolCount] pools.
  int debitVector(int poolCount) => _vectorFor(debitPool, poolCount);

  /// One-hot credit-return vector for [poolCount] pools.
  int returnVector(int poolCount) => _vectorFor(returnPool, poolCount);

  int _vectorFor(int? pool, int poolCount) {
    if (poolCount < 1) {
      throw ArgumentError.value(poolCount, 'poolCount', 'Must be positive.');
    }
    if (pool == null) {
      return 0;
    }
    if (pool < 0 || pool >= poolCount) {
      throw ArgumentError.value(
          pool, 'pool', 'Must identify a configured pool.');
    }
    return 1 << pool;
  }
}

/// Selects reproducible debit and credit-return events across named pools.
class CreditChannelActivity {
  final CreditChannelActivityEvent Function(int cycle) _eventAt;

  /// Concise description suitable for test diagnostics.
  final String description;

  const CreditChannelActivity._(this._eventAt, this.description);

  /// Creates a finite event script that is idle after [events].
  factory CreditChannelActivity.scripted(
      Iterable<CreditChannelActivityEvent> events) {
    final script = UnmodifiableListView(List.of(events));
    return CreditChannelActivity._(
        (cycle) => cycle < script.length
            ? script[cycle]
            : CreditChannelActivityEvent.idle,
        'scripted(${script.length})');
  }

  /// Creates deterministic pseudo-random pool-attributed activity.
  ///
  /// [activeProbability] determines whether a debit and return are emitted on
  /// an individual cycle. A selected debit and return may target distinct
  /// pools, allowing the generated stream to stress aggregate accounting.
  factory CreditChannelActivity.seededRandom(
      {required int seed,
      required int poolCount,
      required double activeProbability}) {
    if (poolCount < 1) {
      throw ArgumentError.value(poolCount, 'poolCount', 'Must be positive.');
    }
    if (activeProbability < 0 || activeProbability > 1) {
      throw ArgumentError.value(activeProbability, 'activeProbability',
          'Must be between zero and one.');
    }
    return CreditChannelActivity._((cycle) {
      final debitPool = _randomUnit(seed, cycle * 3) < activeProbability
          ? _randomPool(seed, cycle * 3 + 1, poolCount)
          : null;
      final returnPool = _randomUnit(seed, cycle * 3 + 2) < activeProbability
          ? _randomPool(seed, cycle * 3 + 3, poolCount)
          : null;
      return CreditChannelActivityEvent(
          debitPool: debitPool, returnPool: returnPool);
    }, 'seededRandom($seed,$poolCount,$activeProbability)');
  }

  /// Returns the selected event for [cycle].
  CreditChannelActivityEvent eventAt(int cycle) {
    if (cycle < 0) {
      throw ArgumentError.value(cycle, 'cycle', 'Must not be negative.');
    }
    return _eventAt(cycle);
  }

  static int _randomPool(int seed, int cycle, int poolCount) =>
      (_randomUnit(seed, cycle) * poolCount).floor();

  static double _randomUnit(int seed, int cycle) {
    var value = (seed ^ ((cycle + 1) * 0x9e3779b9)) & 0xffffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff;
    value = (value ^ (value >> 16)) & 0xffffffff;
    return value / 0x100000000;
  }
}
