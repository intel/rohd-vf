// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_channel_checker.dart
// Credit channel protocol verification.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Immutable pool configuration for a [CreditChannelChecker].
class CreditChannelCheckConfiguration {
  /// Credit counts provisioned by reset for each pool.
  final List<int> initialCredits;

  /// Maximum representable credit count for each pool.
  final List<int> maximumCredits;

  /// Optional aggregate initial credit count for shared-capacity channels.
  final int? sharedInitialCredits;

  /// Optional aggregate maximum credit count for shared-capacity channels.
  final int? sharedMaximumCredits;

  /// Creates a per-pool credit configuration.
  CreditChannelCheckConfiguration(
      {required List<int> initialCredits,
      required List<int> maximumCredits,
      this.sharedInitialCredits,
      this.sharedMaximumCredits})
      : initialCredits = List.unmodifiable(initialCredits),
        maximumCredits = List.unmodifiable(maximumCredits) {
    if (this.initialCredits.isEmpty ||
        this.initialCredits.length != this.maximumCredits.length) {
      throw ArgumentError(
          'Initial and maximum credits must be non-empty and equally sized.');
    }
    for (var pool = 0; pool < this.initialCredits.length; pool++) {
      final initial = this.initialCredits[pool];
      final maximum = this.maximumCredits[pool];
      if (initial < 0 || maximum < 1 || initial > maximum) {
        throw ArgumentError.value(
            '$initial/$maximum', 'pool $pool', 'Invalid credit bounds.');
      }
    }
    if ((sharedInitialCredits == null) != (sharedMaximumCredits == null)) {
      throw ArgumentError(
          'Shared initial and maximum credits must be provided together.');
    }
    if (sharedInitialCredits != null &&
        (sharedInitialCredits! < 0 ||
            sharedMaximumCredits! < 1 ||
            sharedInitialCredits! > sharedMaximumCredits!)) {
      throw ArgumentError.value('$sharedInitialCredits/$sharedMaximumCredits',
          'shared credits', 'Invalid shared credit bounds.');
    }
  }

  /// Creates a configuration with identical bounds for every pool.
  factory CreditChannelCheckConfiguration.uniform(
          {required int poolCount,
          required int initialCredits,
          required int maximumCredits}) =>
      CreditChannelCheckConfiguration(
          initialCredits: List.filled(poolCount, initialCredits),
          maximumCredits: List.filled(poolCount, maximumCredits));

  /// Creates shared-capacity accounting with pool-attributed event vectors.
  factory CreditChannelCheckConfiguration.shared(
          {required int poolCount,
          required int initialCredits,
          required int maximumCredits}) =>
      CreditChannelCheckConfiguration(
          initialCredits: List.filled(poolCount, 0),
          maximumCredits: List.filled(poolCount, maximumCredits),
          sharedInitialCredits: initialCredits,
          sharedMaximumCredits: maximumCredits);
}

/// One sampled credit-accounting violation.
class CreditChannelViolation {
  /// Stable rule identifier.
  final String id;

  /// Zero-based checker cycle at which the violation was sampled.
  final int cycle;

  /// Checked credit channel endpoint.
  final String endpoint;

  /// Human-readable description.
  final String message;

  /// Immutable values relevant to the violation.
  final Map<String, Object?> sampledValues;

  /// Creates a credit channel violation.
  CreditChannelViolation(
      {required this.id,
      required this.cycle,
      required this.endpoint,
      required this.message,
      Map<String, Object?> sampledValues = const {}})
      : sampledValues = UnmodifiableMapView(Map.of(sampledValues));

  @override
  String toString() => '$id at $endpoint cycle $cycle: $message $sampledValues';
}

/// Checks conservation and bounds for one or more independent credit pools.
class CreditChannelChecker extends Component {
  /// Clock used to sample the credit signals.
  final Logic clk;

  /// Active-high reset that restores `configuration.initialCredits`.
  final Logic reset;

  /// Additional reset sources that restart externally provisioned credits.
  final List<Logic> reinitializationResets;

  /// One-hot-or-zero debit vector, one bit for each credit pool.
  final Logic debit;

  /// Credit-return vector, one bit for each credit pool.
  final Logic creditReturn;

  /// Pool bounds and reset provisioning.
  final CreditChannelCheckConfiguration configuration;

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

