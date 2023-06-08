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

  /// Pointer to the phase passed in by [run] for later.
  Phase? _runPhase;

  ///TODO
  QuiesceObjector(
    this.isActive, {
    required Component parent,
    String name = 'quiesceObjector',
    this.timeout,
    this.dropDelay,
  }) : super(name, parent);

  CancelableOperation<void>? _pendingDrop;
  CancelableOperation<void>? _pendingTimeout;

  /// Considers whether or not the objection should be dropped.
  ///
  /// This should generally be called either every time a state may have changed
  /// that would impact the result of [isActive].
  void consider() {
    if (isActive()) {
      if (_objection == null) {
        logger.finest('Raised objection due to activity.');
      }
      raiseObjection();
    } else {
      dropObjection();
    }
  }

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));
    _runPhase = phase;
  }

  void _doDrop() {
    // ignore: discarded_futures
    _pendingTimeout?.cancel();
    _pendingTimeout = null;

    _objection?.drop();
    _objection = null;
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
      _pendingDrop!.then((_) => _doDrop());
    } else {
      _doDrop();
    }
  }

  /// Raise the objection, if it does not exist already.
  ///
  /// Will time out pending [timeout], if it is provided.
  void raiseObjection() {
    if (_runPhase == null) {
      throw Exception('Cannot raise exception before run phase.');
    }

    // ignore: discarded_futures
    _pendingDrop?.cancel();
    _pendingDrop = null;

    _objection ??= _runPhase!.raiseObjection('quiesce')
      // ignore: discarded_futures
      ..dropped.then((value) => logger.finest('Quiesce objection dropped'));

    if (timeout != null) {
      // ignore: discarded_futures
      _pendingTimeout?.cancel();
      // ignore: discarded_futures
      _pendingTimeout = CancelableOperation<void>.fromFuture(
        timeout!(),
        // onCancel: () => logger.finest('Timeout avoided!'),
      );
      _pendingTimeout!.then((_) => logger.severe('Objection has timed out!'));
    }
  }
}
