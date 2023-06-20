// Copyright (C) 2021 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// quiesce_objector.dart
// An component that objects until quiescence.
//
// 2023 June 8
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:async/async.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// Maintains an [Objection] based on whether an entity [isActive], optionally
/// with [dropDelay] before dropping and a [timeout].
class QuiesceObjector extends Component {
  /// The main [Objection] for this objector.
  Objection? _objection;

  /// A function called each time there is activity being considered, and if
  /// it completes before an objection is dropped or there is further activity,
  /// then an error will be flagged.
  final Future<void> Function()? timeout;

  /// A function called each time an objection would drop due to lack of
  /// activity, but the objection will only be dropped if there is no further
  /// activity before it completes.
  final Future<void> Function()? dropDelay;

  /// A function which returns true if there's something worth objecting about.
  final bool Function() isActive;

  /// Pointer to the phase passed in by [run] for later.
  Phase? _runPhase;

  /// Constructs a new [QuiesceObjector] based on [isActive].
  ///
  /// If [timeout] is provided, then if there is no activity before it
  /// completes, then it will flag an error.
  ///
  /// If [dropDelay] is provided, then there will be a delay on dropping an
  /// objection until it completes.
  QuiesceObjector(
    this.isActive, {
    required Component parent,
    String name = 'quiesceObjector',
    this.timeout,
    this.dropDelay,
  }) : super(name, parent);

  /// An objection drop that is pending.
  CancelableOperation<void>? _pendingDrop;

  /// A timeout that is pending.
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

  /// Actually drop the objection, with whatever bookkeeping is required.
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
        // ignore: discarded_futures
        timeout!(),
        // onCancel: () => logger.finest('Timeout avoided!'),
      );
      _pendingTimeout!.then((_) => logger.severe('Objection has timed out!'));
    }
  }
}