  /// Modeled available credits for each pool.
  List<int> get credits => UnmodifiableListView(_credits);

  /// Modeled aggregate availability for a shared-capacity configuration.
  int? get sharedCredits =>
      configuration.sharedMaximumCredits == null ? null : _sharedCredits;

  /// Violations observed by this checker in sampling order.
  List<CreditChannelViolation> get violations =>
      UnmodifiableListView(_violations);

  /// Broadcast stream of newly observed violations.
  Stream<CreditChannelViolation> get violationStream =>
      _violationsController.stream;

  /// Creates a credit channel checker.
  CreditChannelChecker(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.debit,
      required this.creditReturn,
      required this.configuration,
      this.endpoint = 'creditChannel',
      this.reportViolations = true,
      Iterable<Logic> reinitializationResets = const []})
      : reinitializationResets = List.unmodifiable(reinitializationResets) {
    if (debit.width != configuration.initialCredits.length ||
        creditReturn.width != configuration.initialCredits.length) {
      throw ArgumentError(
          'Credit vectors must match the configured pool count.');
    }
    if (this.reinitializationResets.any((reset) => reset.width != 1)) {
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
      final debitValue = debit.previousValue;
      final creditReturnValue = creditReturn.previousValue;
      if (resetValue == null ||
          debitValue == null ||
          creditReturnValue == null) {
        cycle++;
        continue;
      }

      final inReset = (resetValue.isValid && resetValue.toBool()) ||
          reinitializationResets.any((reset) {
            final value = reset.previousValue;
            return value != null && value.isValid && value.toBool();
          });
      if (inReset) {
        _credits.setAll(0, configuration.initialCredits);
        _sharedCredits = configuration.sharedInitialCredits ??
            _credits.fold(0, (sum, credits) => sum + credits);
      } else if (!debitValue.isValid || !creditReturnValue.isValid) {
        _report(
            'credit.controls_known',
            cycle,
            'Debit and credit-return controls must be known after reset.',
            {'debit': debitValue, 'creditReturn': creditReturnValue});
      } else {
        final debitedPools = [
          for (var pool = 0; pool < debit.width; pool++)
            if (debitValue[pool].toBool()) pool
        ];
        if (debitedPools.length > 1) {
          _report(
              'credit.debit_one_hot',
              cycle,
              'At most one credit pool may be debited in a cycle.',
              {'debit': debitValue, 'pools': debitedPools});
        }
        if (configuration.sharedMaximumCredits != null) {
          _checkSharedCredits(debitedPools, creditReturnValue, cycle);
        } else {
          for (final pool in debitedPools) {
            if (_credits[pool] == 0) {
              _report(
                  'credit.no_credit',
                  cycle,
                  'A send consumed a credit from an empty pool.',
                  {'pool': pool, 'credits': _credits[pool]});
            } else {
              _credits[pool]--;
            }
          }
          for (var pool = 0; pool < creditReturn.width; pool++) {
            if (creditReturnValue[pool].toBool()) {
              if (_credits[pool] == configuration.maximumCredits[pool]) {
                _report('credit.overflow', cycle,
                    'A credit return exceeded the configured pool capacity.', {
                  'pool': pool,
                  'credits': _credits[pool],
                  'maximumCredits': configuration.maximumCredits[pool]
                });
              } else {
                _credits[pool]++;
              }
            }
          }
        }
      }
      cycle++;
    }
  }

  void _checkSharedCredits(
      List<int> debitedPools, LogicValue creditReturnValue, int cycle) {
    for (final pool in debitedPools) {
      if (_sharedCredits == 0) {
        _report(
            'credit.no_credit',
            cycle,
            'A send consumed a credit from an empty shared pool.',
            {'pool': pool, 'credits': _sharedCredits});
      } else {
        _sharedCredits--;
      }
    }
    for (var pool = 0; pool < creditReturn.width; pool++) {
      if (creditReturnValue[pool].toBool()) {
        if (_sharedCredits == configuration.sharedMaximumCredits) {
          _report('credit.overflow', cycle,
              'A credit return exceeded shared pool capacity.', {
            'pool': pool,
            'credits': _sharedCredits,
            'maximumCredits': configuration.sharedMaximumCredits
          });
        } else {
          _sharedCredits++;
        }
      }
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
