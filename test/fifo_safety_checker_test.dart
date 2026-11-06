// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// fifo_safety_checker_test.dart
// Tests for signal-level FIFO safety verification.
//
// 2026 August 3
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('accepts legal FIFO signal activity', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final writeEnable = Logic();
    final readEnable = Logic();
    final empty = Logic();
    final full = Logic();
    final error = Logic();
    final checker = FifoSafetyChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      writeEnable: writeEnable,
      readEnable: readEnable,
      empty: empty,
      full: full,
      error: error,
      enableEndOfTestEmptyCheck: false,
    );

    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());
    reset.inject(1);
    writeEnable.inject(0);
    readEnable.inject(0);
    empty.inject(1);
    full.inject(0);
    error.inject(0);
    await clk.nextPosedge;

    reset.inject(0);
    await clk.nextPosedge;

    writeEnable.inject(1);
    empty.inject(1);
    await clk.nextPosedge;

    writeEnable.inject(0);
    readEnable.inject(1);
    empty.inject(0);
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });

  test('permits a bypass read from an empty FIFO with a write', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final writeEnable = Logic();
    final readEnable = Logic();
    final empty = Logic();
    final full = Logic();
    final checker = FifoSafetyChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      writeEnable: writeEnable,
      readEnable: readEnable,
      empty: empty,
      full: full,
      allowReadWhenEmptyWithWrite: true,
      enableEndOfTestEmptyCheck: false,
    );

    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());
    reset.inject(1);
    writeEnable.inject(0);
    readEnable.inject(0);
    empty.inject(1);
    full.inject(0);
    await clk.nextPosedge;

    reset.inject(0);
    writeEnable.inject(1);
    readEnable.inject(1);
    await clk.nextPosedge;

    await Simulator.endSimulation();
  });
}
