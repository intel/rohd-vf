// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// waiter_test.dart
// Test the waiter
//
// 2023 September 25
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  late Logic clk;
  setUp(() {
    Simulator.setMaxSimTime(500);
    clk = SimpleClockGenerator(10).clk;
  });

  tearDown(() async {
    await Test.reset();
  });

  test('0 cycles is instant', () async {
    Simulator.registerAction(18, () async {
      await clk.waitCycles(0);
      expect(Simulator.time, 18);
    });

    unawaited(Simulator.run());

    await clk.waitCycles(0);

    expect(Simulator.time, 0);

    await Simulator.simulationEnded;
  });

  test('pos', () async {
    var checkHappened = false;

    Simulator.registerAction(18, () {
      // 25, 35, 45
      clk.waitCycles(3).then((value) {
        expect(Simulator.time, 45);
        checkHappened = true;
      });
    });

    unawaited(Simulator.run());

    await Simulator.simulationEnded;

    expect(checkHappened, isTrue);
  });

  test('neg', () async {
    var checkHappened = false;

    Simulator.registerAction(18, () {
      // 20, 30, 40
      clk.waitCycles(3, edge: Edge.neg).then((value) {
        expect(Simulator.time, 40);
        checkHappened = true;
      });
    });

    unawaited(Simulator.run());

    await Simulator.simulationEnded;

    expect(checkHappened, isTrue);
  });

  test('any', () async {
    var checkHappened = false;

    Simulator.registerAction(18, () {
      // 20, 25, 30
      clk.waitCycles(3, edge: Edge.any).then((value) {
        expect(Simulator.time, 30);
        checkHappened = true;
      });
    });

    unawaited(Simulator.run());

    await Simulator.simulationEnded;

    expect(checkHappened, isTrue);
  });
}
