/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// tracker_test.dart
/// Test the tracker
///
/// 2021 December 6
/// Author: Max Korbel <max.korbel@intel.com>
///

// ignore_for_file: lines_longer_than_80_chars, avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

class FruitEvent implements Trackable {
  final LogicValue apple;
  final String banana;
  final int carrot;
  final String? pear;

  FruitEvent(this.apple, this.banana, this.carrot, this.pear);

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
      case 'Pear':
        return pear;
    }
    return null;
  }
}

void main() {
  test('tracker test', () async {
    final tracker = Tracker(
      'testTracker',
      [
        const TrackerField('Apple', columnWidth: 10),
        const TrackerField('Banana', columnWidth: 5),
        const TrackerField('Carrot', columnWidth: 12, justify: Justify.center),
        const TrackerField('Durian', columnWidth: 12, mapOnly: true),
        const TrackerField('Pear', columnWidth: 12)
      ],
    )
      ..record(
          FruitEvent(LogicValue.ofString('1x0'), 'banana', 25, 'green pear'),
          defaults: {'Pear': 'red pear'})
      ..record(
          FruitEvent(
              LogicValue.ofString('1x01111000011010101'), 'aaa', 5, null),
          defaults: {'Pear': 'red pear'});

    // Expect JSON log to look like:
    // {"records":[
    //   {"Apple": "3'b1x0", "Banana": "banana", "Carrot": "25", "Durian": "32", "Pear": "green pear"}
    // , {"Apple": "19'b1x01111000011010101", "Banana": "aaa", "Carrot": "4", "Durian": "8", "Pear": "red pear"}
    // ]}

    await tracker.terminate();

    final jsonOutput =
        json.decode(File(tracker.jsonFileName).readAsStringSync());
    expect(jsonOutput['records'].length, equals(2));
    expect(jsonOutput['records'][0]['Banana'], equals('banana'));
    expect(jsonOutput['records'][1]['Durian'], equals('a'));
    expect(jsonOutput['records'][0]['Pear'], equals('green pear'));
    expect(jsonOutput['records'][1]['Pear'], equals('red pear'));

    // Expect table log to look like:
// ------------------------------------------------------
//  | A          | B     | C            | P            |
//  | P          | A     | A            | E            |
//  | P          | N     | R            | A            |
//  | L          | A     | R            | R            |
//  | E          | N     | O            |              |
//  |            | A     | T            |              |
// ------------------------------------------------------
//  |     3'b1x0 | bana* |      25      |   green pear | {Apple: 3'b1x0, Banana: banana, Carrot: 25, Durian: 32, Pear: green pear}
//  | 19'b1x011* |   aaa |      5       |     red pear | {Apple: 19'b1x01111000011010101, Banana: aaa, Carrot: 5, Durian: a, Pear: red pear}

    final logOutput = File(tracker.tableFileName).readAsStringSync();
    expect(logOutput.contains('bana*'), equals(true));
    expect(logOutput.split('\n')[1].split('|').length, equals(6));

    File(tracker.jsonFileName).deleteSync();
    File(tracker.tableFileName).deleteSync();
  });
}
