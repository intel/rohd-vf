// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// test_test.dart
// Tests for `Test`
//
// 2022 August 19
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class ForeverObjectionTest extends Test {
  ForeverObjectionTest() : super('foreverObjectionTest', printLevel: Level.OFF);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    phase.raiseObjection('objectionNeverCloses');
    SimpleClockGenerator(10);
    Simulator.registerAction(100, Simulator.endSimulation);
  }
}

class NormalTest extends Test {
  NormalTest() : super('normalTest');
  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    final obj = phase.raiseObjection('obj');
    SimpleClockGenerator(10);
    Simulator.registerAction(100, obj.drop);
  }
}

class LogTypeTest extends Test {
  final Level errorLevel;

  bool testCompleted = false;

  final Logic _clk = SimpleClockGenerator(10).clk;

  LogTypeTest(this.errorLevel) : super('logTypeTest', printLevel: Level.OFF) {
    Simulator.setMaxSimTime(500);
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    final obj = phase.raiseObjection();

    await _clk.nextPosedge;

    logger.log(errorLevel, 'error message');

    await _clk.nextPosedge;

    testCompleted = true;

    obj.drop();
  }
}

class CheckPhaseFailureTest extends Test {
  CheckPhaseFailureTest()
      : super('checkPhaseFailureTest', printLevel: Level.OFF) {
    FailingSubComponent(this);
  }
}

class FailingSubComponent extends Component {
  FailingSubComponent(Component parent) : super('failingSubComponent', parent);

  @override
  void check() {
    logger.severe('Failure during check');
  }
}

class CheckPhaseCalledOnceTest extends Test {
  CheckPhaseCalledOnceTest()
      : super('checkPhaseCalledOnceTest', printLevel: Level.OFF) {
    CheckPhaseFailingSubComponent(this);
  }
}

class CheckPhaseFailingSubComponent extends Component {
  int checkPhaseCount = 0;

  CheckPhaseFailingSubComponent(Component parent)
      : super('checkPhaseFailingSubComponent', parent);

  @override
  void check() {
    checkPhaseCount += 1;
    if (checkPhaseCount > 1) {
      logger.severe('Check Phase called $checkPhaseCount times');
    }
  }
}

void main() {
  setUp(() {
    Logger.root.level = Level.WARNING;
  });

  tearDown(Simulator.reset);

  test('Test does not wait for objections if simulation ends', () async {
    await ForeverObjectionTest().start();
  });

  test('Test.start does not complete until simulation ends', () async {
    await NormalTest().start();
    expect(Simulator.simulationHasEnded, isTrue);
  });

  test('Logger failure causes exception at end of test', () async {
    var sawError = false;
    final logTest = LogTypeTest(Level.SEVERE);

    try {
      await logTest.start();
    } on Exception {
      sawError = true;
    }

    expect(sawError, isTrue);
    expect(logTest.testCompleted, isTrue);
  });

  test('Logger kill causes exception immediately', () async {
    var sawError = false;
    final logTest = LogTypeTest(Level.SHOUT);

    try {
      await logTest.start();
    } on Exception {
      sawError = true;
    }

    expect(sawError, isTrue);
    expect(logTest.testCompleted, isFalse);
  });

  test('Logger normal message passes', () async {
    await LogTypeTest(Level.WARNING).start();
  });

  test('Failure during check causes test failure', () async {
    var sawError = false;

    try {
      await CheckPhaseFailureTest().start();
    } on Exception {
      sawError = true;
    }

    expect(sawError, isTrue);
  });

  test('Check is only called once on components directly under Test', () async {
    var sawError = false;

    try {
      await CheckPhaseCalledOnceTest().start();
    } on Exception {
      sawError = true;
    }

    expect(sawError, isFalse);
  });
}
