---
title: "Drivers"
permalink: /docs/driver/
last_modified_at: 2022-6-8
toc: true
---

A [`Driver`](https://intel.github.io/rohd-vf/rohd_vf/Driver-class.html) is responsible for converting a `SequenceItem` into signal transitions on a hardware interface.  The driver accepts incoming items from a `Sequencer`.

## Pending Driver

A `PendingDriver` is a flavor of `Driver` that takes care of some bookkeeping automatically for you:

- Automatically pulls items from the `sequencer` into a queue `pendingSeqItems`.
- Maintains an objection, including with drop delays and timeouts (via a `QuiesceObjector`) based on the occupancy of the queue.
- Checks that the queue is empty at the end of the test.

### Pending Clocked Driver

Because it is common to want to wait for a certain number of cycles of a clock, the `PendingClockedDriver` offers a way to wait for a number of cycles using the `waitCycles` function automatically.