// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_storage_status_checker_test.dart
// Tests for ready/valid retained-storage status verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class _StorageStatusCycle {
  final int reset;
  final LogicValue occupancy;
  final LogicValue empty;
  final LogicValue full;

  const _StorageStatusCycle(this.reset, this.occupancy, this.empty, this.full);
}

Future<List<ReadyValidStorageStatusViolation>> _runChecker(
  List<_StorageStatusCycle> cycles,
) async {
  final clk = SimpleClockGenerator(10).clk;
  final reset = Logic();
  final occupancy = Logic(width: 2);
  final empty = Logic();
  final full = Logic();
  final checker = ReadyValidStorageStatusChecker(
    'checker',
    null,
    clk: clk,
    reset: reset,
    capacity: 2,
    occupancy: occupancy,
    empty: empty,
    full: full,
    reportViolations: false,
  );

  unawaited(checker.run(Phase()));
  unawaited(Simulator.run());
  for (final cycle in cycles) {
    reset.inject(cycle.reset);
    occupancy.inject(cycle.occupancy);
    empty.inject(cycle.empty);
    full.inject(cycle.full);
    await clk.nextPosedge;
  }
  await Simulator.endSimulation();
  return checker.violations;
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('accepts consistent empty, partial, and full status', () async {
    final violations = await _runChecker([
      const _StorageStatusCycle(
        0,
        LogicValue.zero,
        LogicValue.one,
        LogicValue.zero,
      ),
      _StorageStatusCycle(
        0,
        LogicValue.ofInt(1, 2),
        LogicValue.zero,
        LogicValue.zero,
      ),
      _StorageStatusCycle(
        0,
        LogicValue.ofInt(2, 2),
        LogicValue.zero,
        LogicValue.one,
      ),
    ]);

    expect(violations, isEmpty);
  });

  test('reports inconsistent and out-of-range status', () async {
    final violations = await _runChecker([
      _StorageStatusCycle(
        0,
        LogicValue.ofInt(3, 2),
        LogicValue.zero,
        LogicValue.zero,
      ),
      const _StorageStatusCycle(
        0,
        LogicValue.zero,
        LogicValue.zero,
        LogicValue.one,
      ),
    ]);

    expect(violations.map((violation) => violation.id), [
      'storage.occupancy_in_range',
      'storage.empty_matches_occupancy',
      'storage.full_matches_occupancy',
    ]);
  });

  test('reports unknown status signals after reset', () async {
    final violations = await _runChecker([
      const _StorageStatusCycle(
        0,
        LogicValue.x,
        LogicValue.zero,
        LogicValue.zero,
      ),
    ]);

    expect(violations.map((violation) => violation.id), [
      'storage.status_known',
    ]);
  });
}
