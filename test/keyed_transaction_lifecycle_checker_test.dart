// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// keyed_transaction_lifecycle_checker_test.dart
// Tests for keyed transaction lifecycle verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  test('retains resource attribution until completion or cancellation', () {
    final checker = KeyedTransactionLifecycleChecker<int, String>()
      ..observeRequest(key: 3, resource: 'low', cycle: 1);
    expect(checker.observeResponse(key: 3, completes: false, cycle: 2), 'low');
    expect(checker.outstanding, {3: 'low'});
    expect(checker.observeResponse(key: 3, completes: true, cycle: 3), 'low');
    expect(checker.outstanding, isEmpty);

    checker.observeRequest(key: 4, resource: 'high', cycle: 4);
    expect(checker.observeCancellation(key: 4, cycle: 5), 'high');
    expect(checker.verifyComplete(cycle: 6), isEmpty);
    expect(checker.failures, isEmpty);
  });

  test('reports duplicate requests, unknown responses, and cancel misses', () {
    final checker = KeyedTransactionLifecycleChecker<int, int>()
      ..observeRequest(key: 1, resource: 0, cycle: 1)
      ..observeRequest(key: 1, resource: 1, cycle: 2)
      ..observeResponse(key: 2, completes: true, cycle: 3)
      ..observeCancellation(key: 3, cycle: 4);
    expect(checker.failures.map((failure) => failure.id), [
      'lifecycle.duplicate_key',
      'lifecycle.unexpected_response',
      'lifecycle.cancel_miss',
    ]);
  });
}
