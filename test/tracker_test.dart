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
  final LogicValue apple;
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
      case 'Durian':
        return (carrot * 2).toRadixString(16);
    }
    return null;
  }
}

void main() {
  test('tracker test', () async {
    var tracker = Tracker(
      'testTracker',
      [
        TrackerField('Apple', 10),
        TrackerField('Banana', 5),
        TrackerField('Carrot', 12, justify: Justify.center),
        TrackerField('Durian', 12, mapOnly: true)
      ],
    );

    tracker.record(FruitEvent(LogicValue.ofString('1x0'), 'banana', 25));
    tracker.record(
        FruitEvent(LogicValue.ofString('1x01111000011010101'), 'aaa', 5));

    // Expect JSON log to look like:
    // {"records":[
    //   {"Apple": "3'b1x0", "Banana": "banana", "Carrot": "25", "Durian": "32"}
    // , {"Apple": "19'b1x01111000011010101", "Banana": "aaa", "Carrot": "4", "Durian": "8"}
    // ]}

    await tracker.terminate();

    var jsonOutput = json.decode(File(tracker.jsonFileName).readAsStringSync());
    expect(jsonOutput['records'].length, equals(2));
    expect(jsonOutput['records'][0]['Banana'], equals('banana'));
    expect(jsonOutput['records'][1]['Durian'], equals('a'));

    // Expect table log to look like:
    // ---------------------------------------
    //  | A          | B     | C            |
    //  | P          | A     | A            |
    //  | P          | N     | R            |
    //  | L          | A     | R            |
    //  | E          | N     | O            |
    //  |            | A     | T            |
    // ---------------------------------------
    //  |     3'b1x0 | bana* |      25      | {Apple: 3'b1x0, Banana: banana, Carrot: 25, Durian: 32}
    //  | 19'b1x011* |   aaa |      5       | {Apple: 19'b1x01111000011010101, Banana: aaa, Carrot: 5, Durian: a}

    var logOutput = File(tracker.tableFileName).readAsStringSync();
    expect(logOutput.contains('bana*'), equals(true));
    expect(logOutput.split('\n')[1].split('|').length, equals(5));

    File(tracker.jsonFileName).deleteSync();
    File(tracker.tableFileName).deleteSync();
  });
}
