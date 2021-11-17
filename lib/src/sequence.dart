/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// sequence.dart
/// Base sequence for ROHD-VF
///
/// 2021 May 11
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd_vf/rohd_vf.dart';

/// A collection of operations to execute on a [Sequencer].
///
/// [Sequence]s are a mechanism that enabled modular reuse of
/// a sequence of [SequenceItem]s on a given type of [Sequencer],
/// parameterized by [SequencerType].
abstract class Sequence<SequencerType extends Sequencer> extends ROHDVFObject {
  /// The name of this instance of this [Sequence].
  ///
  /// Useful for logging and debug purposes.
  final String name;

  /// Constructs a new [Sequence] named [name].
  Sequence(this.name) : super();

  @override
  String fullName() => name;

  /// Operations to perform on [sequencer], usually
  /// adding new [SequenceItem]s to [sequencer].
  Future<void> body(SequencerType sequencer);
}
