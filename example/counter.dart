// Copyright (C) 2021-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter.dart
// A simple counter module that can be tested in an example testbench
//
// 2021 May 11
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';

enum CounterDirection { inward, outward, misc }

/// A simple [Interface] for [Counter].
class CounterInterface extends Interface<CounterDirection> {
  Logic get en => port('en');
  Logic get reset => port('reset');
  Logic get val => port('val');
  Logic get clk => port('clk');

  final int width;
  CounterInterface({this.width = 8}) {
    setPorts(
        [Logic.port('en'), Logic.port('reset')], [CounterDirection.inward]);

    setPorts([
      Logic.port('val', width),
    ], [
      CounterDirection.outward
    ]);

    setPorts([Logic.port('clk')], [CounterDirection.misc]);
  }

  @override
  CounterInterface clone() => CounterInterface(width: width);
}

/// A simple counter which increments once per `clk` edge whenever
/// `en` is high, and `reset`s to 0, with output `val`.
class Counter extends Module {
  late final CounterInterface intf;

  Counter(CounterInterface intf) : super(name: 'counter') {
    this.intf = CounterInterface(width: intf.width)
      ..connectIO(this, intf,
          inputTags: {CounterDirection.inward, CounterDirection.misc},
          outputTags: {CounterDirection.outward});

    _buildLogic();
  }

  void _buildLogic() {
    final nextVal = Logic(name: 'nextVal', width: intf.width);

    nextVal <= intf.val + 1;

    Sequential(intf.clk, reset: intf.reset, [
      If(intf.en, then: [intf.val < nextVal])
    ]);
  }
}
