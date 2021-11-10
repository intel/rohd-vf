/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// rohdvf_object.dart
/// Base definition of objects for ROHD-VF
/// 
/// 2021 May 11
/// Author: Max Korbel <max.korbel@intel.com>
/// 

import 'package:logging/logging.dart';

/// A base class from which all ROHD-VF objects can inherit to acquire some 
/// shared functionality.
abstract class ROHDVFObject {

  /// A [Logger] for messages related to the test or testbench.
  late final Logger logger = Logger(fullName());

  /// A descriptive name representing this instance of the object.
  String fullName();
}