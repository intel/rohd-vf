// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ready_valid_channel_agent.dart
// Ready/valid agent compositions.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Composes a sequencer-backed provider for one ready/valid channel.
class ReadyValidChannelSourceAgent<LogicType extends Logic, ValueType>
    extends Agent {
  /// Sequencer that supplies channel items to the source driver.
  late final Sequencer<ReadyValidChannelItem<ValueType>> sequencer;

  /// Creates a ready/valid source agent.
  ReadyValidChannelSourceAgent(super.name, super.parent,
      {required Logic clk,
      required Logic reset,
      required Logic ready,
      required Logic valid,
      required LogicType data,
      required ReadyValidChannelCodec<LogicType, ValueType> codec,
      double blockRate = 0,
      ReadyValidChannelActivity? activity,
      int dropDelayCycles = 30}) {
    sequencer = Sequencer<ReadyValidChannelItem<ValueType>>('sequencer', this);
    ReadyValidChannelSourceDriver<LogicType, ValueType>('driver', this,
        clk: clk,
        reset: reset,
        ready: ready,
        valid: valid,
        data: data,
        codec: codec,
        sequencer: sequencer,
        blockRate: blockRate,
        activity: activity,
        dropDelayCycles: dropDelayCycles);
  }
}

/// Composes a consumer-side backpressure driver for one ready/valid channel.
class ReadyValidChannelSinkAgent extends Agent {
  /// Creates a ready/valid sink agent.
  ReadyValidChannelSinkAgent(super.name, super.parent,
      {required Logic clk,
      required Logic reset,
      required Logic ready,
      double blockRate = 0,
      ReadyValidChannelActivity? activity}) {
    ReadyValidChannelSink('sink', this,
        clk: clk,
        reset: reset,
        ready: ready,
        blockRate: blockRate,
        activity: activity);
  }
}
