// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_channel_activity_test.dart
// Tests for ready/valid channel activity policies.
//
// 2026 July 31
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd_vf/rohd_vf.dart';
import 'package:test/test.dart';

void main() {
  List<bool> values(ReadyValidChannelActivity activity, int count) =>
      List.generate(count, activity.isActive);

  test('activity policies are deterministic and validate their arguments', () {
    expect(values(ReadyValidChannelActivity.always(), 4),
        [true, true, true, true]);
    expect(values(ReadyValidChannelActivity.scripted([false, true]), 4),
        [false, true, false, false]);
    expect(values(ReadyValidChannelActivity.alternating(activeCycles: 2), 6),
        [true, true, false, true, true, false]);
    expect(
        values(
            ReadyValidChannelActivity.burst(
                startCycle: 2, length: 2, period: 5),
            8),
        [false, false, true, true, false, false, false, true]);

    final first = ReadyValidChannelActivity.seededRandom(
        seed: 42, activeProbability: 0.5);
    final second = ReadyValidChannelActivity.seededRandom(
        seed: 42, activeProbability: 0.5);
    expect(values(first, 12), values(second, 12));
    expect(() => ReadyValidChannelActivity.alternating(activeCycles: 0),
        throwsArgumentError);
  });
}
