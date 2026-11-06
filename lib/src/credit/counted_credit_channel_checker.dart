// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counted_credit_channel_checker.dart
// Verification of credit channels with counted events.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Eligibility rule for simultaneous counted debit and return events.
enum CountedCreditSameCyclePolicy {
  /// Debits may use only the balance present at the start of the cycle.
  debitThenReturn,

  /// Debit and return counts form one atomic balance update.
  atomicNet,
}

/// Handling for a counted event that crosses an accounting boundary.
enum CountedCreditViolationHandling {
  /// Apply none of the violating count.
  reject,

  /// Apply the largest count that remains within the configured bounds.
  saturate,
}

/// Checks counted debit and return events for independent or shared pools.
///
/// Multiple pools may be debited and returned in the same cycle. For an
/// atomic multi-resource transaction, connect the gate's accepted debit
/// counts rather than its unaccepted requirements.
class CountedCreditChannelChecker extends Component {
  /// Clock used to sample accounting events.
  final Logic clk;

  /// Active-high reset that restores the configured initial credits.
  final Logic reset;

  /// One counted debit signal for every pool.
  final List<Logic> debitCounts;

  /// One counted return signal for every pool.
  final List<Logic> returnCounts;

  /// Pool bounds and reset provisioning.
  final CreditChannelCheckConfiguration configuration;

  /// Concurrent event ordering.
  final CountedCreditSameCyclePolicy sameCyclePolicy;

  /// Boundary behavior for invalid counts.
  final CountedCreditViolationHandling violationHandling;

  /// Additional reset sources that restart externally provisioned credits.
  final List<Logic> reinitializationResets;

  /// Whether observed violations are logged as `SEVERE`.
  final bool reportViolations;

  /// Boundary name recorded in violations.
  final String endpoint;

  final StreamController<CreditChannelViolation> _violationsController =
      StreamController<CreditChannelViolation>.broadcast(sync: true);
  final List<CreditChannelViolation> _violations = [];
  late final List<int> _credits = List.of(configuration.initialCredits);
  late int _sharedCredits =
      configuration.sharedInitialCredits ?? _credits.fold(0, (a, b) => a + b);

  /// Modeled available credits for independent pools.
  List<int> get credits => UnmodifiableListView(_credits);

  /// Modeled availability for a shared-capacity configuration.
  int? get sharedCredits =>
      configuration.sharedMaximumCredits == null ? null : _sharedCredits;

  /// Violations observed in sampling order.
  List<CreditChannelViolation> get violations =>
      UnmodifiableListView(_violations);

  /// Broadcast stream of newly observed violations.
  Stream<CreditChannelViolation> get violationStream =>
      _violationsController.stream;

