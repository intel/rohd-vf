// Copyright (C) 2021-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// test.dart
// Base Test for ROHD-VF
//
// 2021 May 11
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// The top level object for an ROHD-VF test.
///
/// The [Test] contains references to the environment and
/// the device under test (DUT), and also is responsible for
/// kicking off sequences on appropriate sequencers.
///
/// Only one [Test] should be created per simulation run.
abstract class Test extends Component {
  /// A central static [Random] object that should be used any
  /// time randomization is required in this test.
  ///
  /// When the main [Test] starts, it will select a random seed
  /// which can be manually overriden.  If all random behavior in
  /// the test derives from [random] object, then tests can be
  /// reproduced by setting the same seed again.
  static Random get random => instance._random;

  /// The minimum level that should immediately kill the test.
  ///
  /// This level should be greater than or equal to [failLevel].
  Level killLevel = Level.SHOUT;

  /// The minimum level that should cause the test to fail after completing.
  ///
  /// A failed test will continue to run, then throw an Exception.  This level
  /// should be less than or equal to [killLevel].
  Level failLevel = Level.SEVERE;

  /// Stores whether a failure has been detected in this test.
  ///
  /// By default, this automatically gets set to true when the
  /// logging level exceeding [failLevel].  If this is true
  /// at the end of the test, the execution will fail with an
  /// [Exception].
  bool failureDetected = false;

  /// The singleton Test for this simulation.
  static late Test instance;

  /// The [Random] object for this [Test].
  final Random _random;

  /// The minimum [Level] which should be printed out to `stdout`.
  ///
  /// Note that this is independent of the [Logger]'s level, which
  /// controls whether the [Test] receives messages at all.  If the
  /// [Logger]'s level is above [killLevel] and/or [failLevel], then
  /// the [Test] will not fail when those messages are emitted.
  Level printLevel;

  /// Constructs a new [Test] named [name].
  ///
  /// Only one [Test] should be created per simulation.  It will set
  /// the value of [random] to a new [Random] object with [randomSeed]
  /// as the seed.  If no [randomSeed] is specified, a random seed
  /// will be selected.  To rerun a test with the same randomized behavior,
  /// pass the same [randomSeed] as the previous run.
  Test(String name, {int? randomSeed, this.printLevel = Level.ALL})
      : _random = Random(randomSeed),
        super(name, null) {
    instance = this;
    configureLogger();
  }

  /// A handle to the subscription to the root [Logger], so that it
  /// can be cancelled at the end of the test.
  late final StreamSubscription<LogRecord> _loggerSubscription;

  /// Prints a message to `stdout`, guarded by the [printLevel].
  void _testPrint(String message, Level messageLevel) {
    if (messageLevel >= printLevel) {
      // ignore: avoid_print
      print(message);
    }
  }

  /// Configures the root logger to provide information about
  /// log messages.
  ///
  /// By default, this `print`s information out to stdout.
  @protected
  void configureLogger() {
    _loggerSubscription = Logger.root.onRecord.listen((record) {
      _testPrint(
        '[${record.level.name}] @ ${Simulator.time}'
        ' | ${record.loggerName}: ${record.message}',
        record.level,
      );
      if (record.error != null) {
        _testPrint('> Error: ${record.error}', record.level);
      }
      if (record.stackTrace != null) {
        _testPrint('> Stack trace: \n${record.stackTrace}', record.level);
      }

      if (record.level >= killLevel) {
        failureDetected = true;

        _testPrint('Killing test due to detected failure.', record.level);

        Simulator.endSimulation();
      } else if (record.level >= failLevel) {
        if (!failureDetected) {
          _testPrint('Test failure detected, but continuing to run to end.',
              record.level);
        }
        failureDetected = true;
      }
    });
  }

  void _checkAll() {
    final checkQueue = Queue<Component>.of([this]);
    while (checkQueue.isNotEmpty) {
      final component = checkQueue.removeFirst();
      checkQueue.addAll(component.components);
      component.check();
    }
    if (failureDetected) {
      throw Exception('Test failed.');
    }
  }

  /// Starts the test on the [Simulator].
  ///
  /// It will kick off the run phase and continue to run until
  /// all objections have dropped.
  Future<void> start() async {
    build();
    final runPhase = Phase();
    unawaited(run(runPhase));
    if (!Simulator.hasStepsRemaining()) {
      logger.warning('Simulator has no registered events.');
    }
    logger.finest('Waiting for objections to finish...');

    await Future.any([
      Simulator.run(),
      runPhase.allObjectionsDropped(),
    ]);

    if (runPhase.objections.isNotEmpty) {
      logger
          .warning('Simulation has ended before all objections were dropped!');
    } else {
      logger.finest('Objections completed, ending simulation.');
      Simulator.endSimulation();
    }

    if (!Simulator.simulationHasEnded) {
      await Simulator.simulationEnded;
    }

    logger.finest('Running end of test checks.');
    _checkAll();

    logger.finest('Simulation ended, test complete.');

    await _loggerSubscription.cancel();
  }
}
