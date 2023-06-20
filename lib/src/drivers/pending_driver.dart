// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pending_driver.dart
// A driver that keeps a queue of pending items
//
// 2023 June 8
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:rohd_vf/rohd_vf.dart';

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

  /// A function called each time there is something added or removed from the
  /// [pendingSeqItems], and if it completes before an objection is dropped or
  /// some further activity occurs, an error is flagged.
  final Future<void> Function()? timeout;

  /// A function called each time an objection would drop due to an empty
  /// [pendingSeqItems], but the objection will only be dropped if there is no
  /// further activity before it completes.
  final Future<void> Function()? dropDelay;

  /// Creates a new [PendingDriver] attached to [sequencer].
  PendingDriver(super.name, super.parent,
      {required super.sequencer, this.timeout, this.dropDelay}) {
    pendingSeqItems = _PendingQueue<SequenceItemType>(
      parent: this,
      timeout: timeout,
      dropDelay: dropDelay,
    );
  }

  @override
  @mustCallSuper
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    sequencer.stream.listen((item) {
      logger.finest('Added item to pending queue: $item');
      pendingSeqItems.add(item);
    });
  }

  @override
  void check() {
    if (pendingSeqItems.isNotEmpty) {
      logger.severe('At end of test, there were still pending items to send.');

      for (final seqItem in pendingSeqItems) {
        logger.finer('Pending item: $seqItem');
      }
    }
  }
}

/// A special version of [ListQueue] that uses a [QuiesceObjector].
class _PendingQueue<E> extends ListQueue<E> {
  final Component parent;

  final Future<void> Function()? timeout;
  final Future<void> Function()? dropDelay;

  late final QuiesceObjector _quiesceObjector;

  _PendingQueue({
    required this.parent,
    required this.timeout,
    required this.dropDelay,
  }) {
    _quiesceObjector = QuiesceObjector(() => isNotEmpty,
        timeout: timeout,
        dropDelay: dropDelay,
        parent: parent,
        name: 'pendingQueueQuiesce');
  }

  void _reconsiderObjection() {
    _quiesceObjector.consider();
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
