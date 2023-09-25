// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// phase.dart
// Definition for Objection and Phase for ROHD-VF
//
// 2021 May 11
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:collection';

/// Represents an objection to the test completing.
///
/// An [Objection] is raised by a [Phase] and will attempt
/// to prevent the phase and test from ending until it is dropped
/// with [Objection.drop].
class Objection {
  /// The name of this [Objection].
  ///
  /// Useful for logging and debug purposes.
  final String name;

  /// The phase thas is objecting completion of.
  final Phase phase;

  /// Keeps track of whether this [isRaised] and
  /// alerts listeners of [dropped].
  final Completer<void> _completer = Completer<void>();

  /// Returns `true` iff this [Objection] is still
  /// raised and trying to prevent the phase from ending.
  bool get isRaised => !_completer.isCompleted;

  /// A [Future] which completes when the [Objection] is dropped.
  Future<void> get dropped => _completer.future;

  Objection._(this.name, this.phase);

  /// Drops this [Objection] on [phase], allowing it to progress
  /// if nothing else is holding it from completing.
  void drop() {
    if (!isRaised) {
      throw Exception('Objection already dropped');
    }
    phase._dropObjection(this);
    _completer.complete();
  }
}

/// A object responsible for controlling a period of time during the test
/// which can be prevented from ending.
///
/// Raising [Objection]s on a [Phase] keeps this portion of the test from
/// completing.
class Phase {
  /// All active [Objection]s to this phase completing.
  final Queue<Objection> _objections = Queue<Objection>();

  /// An unmodifiable [Iterable] of all active [Objection]s which are
  /// preventing this phase from completing.
  Iterable<Objection> get objections => UnmodifiableListView(_objections);

  /// Creates and returns a new objection named [name] applied to this [Phase].
  Objection raiseObjection([String name = '']) {
    final newObjection = Objection._(name, this);
    _objections.add(newObjection);
    return newObjection;
  }

  /// Drops [objection] from applying to this [Phase].
  void _dropObjection(Objection objection) {
    if (objection.phase != this) {
      throw Exception('Objection was not registered with this phase.');
    }
    _objections.remove(objection);
  }

  /// A [Future] which will complete once there are no more
  /// raised objections on this [Phase].
  Future<void> allObjectionsDropped() async {
    while (_objections.isNotEmpty) {
      final nextObjection = _objections.first;
      await nextObjection.dropped;
      _objections.remove(nextObjection);
    }
  }
}