  /// Creates a counted credit checker.
  CountedCreditChannelChecker(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required List<Logic> debitCounts,
      required List<Logic> returnCounts,
      required this.configuration,
      this.sameCyclePolicy = CountedCreditSameCyclePolicy.debitThenReturn,
      this.violationHandling = CountedCreditViolationHandling.reject,
      this.endpoint = 'countedCreditChannel',
      this.reportViolations = true,
      Iterable<Logic> reinitializationResets = const []})
      : debitCounts = List.unmodifiable(debitCounts),
        returnCounts = List.unmodifiable(returnCounts),
        reinitializationResets = List.unmodifiable(reinitializationResets) {
    final poolCount = configuration.initialCredits.length;
    if (this.debitCounts.length != poolCount ||
        this.returnCounts.length != poolCount) {
      throw ArgumentError(
          'Debit and return counts must contain one signal per pool.');
    }
    if ([...this.debitCounts, ...this.returnCounts]
        .any((signal) => signal.width < 1)) {
      throw ArgumentError('Count signals must be at least one bit wide.');
    }
    if (this.reinitializationResets.any((signal) => signal.width != 1)) {
      throw ArgumentError('Reinitialization resets must be one bit wide.');
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
      final debitValues = debitCounts.map((signal) => signal.previousValue);
      final returnValues = returnCounts.map((signal) => signal.previousValue);
      if (resetValue == null ||
          debitValues.any((value) => value == null) ||
          returnValues.any((value) => value == null)) {
        cycle++;
        continue;
      }

      final inReset = (resetValue.isValid && resetValue.toBool()) ||
          reinitializationResets.any((signal) {
            final value = signal.previousValue;
            return value != null && value.isValid && value.toBool();
          });
      if (inReset) {
        _credits.setAll(0, configuration.initialCredits);
        _sharedCredits = configuration.sharedInitialCredits ??
            _credits.fold(0, (sum, credits) => sum + credits);
        cycle++;
        continue;
      }

      final allValues = [...debitValues, ...returnValues].cast<LogicValue>();
      if (allValues.any((value) => !value.isValid)) {
        _report('credit.counts_known', cycle,
            'Debit and return counts must be known after reset.', {
          'debitCounts': debitValues.toList(),
          'returnCounts': returnValues.toList(),
        });
        cycle++;
        continue;
      }

      final debits = debitValues
          .cast<LogicValue>()
          .map((value) => value.toInt())
          .toList(growable: false);
      final returns = returnValues
          .cast<LogicValue>()
          .map((value) => value.toInt())
          .toList(growable: false);
      if (configuration.sharedMaximumCredits == null) {
        for (var pool = 0; pool < _credits.length; pool++) {
          _credits[pool] = _applyCounts(
              current: _credits[pool],
              maximum: configuration.maximumCredits[pool],
              debit: debits[pool],
              creditReturn: returns[pool],
              pool: pool,
              cycle: cycle);
        }
      } else {
        _sharedCredits = _applyCounts(
            current: _sharedCredits,
            maximum: configuration.sharedMaximumCredits!,
            debit: debits.fold(0, (sum, value) => sum + value),
            creditReturn: returns.fold(0, (sum, value) => sum + value),
            pool: null,
            cycle: cycle);
      }
      cycle++;
    }
  }

  int _applyCounts(
      {required int current,
      required int maximum,
      required int debit,
      required int creditReturn,
      required int? pool,
      required int cycle}) {
    if (sameCyclePolicy == CountedCreditSameCyclePolicy.atomicNet) {
      final underflow = debit > maximum || debit > current + creditReturn;
      final overflow = creditReturn > maximum ||
          current + creditReturn - min(debit, current + creditReturn) > maximum;
      _reportBounds(underflow, overflow, current, maximum, debit, creditReturn,
          pool, cycle);
      if (violationHandling == CountedCreditViolationHandling.reject &&
          (underflow || overflow)) {
        return current;
      }
      final boundedReturn = min(creditReturn, maximum);
      final acceptedDebit = min(debit, current + boundedReturn);
      return min(maximum, current + boundedReturn - acceptedDebit);
    }

    final underflow = debit > current;
    final acceptedDebit = underflow
        ? violationHandling == CountedCreditViolationHandling.saturate
            ? current
            : 0
        : debit;
    final roomAfterDebit = maximum - current + acceptedDebit;
    final overflow = creditReturn > roomAfterDebit;
    final acceptedReturn = overflow
        ? violationHandling == CountedCreditViolationHandling.saturate
            ? roomAfterDebit
            : 0
        : creditReturn;
    _reportBounds(underflow, overflow, current, maximum, debit, creditReturn,
        pool, cycle);
    return current - acceptedDebit + acceptedReturn;
  }

  void _reportBounds(bool underflow, bool overflow, int current, int maximum,
      int debit, int creditReturn, int? pool, int cycle) {
    final scope = pool == null ? 'shared capacity' : 'pool $pool';
    if (underflow) {
      _report('credit.counted_underflow', cycle,
          'A counted debit exceeded $scope availability.', {
        'pool': pool,
        'credits': current,
        'debitCount': debit,
        'returnCount': creditReturn,
      });
    }
    if (overflow) {
      _report('credit.counted_overflow', cycle,
          'A counted return exceeded $scope capacity.', {
        'pool': pool,
        'credits': current,
        'maximumCredits': maximum,
        'debitCount': debit,
        'returnCount': creditReturn,
      });
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
    _violationsController.add(violation);
    if (reportViolations) {
      logger.severe(violation);
    }
  }
}
