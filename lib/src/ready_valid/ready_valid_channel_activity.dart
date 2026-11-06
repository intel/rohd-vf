// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_channel_activity.dart
// Ready/valid channel activity policies.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

/// Selects cycles on which a ready/valid participant may become active.
class ReadyValidChannelActivity {
  final bool Function(int cycle) _isActive;

  /// Concise description suitable for test diagnostics.
  final String description;

  const ReadyValidChannelActivity._(this._isActive, this.description);

  /// Creates an activity policy that is active on every cycle.
  factory ReadyValidChannelActivity.always() =>
      ReadyValidChannelActivity._((cycle) => true, 'always');

  /// Creates a finite activity script that is inactive after [values].
  factory ReadyValidChannelActivity.scripted(Iterable<bool> values) {
    final script = UnmodifiableListView(List<bool>.of(values));
    return ReadyValidChannelActivity._(
        (cycle) => cycle < script.length && script[cycle],
        'scripted(${script.length})');
  }

  /// Creates a repeating active/inactive policy.
  factory ReadyValidChannelActivity.alternating(
      {int activeCycles = 1, int inactiveCycles = 1}) {
    if (activeCycles < 1) {
      throw ArgumentError.value(
          activeCycles, 'activeCycles', 'Must be at least one.');
    }
    if (inactiveCycles < 1) {
      throw ArgumentError.value(
          inactiveCycles, 'inactiveCycles', 'Must be at least one.');
    }

    final period = activeCycles + inactiveCycles;
    return ReadyValidChannelActivity._((cycle) => cycle % period < activeCycles,
        'alternating($activeCycles,$inactiveCycles)');
  }

  /// Creates a periodic burst beginning at [startCycle].
  factory ReadyValidChannelActivity.burst(
      {required int length, required int period, int startCycle = 0}) {
    if (startCycle < 0) {
      throw ArgumentError.value(
          startCycle, 'startCycle', 'Must not be negative.');
    }
    if (length < 1) {
      throw ArgumentError.value(length, 'length', 'Must be at least one.');
    }
    if (period < length) {
      throw ArgumentError.value(
          period, 'period', 'Must be at least the burst length.');
    }

    return ReadyValidChannelActivity._(
        (cycle) =>
            cycle >= startCycle && (cycle - startCycle) % period < length,
        'burst($startCycle,$length,$period)');
  }

  /// Creates a deterministic pseudo-random activity policy.
  factory ReadyValidChannelActivity.seededRandom(
      {required int seed, required double activeProbability}) {
    if (activeProbability < 0 || activeProbability > 1) {
      throw ArgumentError.value(activeProbability, 'activeProbability',
          'Must be between zero and one.');
    }

    return ReadyValidChannelActivity._(
        (cycle) => _randomUnit(seed, cycle) < activeProbability,
        'seededRandom($seed,$activeProbability)');
  }

  /// Returns whether the participant may activate on [cycle].
  bool isActive(int cycle) {
    if (cycle < 0) {
      throw ArgumentError.value(cycle, 'cycle', 'Must not be negative.');
    }
    return _isActive(cycle);
  }

  static double _randomUnit(int seed, int cycle) {
    var value = (seed ^ ((cycle + 1) * 0x9e3779b9)) & 0xffffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff;
    value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff;
    value = (value ^ (value >> 16)) & 0xffffffff;
    return value / 0x100000000;
  }
}
