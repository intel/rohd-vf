// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_storage_status_checker.dart
// Ready/valid retained-storage status verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// One violation observed by [ReadyValidStorageStatusChecker].
class ReadyValidStorageStatusViolation {
  /// Stable rule identifier.
  final String id;

  /// Zero-based checker cycle at which the violation was sampled.
  final int cycle;

  /// Checked storage boundary.
  final String endpoint;

  /// Human-readable description.
  final String message;

  /// Immutable values relevant to the violation.
  final Map<String, Object?> sampledValues;

  /// Creates a storage-status violation.
  ReadyValidStorageStatusViolation(
      {required this.id,
      required this.cycle,
      required this.endpoint,
      required this.message,
      Map<String, Object?> sampledValues = const {}})
      : sampledValues = UnmodifiableMapView(Map.of(sampledValues));

  @override
  String toString() => '$id at $endpoint cycle $cycle: $message $sampledValues';
}

/// Checks retained-storage status signals at rising clock edges.
///
/// The checker is deliberately signal based: it does not import a particular
/// component package or infer an occupancy-update policy from handshakes.
class ReadyValidStorageStatusChecker extends Component {
  /// Clock used to sample the status signals.
  final Logic clk;

  /// Active-high reset that suppresses status checks.
  final Logic reset;

  /// Number of items the checked storage can retain.
  final int capacity;

  /// Number of items retained by the checked storage.
  final Logic occupancy;

  /// High when [occupancy] is zero.
  final Logic empty;

  /// High when [occupancy] equals [capacity].
  final Logic full;

  /// Whether observed violations are logged as `SEVERE`.
  final bool reportViolations;

  /// Storage boundary name recorded in violations.
  final String endpoint;

  final StreamController<ReadyValidStorageStatusViolation>
      _violationsController =
      StreamController<ReadyValidStorageStatusViolation>.broadcast(sync: true);
  final List<ReadyValidStorageStatusViolation> _violations = [];

  /// Violations observed by this checker in sampling order.
  List<ReadyValidStorageStatusViolation> get violations =>
      UnmodifiableListView(_violations);

  /// Broadcast stream of newly observed violations.
  Stream<ReadyValidStorageStatusViolation> get violationStream =>
      _violationsController.stream;

  /// Creates a retained-storage status checker.
  ReadyValidStorageStatusChecker(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.capacity,
      required this.occupancy,
      required this.empty,
      required this.full,
      this.endpoint = 'readyValidStorage',
      this.reportViolations = true}) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be at least one.');
    }
    if (reset.width != 1 || empty.width != 1 || full.width != 1) {
      throw ArgumentError('Reset, empty, and full signals must be one bit.');
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    var cycle = 0;
    while (!Simulator.simulationHasEnded) {
      await clk.nextPosedge;
      if (Simulator.simulationHasEnded) {
        return;
      }

      final resetValue = reset.previousValue;
      final occupancyValue = occupancy.previousValue;
      final emptyValue = empty.previousValue;
      final fullValue = full.previousValue;
      if (resetValue == null ||
          occupancyValue == null ||
          emptyValue == null ||
          fullValue == null) {
        cycle++;
        continue;
      }

      final inReset = resetValue.isValid && resetValue.toBool();
      final statusesKnown =
          occupancyValue.isValid && emptyValue.isValid && fullValue.isValid;
      if (!inReset && !statusesKnown) {
        _report('storage.status_known', cycle,
            'Occupancy, empty, and full must be known after reset.', {
          'occupancy': occupancyValue,
          'empty': emptyValue,
          'full': fullValue,
        });
      }
      if (!inReset && statusesKnown) {
        final retainedItems = occupancyValue.toInt();
        if (retainedItems > capacity) {
          _report('storage.occupancy_in_range', cycle,
              'Occupancy exceeded the declared capacity.', {
            'occupancy': retainedItems,
            'capacity': capacity,
          });
        }
        if (emptyValue.toBool() != (retainedItems == 0)) {
          _report('storage.empty_matches_occupancy', cycle,
              'Empty did not match zero retained occupancy.', {
            'occupancy': retainedItems,
            'empty': emptyValue,
          });
        }
        if (fullValue.toBool() != (retainedItems == capacity)) {
          _report('storage.full_matches_occupancy', cycle,
              'Full did not match capacity retained occupancy.', {
            'occupancy': retainedItems,
            'capacity': capacity,
            'full': fullValue,
          });
        }
      }
      cycle++;
    }
  }

  void _report(String id, int cycle, String message,
      Map<String, Object?> sampledValues) {
    final violation = ReadyValidStorageStatusViolation(
        id: id,
        cycle: cycle,
        endpoint: endpoint,
        message: message,
        sampledValues: sampledValues);
    _violations.add(violation);
    _violationsController.add(violation);
    if (reportViolations) {
      logger.severe(violation);
    }
  }
}
