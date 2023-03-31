[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=426054568)

[![Tests](https://github.com/intel/rohd-vf/actions/workflows/general.yml/badge.svg?event=push)](https://github.com/intel/rohd-vf/actions/workflows/general.yml)
[![API Docs](https://img.shields.io/badge/API%20Docs-generated-success)](https://intel.github.io/rohd-vf/rohd_vf/rohd_vf-library.html)
[![Chat](https://img.shields.io/discord/1001179329411166267?label=Chat)](https://discord.gg/jubxF84yGw)
[![License](https://img.shields.io/badge/License-BSD--3-blue)](https://github.com/intel/rohd-vf/blob/main/LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](https://github.com/intel/rohd-vf/blob/main/CODE_OF_CONDUCT.md)

# ROHD Verification Framework

The ROHD Verification Framework (ROHD-VF) is a verification framework built upon the [Rapid Open Hardware Development (ROHD) framework](https://www.github.com/intel/rohd).  It enables testbench organization in a way similar to [UVM](https://www.accellera.org/images/downloads/standards/uvm/uvm_users_guide_1.1.pdf).  A key motivation behind it is that hardware testbenches are really just software, and verification engineers should be empowered to write them as great software.  The ROHD Verification Framework enables development of a testbench in a *modern* programming language, taking advantage of recent innovations in the software industry.

With ROHD and ROHD-VF, your testbench and hardware execute natively in Dart in a single fully-debuggable process.  There is no black-box vendor simulator to interact with, just execute your software.  You can leverage the cosimulation functionality of ROHD (see [ROHD Cosim](https://github.com/intel/rohd-cosim)) to build ROHD-VF testbenches for designs that include (or are entirely) written in other languages (e.g. SystemVerilog).

The ROHD Verification Framework does *not* implement exactly the same API as UVM.  Rather, it takes some key concepts that are useful for testbench design and omits features that are rarely used, present to work around language limitations in SystemVerilog, encourage outdated or overly opinionated design patterns, or otherwise don't add significant value.  **The ROHD Verification Framework eliminates the macros and boilerplate that are associated with UVM.**

The ROHD Verification Framework offers a simple, clean, and scalable methodology for developing testbenches with moderate to high complexity.  Verifying a very small and simple design may be easier with a "peek & poke" type methodology using  `Logic.value` and `Logic.inject` directly on the DUT interfaces.  A "peek & poke" methodology for a larger, more complex design is usually not a scalable approach.  The "startup cost" associated with building a full testbench with the ROHD Verification Framework is drastically lower than one might traditionally expect if they had experience with UVM in the past.

## Testbenches

A testbench is software used to interact with and test a device under test (DUT).  ROHD Verification Framework testbenches are organized in a modular and extenable way using simple base classes which have specific roles.  The diagram below shows what a typical testbench might look like.  More details about each of the objects in the testbench are described below.  This should look very familiar if you've used UVM.

![Testbench Diagram](https://github.com/intel/rohd-vf/raw/main/doc/rohdvfdiagram1.png)

### Example

Dive right in with a full [example testbench for a counter](https://github.com/intel/rohd-vf/raw/main/example/main.dart).  The example includes `Monitor`s, a `Driver`, a `Sequencer`, an `Agent`, an `Env`, a `Test`, the same DUT as the ROHD counter example, a `Sequence` with `SequenceItem`s, a scoreboard, and a main function to kick it all off, all in a single commented file.

### Constructing Objects

The ROHD Verification Framework does not come with a built-in "factory" (like UVM) for constructing `Component`s in the testbench.  Instead, objects can just be constructed like any other object.  It is a good idea to build a testbench with modularity and configurability in mind so that behavior can be easily changed depending on the desired test.  There is no restriction against using a factory design pattern to build a testbench if that's the right approach for a specific situation.  You also might be interested in using other approaches, such as dependency injection.  ROHD-VF doesn't push a strong opinion here.

### [`Phase`](https://intel.github.io/rohd-vf/rohd_vf/Phase-class.html)s

A lot of setup for the testbench can occur in the constructor of the object.  ROHD-VF comes with some phasing (similar to UVM) to help configure, connect, and run a testbench in coordinated steps.  Every `Component` goes through phases.

- The constructor
  - Clearly enumerate what is required to build the component as part of the constructor parameters.
  - Construct any sub-components.
- `void build()`
  - A function which gets called when the test is started, but before the `Simulator` is running.
- `Future<void> run(Phase phase)`
  - A time-consuming function which starts executing when the test and `Simulator` are running.
  - Use `phase` to create `Objection`s.
- `void check()`
  - A function that gets called at the end of the simulation, for checking the end state for correctness.

## `Component`s

A [`Component`](https://intel.github.io/rohd-vf/rohd_vf/Component-class.html) is an object which holds a fixed hierarchical position in the testbench.  The hierarchy is determined at construction time by passing information about each `Component`'s parent (null if no parent / top level).  All of the below classes extend `Component`.  You can build your testbench extending these subclasses of `Component` or directly extend `Component`.

### `Monitor`

A [`Monitor`](https://intel.github.io/rohd-vf/rohd_vf/Monitor-class.html) is responsible for watching an interface and reporting out interesting events onto an output stream.  This bridges the hardware world into an object that can be manipulated in the testbench.  Many things can listen to a `Monitor`, often logging or checking logic.

### `Driver`

A [`Driver`](https://intel.github.io/rohd-vf/rohd_vf/Driver-class.html) is responsible for converting a `SequenceItem` into signal transitions on a hardware interface.  The driver accepts incoming items from a `Sequencer`.

### `Sequencer`

A [`Sequencer`](https://intel.github.io/rohd-vf/rohd_vf/Sequencer-class.html) accepts `SequenceItem`s from stimulus sources (e.g. `Sequence`s) and determines how to pass them to the appropriate `Driver`(s).  The default behavior of a `Sequencer` is to directly pass them to the `Driver` immediately, but they can be more complex than that.

### `Agent`

The [`Agent`](https://intel.github.io/rohd-vf/rohd_vf/Agent-class.html) is a wrapper for related components, often which all look at a single interface or set of interfaces.  Typically, an `Agent` constructs some `Monitor`s, `Driver`s, and `Sequencer`s, and then connects them up appropriately to each other and interfaces.

### `Env`

The [`Env`](https://intel.github.io/rohd-vf/rohd_vf/Env-class.html) is a wrapper for a collection of related components, often each with their own hierarchy. `Env`s are usually composed of `Agent`s, scoreboards, configuration & coordination logic, other smaller `Env`s, etc.

### `Test`

A [`Test`](https://intel.github.io/rohd-vf/rohd_vf/Test-class.html) is like a top-level testing entity that contains the top testbench `Env` and kicks off `Sequence`s.  Only one `Test` should be running at a time.  The `Test` also contains a central `Random` object to be used for randomization in a reproducible way.

## Stimulus

Sending stimulus through the testbench to the device under test is done by passing `SequenceItem`s through a `Sequencer` to a `Driver`.

### `SequenceItem`

A [`SequenceItem`](https://intel.github.io/rohd-vf/rohd_vf/SequenceItem-class.html) represents a collection of information to transmit across an interface.  A typical use case would be an object representing a transaction to be driven over a standardized hardware interface.

### `Sequence`

A [`Sequence`](https://intel.github.io/rohd-vf/rohd_vf/Sequence-class.html) is a modular object which has instructions for how to send `SequenceItem`s to a `Sequencer`.  A typical use case would be sending a collection of `SequenceItem`s in a specific order.

## Virtual Sequencers & Sequences

It is possible to create a "virtual" `Sequencer` whose role is to distribute `Sequence`s or `SequenceItem`s to other sub-sequencers.  `Sequence`s that run on a "virtual" `Sequencer` are called "virtual" `Sequence`s.  There's no special support in ROHD-VF for these, but the standard `Sequencer` and `Sequence` objects can be easily used for this purpose.

## Logging

ROHD-VF uses the Dart [`logging`](https://pub.dev/packages/logging) package for all logging.  It comes with a variety of verbosity levels and excellent customizability.

The `Test` object contains settings for `killLevel` and `failLevel` which will, respectively, immediately end the test or cause a test failure when the simulation finishes running.  These levels are associated with the levels from the `logging` package.

To log a message from any ROHD-VF object or component, just use the inherited `logger` object.

### Logging with the `Tracker`

ROHD-VF comes with a flexible [`Tracker`](https://intel.github.io/rohd-vf/rohd_vf/Tracker-class.html) which enables pretty printing and convenient output files associated with arbitrary events (which implement [`Trackable`](https://intel.github.io/rohd-vf/rohd_vf/Trackable-class.html)) throughout your test.  `Tracker` currently supports a JSON output as well as an ASCII table output.  Check out the [tracker unit test](https://github.com/intel/rohd-vf/raw/main/test/tracker_test.dart) for an example of how to configure and use the `Tracker`.

----------------
2021 November 9  
Author: Max Korbel <<max.korbel@intel.com>>

Copyright (C) 2021-2023 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
