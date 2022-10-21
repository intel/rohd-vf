/// Copyright (C) 2021 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// tracker.dart
/// A tracker to generate pretty and convenient logs from events
///
/// 2021 December 7
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'dart:io';
import 'dart:math';

/// Selection of how to align text in a column.
enum Justify {
  /// Right-justify, text is aligned with no space on the right.
  right,

  /// Left-justify, text is aligned with no space on the left.
  left,

  /// Centered, text is centered with equal space on both the
  /// left and the right.
  center
}

/// A field or column in a [Tracker] log.
class TrackerField {
  /// The width (in characters) of a column for a [Tracker] log.
  final int columnWidth;

  /// The title and name of a column for a [Tracker] log.
  final String title;

  /// A [String] to use to fill a column for a row where no data is provided.
  final String emptyFill;

  /// How the data should be aligned with a column of a [Tracker] log.
  final Justify justify;

  /// If set to true, will not print as part of the table, but still be
  /// included in the map outputs.
  final bool mapOnly;

  /// Represents one field or column in the [Tracker] titled [title].
  const TrackerField(this.title, this.columnWidth,
      {this.emptyFill = '', this.justify = Justify.right, this.mapOnly = false})
      : assert(columnWidth > 0, '`columnWidth` must be greater than 0.');
}

/// An interface for an object that can be tracked by a [Tracker].
///
/// Any item that `implements` this class can be tracked.
// ignore: one_member_abstracts
abstract class Trackable {
  /// Returns a formatted [String] value associated with [field] in this object.
  String? trackerString(TrackerField field);
}

/// A logger that tracks a sequence of [Trackable] events into multiple output
/// formats.
///
/// By default, [Tracker] outputs to both a ASCII table format
/// (<name>.tracker.log) and a JSON format (<name>.tracker.json).
class Tracker<TrackableType extends Trackable> {
  /// An optional output directory for the logs.
  ///
  /// By default, if null, files will dump to the current working directory.
  final String? outputFolder;

  /// If true, will dump an ASCII table log to [tableFileName].
  final bool dumpTable;

  /// If true, will dump a JSON file log to [jsonFileName].
  final bool dumpJson;

  /// The name of the file without an extension and including
  /// the directory, if applicable.
  String get _fileNameStart {
    var fileNameStart = name;
    if (outputFolder != null) {
      fileNameStart = '${outputFolder!}/$fileNameStart';
    }
    return fileNameStart;
  }

  /// The path to the generated JSON log file, if enabled by [dumpJson].
  String get jsonFileName => '$_fileNameStart.tracker.json';

  /// The path to the generated ASCII table log file, if enabled by [dumpTable].
  String get tableFileName => '$_fileNameStart.tracker.log';

  /// The name of this [Tracker], used for naming output files.
  final String name;

  /// A [List] of all [_TrackerDumper]s which are enabled for output dumping.
  late final List<_TrackerDumper<TrackableType>> _dumpers;

  /// Constructs a [Tracker] named [name] with the provided [fields].
  ///
  /// In the table view, the [spacer] is used to separate columns, the
  /// [separator] is used to separate the headers from the data, and the
  /// [overflow] is used to show that a value is exceeding the width of
  /// the column.  Tables will only dump if [dumpTable] is true.
  ///
  /// JSON files will only dump if [dumpJson] is true.
  ///
  /// All outputs are dumped to [outputFolder] if it is provided, otherwise
  /// they are dumepd in the current working directory.
  Tracker(this.name, List<TrackerField> fields,
      {String spacer = ' | ',
      String separator = '-',
      String overflow = '*',
      this.outputFolder,
      this.dumpTable = true,
      this.dumpJson = true}) {
    var fileNameStart = name;
    if (outputFolder != null) {
      fileNameStart = '${outputFolder!}/$fileNameStart';
    }
    _dumpers = [
      if (dumpJson) _JsonDumper<TrackableType>(jsonFileName, fields),
      if (dumpTable)
        _TableDumper<TrackableType>(tableFileName, fields,
            spacer: spacer, separator: separator, overflow: overflow)
    ];
  }

  /// Records [trackable] into all enabled logs.
  ///
  /// If [trackable] does not specify a value for a field, then
  /// the value from [defaults] will be used (key=title), if present.
  void record(TrackableType trackable,
      {Map<String, String?> defaults = const {}}) {
    for (final dumper in _dumpers) {
      dumper.record(trackable);
    }
  }

  /// Cleans up and finalizes all logs.
  ///
  /// If this is not called, the logs may be left in an
  /// incomplete/invalid format.
  ///
  /// Usually, a reasonable place to put this is in ROHD's
  /// `Simulator.registerEndOfSimulationAction`.
  Future<void> terminate() async {
    await Future.wait(_dumpers.map((dumper) => dumper.terminate()));
  }
}

/// A generic interface for an object which dumps to a log file
/// for a [Tracker].
abstract class _TrackerDumper<TrackableType extends Trackable> {
  /// All the [TrackerField]s to be dumped in the intended order.
  final List<TrackerField> _fields;

