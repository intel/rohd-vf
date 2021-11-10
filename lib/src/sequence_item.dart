/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// sequence_item.dart
/// Base SequenceItem for ROHD-VF
/// 
/// 2021 May 11
/// Author: Max Korbel <max.korbel@intel.com>
/// 

import 'package:rohd_vf/rohd_vf.dart';

/// A single item that a [Driver] would parse to be driven.
abstract class SequenceItem extends ROHDVFObject {

  @override
  String fullName() => runtimeType.toString();
}