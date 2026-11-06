// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flow_scoreboard.dart
// Scoreboard for expected and observed payload flows.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

enum _FlowScoreboardMode { strict, perKey, unordered }

/// A semantic failure reported by a [FlowScoreboard].
class FlowFailure<PayloadType> {
  /// Stable failure identifier.
  final String id;

  /// Cycle associated with the failure, when available.
  final int? cycle;

  /// Endpoint associated with the failure.
  final String endpoint;

  /// Human-readable failure description.
  final String message;

  /// Expected payload, when available.
  final PayloadType? expected;

  /// Actual payload, when available.
  final PayloadType? actual;

  /// Creates a scoreboard failure.
  const FlowFailure(
      {required this.id,
      required this.endpoint,
      required this.message,
      this.cycle,
      this.expected,
      this.actual});

  @override
  String toString() => '$id at $endpoint'
      '${cycle == null ? '' : ' cycle $cycle'}: $message';
}

/// Compares expected and observed payload flows.
class FlowScoreboard<PayloadType, KeyType> {
  final _FlowScoreboardMode _mode;
  // Callbacks are invoked only with values accepted by this scoreboard.
  // ignore: unsafe_variance
  final bool Function(PayloadType expected, PayloadType actual) _equals;
  // Key extraction uses only values accepted by this scoreboard.
  // ignore: unsafe_variance
  final KeyType Function(PayloadType value) _keyOf;
  final List<PayloadType> _expected = [];
  final Map<KeyType, List<PayloadType>> _expectedByKey = {};
  final List<FlowFailure<PayloadType>> _failures = [];

  FlowScoreboard._(
      this._mode, this._equals, KeyType Function(PayloadType value)? keyOf)
      : _keyOf = keyOf ??
            ((value) => throw StateError('This scoreboard does not use keys.'));

  /// Creates a scoreboard that requires global FIFO order.
  factory FlowScoreboard.strict(
          {bool Function(PayloadType expected, PayloadType actual)? equals}) =>
      FlowScoreboard._(_FlowScoreboardMode.strict,
          equals ?? (expected, actual) => expected == actual, null);

  /// Creates a scoreboard that requires FIFO order independently per key.
  factory FlowScoreboard.perKey(
          {required KeyType Function(PayloadType value) keyOf,
          bool Function(PayloadType expected, PayloadType actual)? equals}) =>
      FlowScoreboard._(_FlowScoreboardMode.perKey,
          equals ?? (expected, actual) => expected == actual, keyOf);

  /// Creates a scoreboard that compares an unordered multiset.
  factory FlowScoreboard.unordered(
          {bool Function(PayloadType expected, PayloadType actual)? equals}) =>
      FlowScoreboard._(_FlowScoreboardMode.unordered,
          equals ?? (expected, actual) => expected == actual, null);

  /// Failures accumulated while observing payloads.
  List<FlowFailure<PayloadType>> get failures =>
      UnmodifiableListView(_failures);

  /// Whether every expectation has been matched.
  bool get isComplete => switch (_mode) {
        _FlowScoreboardMode.perKey =>
          _expectedByKey.values.every((values) => values.isEmpty),
        _ => _expected.isEmpty
      };

  /// Adds one expected payload.
  void expect(PayloadType value) {
    if (_mode == _FlowScoreboardMode.perKey) {
      final key = _keyOf(value);
      _expectedByKey.putIfAbsent(key, () => []).add(value);
    } else {
      _expected.add(value);
    }
  }

  /// Adds all [values] as expectations in iteration order.
  void expectAll(Iterable<PayloadType> values) => values.forEach(expect);

  /// Compares one observed [value] against outstanding expectations.
  void observe(PayloadType value,
      {required int cycle, required String endpoint}) {
    switch (_mode) {
      case _FlowScoreboardMode.strict:
        _observeOrdered(_expected, value, cycle, endpoint);
      case _FlowScoreboardMode.perKey:
        final key = _keyOf(value);
        _observeOrdered(
            _expectedByKey[key] ?? <PayloadType>[], value, cycle, endpoint);
      case _FlowScoreboardMode.unordered:
        final matchingIndex = _indexOf(_expected, value);
        if (matchingIndex < 0) {
          _addUnexpected(value, cycle, endpoint);
        } else {
          _expected.removeAt(matchingIndex);
        }
    }
  }

  void _observeOrdered(List<PayloadType> expectedValues, PayloadType actual,
      int cycle, String endpoint) {
    if (expectedValues.isEmpty) {
      _addUnexpected(actual, cycle, endpoint);
      return;
    }

    final expected = expectedValues.first;
    if (_equals(expected, actual)) {
      expectedValues.removeAt(0);
      return;
    }

    final laterIndex = _indexOf(expectedValues, actual, start: 1);
    if (laterIndex >= 0) {
      expectedValues.removeAt(laterIndex);
      _failures.add(FlowFailure(
          id: 'scoreboard.order',
          cycle: cycle,
          endpoint: endpoint,
          message: 'Observed a payload before an earlier expectation.',
          expected: expected,
          actual: actual));
      return;
    }

    expectedValues.removeAt(0);
    _failures.add(FlowFailure(
        id: 'scoreboard.mismatch',
        cycle: cycle,
        endpoint: endpoint,
        message: 'Observed payload does not match the next expectation.',
        expected: expected,
        actual: actual));
  }

  void _addUnexpected(PayloadType actual, int cycle, String endpoint) {
    _failures.add(FlowFailure(
        id: 'scoreboard.unexpected',
        cycle: cycle,
        endpoint: endpoint,
        message: 'Observed payload with no matching expectation.',
        actual: actual));
  }

  int _indexOf(List<PayloadType> values, PayloadType actual, {int start = 0}) {
    for (var index = start; index < values.length; index++) {
      if (_equals(values[index], actual)) {
        return index;
      }
    }
    return -1;
  }

  /// Returns failures for all expectations that remain unmatched.
  List<FlowFailure<PayloadType>> verifyComplete(
      {int? cycle, String endpoint = 'scoreboard'}) {
    final remaining = switch (_mode) {
      _FlowScoreboardMode.perKey =>
        _expectedByKey.values.expand((values) => values),
      _ => _expected
    };

    return List.unmodifiable(remaining.map((expected) => FlowFailure(
        id: 'scoreboard.missing',
        cycle: cycle,
        endpoint: endpoint,
        message: 'An expected payload was not observed.',
        expected: expected)));
  }
}