  /// The [File] to dump output to.
  final File _file;

  /// A sink to write contents into [_file].
  late final IOSink _fileSink;

  /// Constructs a new [_TrackerDumper], erasing any existing file with the
  /// same name.
  _TrackerDumper(String fileName, List<TrackerField> fields)
      : _fields = List.from(fields),
        _file = File(fileName) {
    // default is write mode, empty out existing files
    _fileSink = _file.openWrite();
  }

  /// Prints [message] to [_file], with a new line at the end.
  void logln(String message) {
    if (_hasTerminated) {
      throw Exception('Log has already terminated, cannot log more!');
    }
    _fileSink.write('$message\n');
  }

  /// Logs [trackable] into the log controlled by this [_TrackerDumper].
  void record(TrackableType trackable,
      {Map<String, String?> defaults = const {}});

  /// Keeps track if this has already performed a termination.
  bool _hasTerminated = false;

  /// Performs any clean-up or file ending at the end of the log.
  ///
  /// No more can be logged after this is called.
  Future<void> terminate() async {
    if (_hasTerminated) {
      throw Exception('Already terminated.');
    }
    await _fileSink.flush();
    await _fileSink.close();
    _hasTerminated = true;
  }
}

/// A dumper for ASCII tables.
class _TableDumper<TrackableType extends Trackable>
    extends _TrackerDumper<TrackableType> {
  final String spacer;
  final String separator;
  final String overflow;
  _TableDumper(super.fileName, super.fields,
      {required this.spacer, required this.separator, required this.overflow}) {
    _recordHeader();
  }

  @override
  void record(TrackableType trackable,
      {Map<String, String?> defaults = const {}}) {
    _recordLine({
      for (var field in _fields)
        field: trackable.trackerString(field) ?? defaults[field.title]
    });
  }

  /// Prints the table header with vertically printed titles and separators.
  void _recordHeader() {
    final headerFields = _fields.where((element) => !element.mapOnly);
    final headerHeight =
        headerFields.map((field) => field.title.length).reduce(max);

    _recordSeparator();
    for (var charIdx = 0; charIdx < headerHeight; charIdx++) {
      final entry = <TrackerField, String>{};
      for (final field in headerFields) {
        if (charIdx < field.title.length) {
          entry[field] = field.title[charIdx].toUpperCase();
        }
      }
      _recordLine(entry,
          justify: Justify.left, emptyFill: '', includeMap: false);
    }

    _recordSeparator();
  }

  void _recordSeparator() {
    logln(List.generate(
        _fields
                .where((element) => !element.mapOnly)
                .map((field) => field.columnWidth + spacer.length)
                .reduce((l1, l2) => l1 + l2) +
            spacer.length,
        (index) => separator).join());
  }

  void _recordLine(Map<TrackerField, String?> entry,
      {Justify? justify, String? emptyFill, bool includeMap = true}) {
    final headerFields = _fields.where((element) => !element.mapOnly);
    final fieldVals = headerFields.map((field) {
      var value = entry[field] ?? emptyFill ?? field.emptyFill;
      final fieldJustify = justify ?? field.justify;

      if (value.length > field.columnWidth) {
        if (overflow.length > field.columnWidth) {
          value = overflow.substring(0, field.columnWidth);
        } else {
          value = value.substring(0, field.columnWidth - overflow.length) +
              overflow;
        }
      }

      var leftPadding = 0;
      var rightPadding = 0;
      final totalPadding = field.columnWidth - value.length;

      if (fieldJustify == Justify.left) {
        rightPadding = totalPadding;
      } else if (fieldJustify == Justify.right) {
        leftPadding = totalPadding;
      } else if (fieldJustify == Justify.center) {
        leftPadding = totalPadding ~/ 2;
        rightPadding = totalPadding - leftPadding;
      }
      final leftPaddingStr = List.generate(leftPadding, (index) => ' ').join();
      final rightPaddingStr =
          List.generate(rightPadding, (index) => ' ').join();
      return leftPaddingStr + value + rightPaddingStr;
    });

    final map = {for (var field in _fields) field.title: entry[field]};
    final line = [
      ...fieldVals,
      if (includeMap) map.toString() else '',
    ].join(spacer);
    logln(spacer + line);
  }
}

/// A dumper for JSON files.
class _JsonDumper<TrackableType extends Trackable>
    extends _TrackerDumper<TrackableType> {
  _JsonDumper(super.fileName, super.fields) {
    _recordStart();
  }

  void _recordStart() {
    logln('{"records":[');
  }

  void _recordEnd() {
    logln(']}');
  }

  bool _isFirst = true;
  @override
  void record(TrackableType trackable,
      {Map<String, String?> defaults = const {}}) {
    final start = _isFirst ? ' ' : ',';
    _isFirst = false;
    final map = {
      for (var field in _fields)
        '"${field.title}"':
            '"${trackable.trackerString(field) ?? defaults[field.title]}"'
    };
    logln('$start $map');
  }

  @override
  Future<void> terminate() async {
    _recordEnd();
    await super.terminate();
  }
}
