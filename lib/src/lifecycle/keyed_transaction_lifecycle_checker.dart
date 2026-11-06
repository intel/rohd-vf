// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// keyed_transaction_lifecycle_checker.dart
// Protocol-neutral keyed request and response lifecycle verification.
//
// 2026 October 26
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:meta/meta.dart';

/// Immutable composite key for transactions scoped by a namespace.
///
/// A namespace can identify an ingress interface, requester, partition, or
/// any other caller-defined ownership domain. It allows the same local key to
/// be outstanding independently in distinct domains.
@immutable
class TransactionNamespaceKey<NamespaceType, LocalKeyType> {
  /// Caller-defined ownership namespace.
  final NamespaceType namespace;

  /// Key local to [namespace].
  final LocalKeyType localKey;

  /// Creates a composite transaction key.
  const TransactionNamespaceKey(this.namespace, this.localKey);

  @override
  bool operator ==(Object other) =>
      other is TransactionNamespaceKey<NamespaceType, LocalKeyType> &&
      namespace == other.namespace &&
      localKey == other.localKey;

  @override
  int get hashCode => Object.hash(namespace, localKey);

  @override
  String toString() => '($namespace, $localKey)';
}

/// One failure observed by [KeyedTransactionLifecycleChecker].
class TransactionLifecycleFailure<KeyType, ResourceType> {
  /// Stable rule identifier.
  final String id;

  /// Cycle supplied by the test at observation time.
  final int cycle;

  /// Transaction key associated with the failure, when available.
  final KeyType? key;

  /// Resource associated with the failure, when available.
  final ResourceType? resource;

  /// Human-readable failure description.
  final String message;

  /// Creates a transaction lifecycle failure.
  const TransactionLifecycleFailure(
      {required this.id,
      required this.cycle,
      required this.message,
      this.key,
      this.resource});
}

/// Tracks outstanding keyed transactions and their attributed resources.
///
/// Tests call [observeRequest] for each accepted request and [observeResponse]
/// for every accepted response beat. A response only releases a key when its
/// caller-provided `completes` argument is true. [observeCancellation] records
/// an explicit terminal cancellation. Every method is deterministic and does
/// not require a particular hardware interface or protocol payload type.
class KeyedTransactionLifecycleChecker<KeyType, ResourceType> {
  final Map<KeyType, ResourceType> _outstanding = {};
  final List<TransactionLifecycleFailure<KeyType, ResourceType>> _failures = [];

  /// Outstanding key-to-resource ownership in insertion-independent form.
  Map<KeyType, ResourceType> get outstanding =>
      UnmodifiableMapView(_outstanding);

  /// Failures in observation order.
  List<TransactionLifecycleFailure<KeyType, ResourceType>> get failures =>
      UnmodifiableListView(_failures);

  /// Records one accepted request and its selected resource.
  void observeRequest(
      {required KeyType key,
      required ResourceType resource,
      required int cycle}) {
    if (_outstanding.containsKey(key)) {
      _failures.add(TransactionLifecycleFailure(
          id: 'lifecycle.duplicate_key',
          cycle: cycle,
          key: key,
          resource: resource,
          message:
              'Accepted a request for a key that is already outstanding.'));
      return;
    }
    _outstanding[key] = resource;
  }

  /// Records one accepted response beat and returns its attributed resource.
  ///
  /// A non-final beat retains ownership. An unknown key records an
  /// `lifecycle.unexpected_response` failure and returns `null`.
  ResourceType? observeResponse(
      {required KeyType key, required bool completes, required int cycle}) {
    final resource = _outstanding[key];
    if (resource == null) {
      _failures.add(TransactionLifecycleFailure(
          id: 'lifecycle.unexpected_response',
          cycle: cycle,
          key: key,
          message:
              'Accepted a response for a key with no outstanding request.'));
      return null;
    }
    if (completes) {
      _outstanding.remove(key);
    }
    return resource;
  }

  /// Records an explicit cancellation and returns its released resource.
  ResourceType? observeCancellation(
      {required KeyType key, required int cycle}) {
    final resource = _outstanding.remove(key);
    if (resource == null) {
      _failures.add(TransactionLifecycleFailure(
          id: 'lifecycle.cancel_miss',
          cycle: cycle,
          key: key,
          message: 'Canceled a key with no outstanding request.'));
    }
    return resource;
  }

  /// Returns failures for requests that never reached a terminal outcome.
  List<TransactionLifecycleFailure<KeyType, ResourceType>> verifyComplete(
          {required int cycle}) =>
      List.unmodifiable(_outstanding.entries.map((entry) =>
          TransactionLifecycleFailure(
              id: 'lifecycle.missing_completion',
              cycle: cycle,
              key: entry.key,
              resource: entry.value,
              message: 'Outstanding request did not complete or cancel.')));
}
