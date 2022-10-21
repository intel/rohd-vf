/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// test_test.dart
/// Tests for `Test`
///
/// 2022 August 19
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class ForeverObjectionTest extends Test {
  ForeverObjectionTest() : super('foreverObjectionTest');

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

void main() {
  setUp(() {
    Logger.root.level = Level.OFF;
  });

  tearDown(Simulator.reset);

  test('Test does not wait for objections if simulation ends', () async {
    await ForeverObjectionTest().start();
  });

  test('Test.start does not complete until simulation ends', () async {
    await NormalTest().start();
    expect(Simulator.simulationHasEnded, isTrue);
  });
}
