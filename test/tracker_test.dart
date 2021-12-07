/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// tracker_test.dart
/// Test the tracker
///
/// 2021 December 6
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class FruitEvent implements Trackable {
  final LogicValues apple;
  final String banana;
  final int carrot;

  FruitEvent(this.apple, this.banana, this.carrot);

  @override
  String? trackerString(TrackerField field) {
    switch (field.title) {
      case 'Apple':
        return apple.toString();
      case 'Banana':
        return banana;
      case 'Carrot':
        return carrot.toString();
    }
    return null;
  }
}

void main() {
  test('tracker test', () {
    var tracker = Tracker(
      'testTracker',
      [
        TrackerField('Apple', 10),
        TrackerField('Banana', 5),
        TrackerField('Carrot', 12)
      ],
    );

    tracker.record(FruitEvent(LogicValues.fromString('1x0'), 'banana', 25));
    tracker.record(
        FruitEvent(LogicValues.fromString('1x01111000011010101'), 'aaa', 4));

    tracker.terminate();

    var jsonOutput = json.decode(File(tracker.jsonFileName).readAsStringSync());
    expect(jsonOutput['records'].length, equals(2));
    expect(jsonOutput['records'][0]['Banana'], equals('banana'));

    var logOutput = File(tracker.logFileName).readAsStringSync();
    expect(logOutput.contains('bana*'), equals(true));

    File(tracker.jsonFileName).deleteSync();
    File(tracker.logFileName).deleteSync();
  });
}
