// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counted_credit_channel_checker_test.dart
// Tests for counted credit channel verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(Simulator.reset);

  test('checks concurrent counted events across independent pools', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final debits = [Logic(width: 2), Logic(width: 2)];
    final returns = [Logic(width: 2), Logic(width: 2)];
    final checker = CountedCreditChannelChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      debitCounts: debits,
      returnCounts: returns,
      configuration: CreditChannelCheckConfiguration(
        initialCredits: [2, 0],
        maximumCredits: [3, 3],
      ),
      sameCyclePolicy: CountedCreditSameCyclePolicy.atomicNet,
      reportViolations: false,
    );
    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());

    reset.inject(1);
    for (final signal in [...debits, ...returns]) {
      signal.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);

    debits[0].inject(1);
    debits[1].inject(1);
    returns[1].inject(1);
    await clk.nextPosedge;
    expect(checker.credits, [1, 0]);
    expect(checker.violations, isEmpty);

    debits[0].inject(2);
    debits[1].inject(0);
    returns[1].inject(0);
    await clk.nextPosedge;
    expect(checker.credits, [1, 0]);
    expect(checker.violations.single.id, 'credit.counted_underflow');
    await Simulator.endSimulation();
  });

  test('sums concurrent pool events for shared capacity', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final debits = [Logic(width: 2), Logic(width: 2)];
    final returns = [Logic(width: 2), Logic(width: 2)];
    final checker = CountedCreditChannelChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      debitCounts: debits,
      returnCounts: returns,
      configuration: CreditChannelCheckConfiguration.shared(
        poolCount: 2,
        initialCredits: 4,
        maximumCredits: 4,
      ),
      reportViolations: false,
    );
    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());

    reset.inject(1);
    for (final signal in [...debits, ...returns]) {
      signal.inject(0);
    }
    await clk.nextPosedge;
    reset.inject(0);
    debits[0].inject(1);
    debits[1].inject(2);
    await clk.nextPosedge;
    expect(checker.sharedCredits, 1);
    expect(checker.violations, isEmpty);
    await Simulator.endSimulation();
  });

  test('checks the four-term end-to-end conservation invariant', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final available = Logic(width: 3);
    final forward = Logic(width: 3);
    final occupied = Logic(width: 3);
    final returning = Logic(width: 3);
    final checker = CreditConservationChecker(
      'conservation',
      null,
      clk: clk,
      reset: reset,
      available: [available],
      forwardInFlight: [forward],
      receiverOccupied: [occupied],
      returnsInFlight: [returning],
      provisioned: [6],
      reportViolations: false,
    );
    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());

    reset.inject(1);
    available.inject(6);
    forward.inject(0);
    occupied.inject(0);
    returning.inject(0);
    await clk.nextPosedge;
    reset.inject(0);

    available.inject(2);
    forward.inject(1);
    occupied.inject(2);
    returning.inject(1);
    await clk.nextPosedge;
    expect(checker.violations, isEmpty);

    returning.inject(0);
    await clk.nextPosedge;
    expect(checker.violations.single.id, 'credit.conservation');
    await Simulator.endSimulation();
  });
}
