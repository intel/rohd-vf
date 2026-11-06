// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_conservation_checker.dart
// End-to-end credit conservation verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Checks end-to-end credit conservation in a common unit.
///
/// For every configured pool this checker enforces:
///
/// `available + forwardInFlight + receiverOccupied + returnsInFlight`
/// `== provisioned`.
///
/// Use one-element lists for a shared aggregate capacity.
class CreditConservationChecker extends Component {
  /// Clock used to sample each term.
  final Logic clk;

  /// Active-high reset that suppresses checks.
  final Logic reset;

  /// Sender-side available balances.
  final List<Logic> available;

  /// Debited items or units traveling toward the receiver.
  final List<Logic> forwardInFlight;

  /// Receiver-side occupied resources.
  final List<Logic> receiverOccupied;

  /// Freed resources traveling back toward the sender.
  final List<Logic> returnsInFlight;

  /// Provisioned capacity in the same units as every sampled term.
  final List<int> provisioned;

  /// Whether observed violations are logged as `SEVERE`.
  final bool reportViolations;

  /// Boundary name recorded in violations.
  final String endpoint;

  final List<CreditChannelViolation> _violations = [];

  /// Violations observed in sampling order.
  List<CreditChannelViolation> get violations =>
      UnmodifiableListView(_violations);

  /// Creates an end-to-end conservation checker.
  CreditConservationChecker(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required List<Logic> available,
      required List<Logic> forwardInFlight,
      required List<Logic> receiverOccupied,
      required List<Logic> returnsInFlight,
      required List<int> provisioned,
      this.endpoint = 'creditPath',
      this.reportViolations = true})
      : available = List.unmodifiable(available),
        forwardInFlight = List.unmodifiable(forwardInFlight),
        receiverOccupied = List.unmodifiable(receiverOccupied),
        returnsInFlight = List.unmodifiable(returnsInFlight),
        provisioned = List.unmodifiable(provisioned) {
    final lengths = {
      this.available.length,
      this.forwardInFlight.length,
      this.receiverOccupied.length,
      this.returnsInFlight.length,
      this.provisioned.length,
    };
    if (lengths.length != 1 || this.provisioned.isEmpty) {
      throw ArgumentError(
          'Every conservation term must contain one signal per pool.');
    }
    if (this.provisioned.any((capacity) => capacity < 0)) {
      throw ArgumentError('Provisioned capacities must not be negative.');
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
      if (resetValue == null || (resetValue.isValid && resetValue.toBool())) {
        cycle++;
        continue;
      }

      for (var pool = 0; pool < provisioned.length; pool++) {
        final values = [
          available[pool].previousValue,
          forwardInFlight[pool].previousValue,
          receiverOccupied[pool].previousValue,
          returnsInFlight[pool].previousValue,
        ];
        if (values.any((value) => value == null || !value.isValid)) {
          _report('credit.conservation_known', cycle,
              'Every conservation term must be known after reset.', {
            'pool': pool,
            'values': values,
          });
          continue;
        }
        final terms = values.cast<LogicValue>().map((value) => value.toInt());
        final observed = terms.fold(0, (sum, value) => sum + value);
        if (observed != provisioned[pool]) {
          _report(
              'credit.conservation',
              cycle,
              'End-to-end credit accounting does not equal '
                  'provisioned capacity.',
              {
                'pool': pool,
                'available': values[0]!.toInt(),
                'forwardInFlight': values[1]!.toInt(),
                'receiverOccupied': values[2]!.toInt(),
                'returnsInFlight': values[3]!.toInt(),
                'observed': observed,
                'provisioned': provisioned[pool],
              });
        }
      }
      cycle++;
    }
  }

  void _report(String id, int cycle, String message,
      Map<String, Object?> sampledValues) {
    final violation = CreditChannelViolation(
        id: id,
        cycle: cycle,
        endpoint: endpoint,
        message: message,
        sampledValues: sampledValues);
    _violations.add(violation);
    if (reportViolations) {
      logger.severe(violation);
    }
  }
}
