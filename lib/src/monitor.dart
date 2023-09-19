// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// monitor.dart
// Base monitor for ROHD-VF
//
// 2021 July 13
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'package:meta/meta.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A [Component] that monitors an interface and reports
/// interesting events as items to listeners.
abstract class Monitor<MonitorItem> extends Component {
  /// A controller for the main output [stream] of this [Monitor].
  final StreamController<MonitorItem> _streamController =
      StreamController<MonitorItem>.broadcast(sync: true);

  /// A [Stream] of items that this [Monitor] has detected and shared with
  /// listeners.
  ///
  /// The stream is a broadcast stream, meaning it can have many listeners, and
  /// if nobody is listening the events will just be dropped.  The stream will
  /// not catch up any late listeners who missed earlier events.
  Stream<MonitorItem> get stream => _streamController.stream;

  /// Constructs a [Monitor] named [name] with parent [parent].
  Monitor(super.name, super.parent);

  /// Sends [item] out on [stream] to all listeners.
  @protected
  void add(MonitorItem item) {
    _streamController.add(item);
  }
}
