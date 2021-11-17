/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// sequencer.dart
/// Base sequencer for ROHD-VF
///
/// 2021 May 11
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'dart:async';
import 'package:rohd_vf/rohd_vf.dart';

/// A [Component] that consumes [Sequence]s and [SequenceItem]s and
/// properly forwards them to an output [stream] to be driven by
/// a [Driver].
///
/// If there is no special behavior required, using the default
/// implementation of [Sequencer] is perfectly functional and just
/// passes items directly through to the output [stream].
class Sequencer<SequenceItemType extends SequenceItem> extends Component {
  /// Constructs a basic [Sequencer] of [SequenceItemType] named [name]
  /// which passes items directly through without additional processing to [stream].
  Sequencer(String name, Component? parent) : super(name, parent);

  /// A controller for the output [stream] of this [Sequencer].
  final StreamController<SequenceItemType> _streamController =
      StreamController<SequenceItemType>();

  /// The output [Stream] of [SequenceItemType] from this [Sequencer], intended
  /// to be consumed by a [Driver].
  ///
  /// The [Stream] is single-subscription, and should be connected to exactly
  /// one [Driver].
  Stream<SequenceItemType> get stream => _streamController.stream;

  /// Returns true iff there is exactly one listener to [stream], which
  /// should be a [Driver].
  bool get isConnected => _streamController.hasListener;

  /// Adds a single [item] to this [Sequencer] to be passed on to
  /// the associated [Driver].
  ///
  /// If the sequencer should perform some operations before passing [item]
  /// along to the [Driver], this is a good method to override.  Calling
  /// `super.add(item)` from a subclass of [Sequencer] will finally pass
  /// [item] along to the [Driver].
  void add(SequenceItemType item) {
    if (isConnected) {
      _streamController.add(item);
    } else {
      throw Exception('No listener connected to sequencer');
    }
  }

  /// Starts running the [Sequence.body] on this [Sequencer].
  Future<void> start(Sequence sequence) async {
    await sequence.body(this);
  }
}
