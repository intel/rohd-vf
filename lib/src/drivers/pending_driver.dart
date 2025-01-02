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

  /// If `true`, will [check] at the end of the test that there are no pending
  /// items remaining to be driven.
  final bool enableEndOfTestEmptyCheck;

  /// Creates a new [PendingDriver] attached to [sequencer].
  PendingDriver(
    super.name,
    super.parent, {
    required super.sequencer,
    this.timeout,
    this.dropDelay,
    this.enableEndOfTestEmptyCheck = true,
  }) {
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
    if (pendingSeqItems.isNotEmpty && enableEndOfTestEmptyCheck) {
      logger.severe('At end of test, there were still pending items to send.');

      for (final seqItem in pendingSeqItems) {
        logger.finer('Pending item: $seqItem');
      }
    }
  }
}

/// A special version of [ListQueue] that uses a [QuiesceObjector].
class _PendingQueue<E> implements Queue<E> {
  final Component parent;

  final Future<void> Function()? timeout;
  final Future<void> Function()? dropDelay;

  late final QuiesceObjector _quiesceObjector;

  final ListQueue<E> _listQueue = ListQueue<E>();

  factory _PendingQueue(
          {required Component parent,
          required Future<void> Function()? timeout,
          required Future<void> Function()? dropDelay}) =>
      _PendingQueue._(
        parent: parent,
        timeout: timeout,
        dropDelay: dropDelay,
      );

  _PendingQueue._({
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
    _listQueue.add(value);
    _reconsiderObjection();
  }

  @override
  void addAll(Iterable<E> iterable) {
    _listQueue.addAll(iterable);
    _reconsiderObjection();
  }

  @override
  void addFirst(E value) {
    _listQueue.addFirst(value);
    _reconsiderObjection();
  }

  @override
  void addLast(E value) {
    _listQueue.addLast(value);
    _reconsiderObjection();
  }

  @override
  void clear() {
    _listQueue.clear();
    _reconsiderObjection();
  }

  @override
  bool remove(Object? value) {
    final res = _listQueue.remove(value);
    _reconsiderObjection();
    return res;
  }

  @override
  E removeFirst() {
    final res = _listQueue.removeFirst();
    _reconsiderObjection();
    return res;
  }

  @override
  E removeLast() {
    final res = _listQueue.removeLast();
    _reconsiderObjection();
    return res;
  }

  @override
  void removeWhere(bool Function(E element) test) {
    _listQueue.removeWhere(test);
    _reconsiderObjection();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    _listQueue.retainWhere(test);
    _reconsiderObjection();
  }

  @override
  bool any(bool Function(E element) test) => _listQueue.any(test);

  @override
  Queue<R> cast<R>() => _listQueue.cast<R>();

  @override
  bool contains(Object? element) => _listQueue.contains(element);

  @override
  E elementAt(int index) => _listQueue.elementAt(index);

  @override
  bool every(bool Function(E element) test) => _listQueue.every(test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      _listQueue.expand(toElements);

  @override
  E get first => _listQueue.first;

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      _listQueue.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      _listQueue.fold(initialValue, combine);

  @override
  Iterable<E> followedBy(Iterable<E> other) => _listQueue.followedBy(other);

  @override
  void forEach(void Function(E element) action) => _listQueue.forEach(action);

  @override
  bool get isEmpty => _listQueue.isEmpty;

  @override
  bool get isNotEmpty => _listQueue.isNotEmpty;

  @override
  Iterator<E> get iterator => _listQueue.iterator;

  @override
  String join([String separator = '']) => _listQueue.join(separator);

  @override
  E get last => _listQueue.last;

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      _listQueue.lastWhere(test, orElse: orElse);

  @override
  int get length => _listQueue.length;

  @override
  Iterable<T> map<T>(T Function(E e) toElement) => _listQueue.map(toElement);

  @override
  E reduce(E Function(E value, E element) combine) =>
      _listQueue.reduce(combine);

  @override
  E get single => _listQueue.single;

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      _listQueue.singleWhere(test, orElse: orElse);

  @override
  Iterable<E> skip(int count) => _listQueue.skip(count);

  @override
  Iterable<E> skipWhile(bool Function(E value) test) =>
      _listQueue.skipWhile(test);

  @override
  Iterable<E> take(int count) => _listQueue.take(count);

  @override
  Iterable<E> takeWhile(bool Function(E value) test) =>
      _listQueue.takeWhile(test);

  @override
  List<E> toList({bool growable = true}) =>
      _listQueue.toList(growable: growable);

  @override
  Set<E> toSet() => _listQueue.toSet();

  @override
  Iterable<E> where(bool Function(E element) test) => _listQueue.where(test);

  @override
  Iterable<T> whereType<T>() => _listQueue.whereType<T>();
}
