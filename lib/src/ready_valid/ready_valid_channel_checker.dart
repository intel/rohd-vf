// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_channel_checker.dart
// Ready/valid channel protocol verification.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';
import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

class _SampledPayload<ValueType> {
  final ValueType value;

  const _SampledPayload(this.value);
}

/// Static ready/valid checks enabled for a channel boundary.
class ReadyValidChannelCheckConfiguration<LogicType extends Logic, ValueType> {
  /// Requires known ready and valid controls after reset.
  final bool controlsMustBeKnown;

  /// Prohibits transfers while reset is asserted.
  final bool transfersForbiddenDuringReset;

  /// Requires valid to remain asserted after a stalled offer.
  final bool validMustRemainAssertedWhileStalled;

  /// Requires the payload to remain unchanged after a stalled offer.
  final bool payloadMustRemainStableWhileStalled;

  /// Optional maximum number of consecutive stalled cycles.
  final int? maximumStallCycles;

  /// Compares two sampled payloads when payload stability is enabled.
  // Callers must provide values compatible with the configured callback.
  // ignore: unsafe_variance
  final bool Function(ValueType previous, ValueType current) payloadEquals;

  /// Creates a ready/valid channel checker configuration.
  ReadyValidChannelCheckConfiguration(
      {this.controlsMustBeKnown = true,
      this.transfersForbiddenDuringReset = true,
      this.validMustRemainAssertedWhileStalled = false,
      this.payloadMustRemainStableWhileStalled = false,
      this.maximumStallCycles,
      bool Function(ValueType previous, ValueType current)? payloadEquals})
      : payloadEquals =
            payloadEquals ?? ((previous, current) => previous == current) {
    if (maximumStallCycles != null && maximumStallCycles! < 1) {
      throw ArgumentError.value(
          maximumStallCycles, 'maximumStallCycles', 'Must be at least one.');
    }
  }
}

/// One ready/valid protocol violation sampled by a channel checker.
class ReadyValidChannelViolation {
  /// Stable rule identifier.
  final String id;

  /// Zero-based checker cycle at which the violation was sampled.
  final int cycle;

  /// Checked channel endpoint.
  final String endpoint;

  /// Human-readable description.
  final String message;

  /// Immutable values relevant to the violation.
  final Map<String, Object?> sampledValues;

  /// Creates a protocol violation.
  ReadyValidChannelViolation(
      {required this.id,
      required this.cycle,
      required this.endpoint,
      required this.message,
      Map<String, Object?> sampledValues = const {}})
      : sampledValues = UnmodifiableMapView(Map.of(sampledValues));

  @override
  String toString() => '$id at $endpoint cycle $cycle: $message $sampledValues';
}

