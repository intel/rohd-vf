// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// keyed_transaction_namespace_key_test.dart
// Tests for transaction namespace keys.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  test('models independent requester-ID spaces with a composite key', () {
    final checker = KeyedTransactionLifecycleChecker<
        TransactionNamespaceKey<int, int>, String>();
    const first = TransactionNamespaceKey(0, 7);
    const second = TransactionNamespaceKey(1, 7);

    // PCIe requester/tag and ATCB interface/ID ownership have this shape:
    // local IDs may match while the owning namespace differs.
    checker
      ..observeRequest(key: first, resource: 'first', cycle: 1)
      ..observeRequest(key: second, resource: 'second', cycle: 2);
    expect(
      checker.observeResponse(key: second, completes: true, cycle: 3),
      'second',
    );
    expect(checker.outstanding, {first: 'first'});
    expect(checker.failures, isEmpty);
  });
}
