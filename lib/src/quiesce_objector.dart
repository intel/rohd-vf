// Copyright (C) 2021 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// quiesce_objector.dart
// A driver that keeps a queue of pending packets
//
// 2023 June 8
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:async/async.dart';
import 'package:rohd_vf/rohd_vf.dart';

class QuiesceObjector extends Component {
  /// The main [Objection] for this objector.
  Objection? _objection;

  final Future<void> Function()? timeout;
  final Future<void> Function()? dropDelay;

  /// A function which returns true if there's something worth objecting about.
  final bool Function() isActive;

  final Phase phase;

  ///TODO
  QuiesceObjector(
    this.isActive, {
    required this.phase,
    required Component parent,
    String name = 'quiesceObjector',
    this.timeout,
    this.dropDelay,
  }) : super(name, parent);

  CancelableOperation<void>? _pendingDrop;

  /// Considers whether or not the objection should be dropped.
  ///
  /// This should generally be called either every time a state may have changed
  /// that would impact the result of [isActive].
  void consider() {
    if (isActive()) {
      if (_objection == null) {
        raiseObjection();
        logger.finest('Raised objection due to activity.');
      }
    } else {
      dropObjection();
    }
  }

  /// Drop the objection, pending a [dropDelay] if it is provided.
  void dropObjection() {
    if (dropDelay != null) {
      // ignore: discarded_futures
      _pendingDrop?.cancel();
      logger.finest(
          'Planning to drop objection after delay if nothing stops it.');
      // ignore: discarded_futures
      _pendingDrop = CancelableOperation<void>.fromFuture(dropDelay!(),
          onCancel: () => logger.finest('Cancelling objection drop.'));
      _pendingDrop!.then((value) {
        _objection?.drop();
      });
    } else {
      _objection?.drop();
    }
  }

  /// Raise the objection, if it does not exist already.
  ///
  /// Will time out pending [timeout], if it is provided.
  void raiseObjection() {
    // ignore: discarded_futures
    _pendingDrop?.cancel();
    _pendingDrop = null;

    _objection ??= phase.raiseObjection('quiesce')
      // ignore: discarded_futures
      ..dropped.then((value) => logger.finest('Quiesce objection dropped'));
  }
}