/// Checks one ready/valid boundary at rising clock edges.
class ReadyValidChannelChecker<LogicType extends Logic, ValueType>
    extends Component {
  /// Clock used to sample the channel.
  final Logic clk;

  /// Active-high channel reset.
  final Logic reset;

  /// Consumer handshake control.
  final Logic ready;

  /// Provider handshake control.
  final Logic valid;

  /// Channel payload.
  final LogicType data;

  /// Codec used to sample semantic payload values.
  final ReadyValidChannelCodec<LogicType, ValueType> codec;

  /// Enabled safety and bounded-liveness checks.
  final ReadyValidChannelCheckConfiguration<LogicType, ValueType> configuration;

  /// Whether observed violations are logged as `SEVERE`.
  final bool reportViolations;

  /// Boundary name recorded in violations.
  final String endpoint;

  final StreamController<ReadyValidChannelViolation> _violationsController =
      StreamController<ReadyValidChannelViolation>.broadcast(sync: true);
  final List<ReadyValidChannelViolation> _violations = [];

  /// Violations observed by this checker in sampling order.
  List<ReadyValidChannelViolation> get violations =>
      UnmodifiableListView(_violations);

  /// Broadcast stream of newly observed violations.
  Stream<ReadyValidChannelViolation> get violationStream =>
      _violationsController.stream;

  /// Creates a channel checker.
  ReadyValidChannelChecker(super.name, super.parent,
      {required this.clk,
      required this.reset,
      required this.ready,
      required this.valid,
      required this.data,
      required this.codec,
      this.endpoint = 'readyValidChannel',
      ReadyValidChannelCheckConfiguration<LogicType, ValueType>? configuration,
      this.reportViolations = true})
      : configuration = configuration ??
            ReadyValidChannelCheckConfiguration<LogicType, ValueType>();

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    var cycle = 0;
    var previousWasStalled = false;
    _SampledPayload<ValueType>? previousPayload;
    LogicValue? previousReady;
    LogicValue? previousValid;
    var stalledCycles = 0;
    while (!Simulator.simulationHasEnded) {
      await clk.nextPosedge;
      if (Simulator.simulationHasEnded) {
        return;
      }

      final resetValue = reset.previousValue;
      final readyValue = ready.previousValue;
      final validValue = valid.previousValue;
      if (resetValue == null || readyValue == null || validValue == null) {
        cycle++;
        continue;
      }

      final inReset = resetValue.isValid && resetValue.toBool();
      final controlsKnown = readyValue.isValid && validValue.isValid;
      final currentValid = controlsKnown && validValue.toBool();
      final currentStalled = currentValid && !readyValue.toBool();
      if (!inReset && configuration.controlsMustBeKnown && !controlsKnown) {
        _report(
            'rv.controls_known',
            cycle,
            'Ready and valid must be known after reset.',
            {'ready': readyValue, 'valid': validValue});
      }
      if (inReset &&
          configuration.transfersForbiddenDuringReset &&
          controlsKnown &&
          readyValue.toBool() &&
          validValue.toBool()) {
        _report(
            'rv.no_transfer_during_reset',
            cycle,
            'A transfer completed while reset was asserted.',
            {'ready': readyValue, 'valid': validValue});
      }
      if (!inReset &&
          previousWasStalled &&
          configuration.validMustRemainAssertedWhileStalled &&
          !currentValid) {
        _report('rv.valid_held_while_stalled', cycle,
            'Valid was withdrawn before the offer was accepted.', {
          'previousReady': previousReady,
          'previousValid': previousValid,
          'currentValid': validValue
        });
      }

      _SampledPayload<ValueType>? currentPayload;
      if (!inReset &&
          configuration.payloadMustRemainStableWhileStalled &&
          (previousWasStalled || currentStalled)) {
        currentPayload = _SampledPayload(codec.sample(data, previous: true));
        if (previousWasStalled &&
            currentValid &&
            previousPayload != null &&
            !configuration.payloadEquals(
                previousPayload.value, currentPayload.value)) {
          _report('rv.payload_stable_while_stalled', cycle,
              'Payload changed while the offer remained stalled.', {
            'previousPayload': previousPayload.value,
            'currentPayload': currentPayload.value
          });
        }
      }

      if (inReset || !currentStalled) {
        stalledCycles = 0;
      } else {
        stalledCycles++;
        final maximumStallCycles = configuration.maximumStallCycles;
        if (maximumStallCycles != null &&
            stalledCycles == maximumStallCycles + 1) {
          _report('rv.max_stall_cycles', cycle,
              'The ready/valid offer exceeded its stall bound.', {
            'maximumCycles': maximumStallCycles,
            'stalledCycles': stalledCycles
          });
        }
      }

      previousWasStalled = !inReset && currentStalled;
      previousPayload = previousWasStalled ? currentPayload : null;
      previousReady = readyValue;
      previousValid = validValue;
      cycle++;
    }
  }

  void _report(String id, int cycle, String message,
      Map<String, Object?> sampledValues) {
    final violation = ReadyValidChannelViolation(
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
