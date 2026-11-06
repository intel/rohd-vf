// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// flow_scoreboard_test.dart
// Tests for flow scoreboards.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  group('FlowScoreboard', () {
    test('strict mode identifies ordering before value mismatch', () {
      final scoreboard = FlowScoreboard<int, Never>.strict()
        ..expectAll([1, 2, 3])
        ..observe(2, cycle: 4, endpoint: 'sink');
      final failures = scoreboard.failures;

      expect(failures, hasLength(1));
      expect(failures.single.id, 'scoreboard.order');
      expect(failures.single.expected, 1);
      expect(failures.single.actual, 2);
    });

    test('strict mode reports unexpected duplicate data', () {
      final scoreboard = FlowScoreboard<int, Never>.strict()
        ..expect(4)
        ..observe(4, cycle: 1, endpoint: 'sink')
        ..observe(4, cycle: 2, endpoint: 'sink');

      expect(scoreboard.failures.single.id, 'scoreboard.unexpected');
    });

    test('per-key mode preserves order independently per key', () {
      final scoreboard = FlowScoreboard<String, String>.perKey(
          keyOf: (value) => value.substring(0, 1))
        ..expectAll(['a1', 'a2', 'b1'])
        ..observe('b1', cycle: 1, endpoint: 'sink')
        ..observe('a1', cycle: 2, endpoint: 'sink')
        ..observe('a2', cycle: 3, endpoint: 'sink');

      expect(scoreboard.failures, isEmpty);
      expect(scoreboard.verifyComplete(), isEmpty);
    });

    test('unordered mode matches an equivalent multiset', () {
      final scoreboard = FlowScoreboard<int, Never>.unordered()
        ..expectAll([1, 2, 2])
        ..observe(2, cycle: 1, endpoint: 'sink')
        ..observe(1, cycle: 2, endpoint: 'sink')
        ..observe(2, cycle: 3, endpoint: 'sink');

      expect(scoreboard.failures, isEmpty);
      expect(scoreboard.verifyComplete(), isEmpty);
    });

    test('completion reports every missing expectation', () {
      final scoreboard = FlowScoreboard<int, Never>.strict()..expectAll([8, 9]);

      final failures = scoreboard.verifyComplete(cycle: 12, endpoint: 'sink');

      expect(failures, hasLength(2));
      expect(failures.every((failure) => failure.id == 'scoreboard.missing'),
          isTrue);
    });
  });
}
