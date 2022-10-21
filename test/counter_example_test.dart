/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// counter_example_test.dart
/// Tests an example of a complete ROHD-VF testbench
///
/// 2021 October 20
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:test/test.dart';
import '../example/main.dart' as example;

void main() {
  tearDown(Simulator.reset);

  test('counter example test', () async {
    await example.main(loggerLevel: Level.OFF);
  });
}
