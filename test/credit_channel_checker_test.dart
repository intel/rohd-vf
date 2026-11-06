// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// credit_channel_checker_test.dart
// Tests for credit channel verification.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('monitors and conserves independent credit pools', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final debit = Logic(width: 2);
    final creditReturn = Logic(width: 2);
    final checker = CreditChannelChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      debit: debit,
      creditReturn: creditReturn,
      configuration: CreditChannelCheckConfiguration(
        initialCredits: [1, 1],
        maximumCredits: [2, 2],
      ),
      reportViolations: false,
    );
    final monitor = CreditChannelMonitor(
      'monitor',
      null,
      clk: clk,
      reset: reset,
      debit: debit,
      creditReturn: creditReturn,
    );
    final events = <CreditTransferItem>[];
    monitor.stream.listen(events.add);

    unawaited(checker.run(Phase()));
    unawaited(monitor.run(Phase()));
    unawaited(Simulator.run());

    reset.inject(1);
    debit.inject(0);
    creditReturn.inject(0);
    await clk.nextPosedge;

    reset.inject(0);
    debit.inject(0x1);
    await clk.nextPosedge;
    debit.inject(0);
    creditReturn.inject(0x1);
    await clk.nextPosedge;
    debit.inject(0x2);
    creditReturn.inject(0x2);
    await clk.nextPosedge;

    expect(checker.credits, [1, 1]);
    expect(checker.violations, isEmpty);
    expect(events.map((event) => (event.kind, event.pool)), [
      (CreditTransferKind.debit, 0),
      (CreditTransferKind.creditReturn, 0),
      (CreditTransferKind.debit, 1),
      (CreditTransferKind.creditReturn, 1),
    ]);
    await Simulator.endSimulation();
  });

  test('reports debit encoding, underflow, and overflow', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final debit = Logic(width: 2);
    final creditReturn = Logic(width: 2);
    final checker = CreditChannelChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      debit: debit,
      creditReturn: creditReturn,
      configuration: CreditChannelCheckConfiguration(
        initialCredits: [0, 1],
        maximumCredits: [1, 1],
      ),
      reportViolations: false,
    );

    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());

    reset.inject(1);
    debit.inject(0);
    creditReturn.inject(0);
    await clk.nextPosedge;

    reset.inject(0);
    debit.inject(0x3);
    await clk.nextPosedge;
    debit.inject(0);
    creditReturn.inject(0x3);
    await clk.nextPosedge;
    creditReturn.inject(0x3);
    await clk.nextPosedge;

    expect(
      checker.violations.map((violation) => violation.id),
      containsAll([
        'credit.debit_one_hot',
        'credit.no_credit',
        'credit.overflow',
      ]),
    );
    await Simulator.endSimulation();
  });

  test('conserves one shared capacity across pool-attributed events', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final debit = Logic(width: 2);
    final creditReturn = Logic(width: 2);
    final checker = CreditChannelChecker(
      'checker',
      null,
      clk: clk,
      reset: reset,
      debit: debit,
      creditReturn: creditReturn,
      configuration: CreditChannelCheckConfiguration.shared(
        poolCount: 2,
        initialCredits: 2,
        maximumCredits: 2,
      ),
      reportViolations: false,
    );
    unawaited(checker.run(Phase()));
    unawaited(Simulator.run());

    final activity = CreditChannelActivity.scripted([
      const CreditChannelActivityEvent(debitPool: 0),
      const CreditChannelActivityEvent(debitPool: 1),
      const CreditChannelActivityEvent(returnPool: 1),
    ]);
    reset.inject(1);
    debit.inject(0);
    creditReturn.inject(0);
    await clk.nextPosedge;
    reset.inject(0);
    debit.inject(activity.eventAt(0).debitVector(2));
    creditReturn.inject(activity.eventAt(0).returnVector(2));
    await clk.nextPosedge;
    debit.inject(activity.eventAt(1).debitVector(2));
    creditReturn.inject(activity.eventAt(1).returnVector(2));
    await clk.nextPosedge;
    debit.inject(activity.eventAt(2).debitVector(2));
    creditReturn.inject(activity.eventAt(2).returnVector(2));
    await clk.nextPosedge;

    expect(checker.sharedCredits, 1);
    expect(checker.violations, isEmpty);
    await Simulator.endSimulation();
  });

  test(
    'reprovisions credits when an additional reset source is asserted',
    () async {
      final clk = SimpleClockGenerator(10).clk;
      final reset = Logic();
      final remoteReset = Logic();
      final debit = Logic();
      final creditReturn = Logic();
      final checker = CreditChannelChecker(
        'checker',
        null,
        clk: clk,
        reset: reset,
        reinitializationResets: [remoteReset],
        debit: debit,
        creditReturn: creditReturn,
        configuration: CreditChannelCheckConfiguration.uniform(
          poolCount: 1,
          initialCredits: 1,
          maximumCredits: 1,
        ),
        reportViolations: false,
      );
      unawaited(checker.run(Phase()));
      unawaited(Simulator.run());

      reset.inject(1);
      remoteReset.inject(0);
      debit.inject(0);
      creditReturn.inject(0);
      await clk.nextPosedge;

      reset.inject(0);
      debit.inject(1);
      await clk.nextPosedge;
      debit.inject(0);
      expect(checker.credits, [0]);

      remoteReset.inject(1);
      await clk.nextPosedge;
      remoteReset.inject(0);
      expect(checker.credits, [1]);
      expect(checker.violations, isEmpty);
      await Simulator.endSimulation();
    },
  );

  test('generates reproducible valid multi-pool activity', () {
    final first = CreditChannelActivity.seededRandom(
      seed: 71,
      poolCount: 3,
      activeProbability: 0.75,
    );
    final second = CreditChannelActivity.seededRandom(
      seed: 71,
      poolCount: 3,
      activeProbability: 0.75,
    );

    for (var cycle = 0; cycle < 16; cycle++) {
      final firstEvent = first.eventAt(cycle);
      final secondEvent = second.eventAt(cycle);
      expect(firstEvent.debitVector(3), secondEvent.debitVector(3));
      expect(firstEvent.returnVector(3), secondEvent.returnVector(3));
    }
  });
}
