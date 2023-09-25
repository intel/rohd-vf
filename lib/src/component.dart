// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// component.dart
// Base class for ROHD-VF component, all components should derive from this
//
// 2021 May 11
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:collection';
import 'package:meta/meta.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// The base class for any component in ROHD-VF.
///
/// A [Component] is an object that has a static position in the
/// hierarchy of the testbench.  [Component]s are constructed
/// before the test starts running and stay in place throughout
/// the duration of the test.
abstract class Component extends ROHDVFObject {
  /// A name for this instance of the [Component].
  ///
  /// Strive to make this name unique.
  final String name;

  /// The [Component] which constructed and contains this [Component].
  ///
  /// This information is used to determine the testbench hierarchy.  If
  /// there is no parent (e.g. this is the top level [Component]), then the
  /// [parent] is `null`.
  final Component? parent;

  /// A [List] of all children [Component]s.
  UnmodifiableListView<Component> get components =>
      UnmodifiableListView(_components);
  final List<Component> _components = [];

  /// Constructs an instance of this [Component] named [name] and with
  /// parent [parent].
  Component(this.name, this.parent) {
    parent?._components.add(this);
  }

  /// Returns a [List] of [Component]s representing the full hierarchy
  /// of this [Component], with the top-most parent at index 0 and this
  /// as the last element of the [List].
  List<Component> hierarchy() =>
      (parent == null ? <Component>[] : parent!.hierarchy())..add(this);

  /// A descriptive name including the full hierarchical path of
  /// this [Component].
  @override
  String fullName() => hierarchy().map((e) => e.name).join('.');

  /// Performs additional build-related activities required before [run].
  @mustCallSuper
  void build() {
    for (final component in _components) {
      component.build();
    }
  }

  /// Executes this [Component]'s activities related to running the test.
  ///
  /// Overrides of [run] must call `super.run` in an `unawaited` fashion.
  /// For example:
  /// ```dart
  /// @override
  /// Future<void> run(Phase phase) async {
  ///   unawaited(super.run(phase));
  ///   // New code goes here!
  /// }
  /// ```
  @mustCallSuper
  Future<void> run(Phase phase) async {
    for (final component in _components) {
      unawaited(component.run(phase));
    }
  }

  /// Performs additional checks at the end of the simulation.
  ///
  /// This is a good place to search for any incomplete flows or
  /// compare final states with expected states.
  void check() {
    // By default, nothing to do here!
  }
}
