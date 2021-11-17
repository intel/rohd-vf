/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// agent.dart
/// ROHD-VF agent, contains things like monitors and drivers
///
/// 2021 May 11
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd_vf/rohd_vf.dart';

/// An agent for encapsulating related functionality on an interface,
/// often a [Driver], [Sequencer], and a [Monitor].
abstract class Agent extends Component {
  Agent(String name, Component? parent) : super(name, parent);
}
