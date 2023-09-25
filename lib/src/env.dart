// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// env.dart
// Base environment for ROHD-VF
//
// 2021 May 11
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd_vf/rohd_vf.dart';

/// A high level encapsulation of related functionality.
///
/// An [Env] could contain one or more agents, configuration objects,
/// checkers, scoreboards, coordination, interfaces, etc.
abstract class Env extends Component {
  /// Constructs an [Env] named [name] with parent [parent].
  Env(super.name, super.parent);
}
