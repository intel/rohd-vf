// Copyright (C) 2021 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pending_driver.dart
// A driver that keeps a queue of pending packets
//
// 2023 June 8
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:collection';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A special version of [ListQueue] that considers whether an [Objection]
/// should be raised on [phase] each time something is added or removed.
class _PendingQueue<E> extends ListQueue<E> {
  final Phase phase;
  final Logger logger;

  final Future<void> Function()? timeout;
  final Future<void> Function()? dropDelay;

  _PendingQueue({
    required this.phase,
    required this.logger,
    required this.timeout,
    required this.dropDelay,
  });

  Objection? _pendingObjection;

  CancelableOperation<void>? pendingDrop;

  void dropObjection() {
    if (dropDelay != null) {
      // ignore: discarded_futures
      pendingDrop?.cancel();
      logger.finest(
          'Planning to drop objection after delay if nothing stops it.');
      // ignore: discarded_futures
      pendingDrop = CancelableOperation<void>.fromFuture(dropDelay!(),
          onCancel: () => logger.finest('Cancelling objection drop.'));
      pendingDrop!.then((value) {
        _pendingObjection?.drop();
      });
    } else {
      _pendingObjection?.drop();
    }
  }

  void raiseObjection() {
    // ignore: discarded_futures
    pendingDrop?.cancel();
    pendingDrop = null;

    _pendingObjection ??= phase.raiseObjection('pendingItems')
      // ignore: discarded_futures
      ..dropped.then((value) => logger.finest('Pending objection dropped'));
  }

  void _reconsiderObjection() {
    if (isNotEmpty) {
      if (_pendingObjection == null) {
        raiseObjection();
        logger.finest('Raised objection due to pending items.');
      }
    } else {
      dropObjection();
    }
  }

  @override
  void add(E value) {
    super.add(value);
    _reconsiderObjection();
  }

  @override
  void addAll(Iterable<E> iterable) {
    super.addAll(iterable);
    _reconsiderObjection();
  }

  @override
  void addFirst(E value) {
    super.addFirst(value);
    _reconsiderObjection();
  }

  @override
  void addLast(E value) {
    super.addLast(value);
    _reconsiderObjection();
  }

  @override
  void clear() {
    super.clear();
    _reconsiderObjection();
  }

  @override
  bool remove(Object? value) {
    final res = super.remove(value);
    _reconsiderObjection();
    return res;
  }

  @override
  E removeFirst() {
    final res = super.removeFirst();
    _reconsiderObjection();
    return res;
  }

  @override
  E removeLast() {
    final res = super.removeLast();
    _reconsiderObjection();
    return res;
  }

  @override
  void removeWhere(bool Function(E element) test) {
    super.removeWhere(test);
    _reconsiderObjection();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    super.retainWhere(test);
    _reconsiderObjection();
  }
}

/// A special type of [Driver] which automatically pulls items out of
/// the [sequencer] and into a queue of [pendingSeqItems].
///
/// It also handles raising objections while there are pending items
/// and ensuring that the queue is empty at the end of the test.
abstract class PendingDriver<SequenceItemType extends SequenceItem>
    extends Driver<SequenceItemType> {
  /// A [Queue] of items that have been received from the sequencer and are
  /// waiting to be driven.  After an item has been driven, it should be
  /// removed.
  ///
  /// This can only be access during the [run] [Phase].
  ///
  /// The [PendingDriver] will raise an [Objection] until the queue is empty.
  ///
  /// If the test ends and this is not empty, a `SEVERE` will be raised.
  late final Queue<SequenceItemType> pendingSeqItems;

  final Future<void> Function()? timeout;
  final Future<void> Function()? dropDelay;

  /// Creates a new [PendingDriver] attached to [sequencer].
  PendingDriver(super.name, super.parent,
      {required super.sequencer, this.timeout, this.dropDelay});

  @override
  @mustCallSuper
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    pendingSeqItems = _PendingQueue<SequenceItemType>(
      phase: phase,
      logger: logger,
      timeout: timeout,
      dropDelay: dropDelay,
    );

    sequencer.stream.listen(pendingSeqItems.add);
  }

  @override
  void check() {
    if (pendingSeqItems.isNotEmpty) {
      logger
          .severe('At end of test, there were still pending packets to send.');

      for (final seqItem in pendingSeqItems) {
        logger.finer('Pending item: $seqItem');
      }
    }
  }
}
