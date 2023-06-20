/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// driver.dart
/// Base driver for ROHD-VF
///
/// 2021 May 11
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd_vf/rohd_vf.dart';

/// A driver of stimulus to the DUT.
///
/// The parameterized [SequenceItemType] represents the type of [SequenceItem]
/// that this [Driver] will send over the interface.  [Driver]s should acquire
/// new [SequenceItem]s to drive via the [sequencer].
abstract class Driver<SequenceItemType extends SequenceItem> extends Component {
  /// The sequencer from which this [Driver] acquires new items to drive.
  ///
  /// [Driver] implementations should listen to [sequencer]'s
  /// [Sequencer.stream].
  /// For example:
  /// ```dart
  /// @override
  /// Future<void> run(Phase phase) async {
  ///   unawaited(super.run(phase));
  ///   sequencer.stream.listen((newItem) {
  ///     // some code that should operate on `newItem`
  ///   });
  /// }
  /// ```
  final Sequencer<SequenceItemType> sequencer;

  /// Constructs a [Driver] named [name] with parent [parent].
  ///
  /// The driver should receive [SequenceItem]s from [sequencer].
  Driver(super.name, super.parent, {required this.sequencer});
}
