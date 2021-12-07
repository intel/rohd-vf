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
enum Justify { right, left, center }

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

  const TrackerField(this.title, this.columnWidth,
      {this.emptyFill = '', this.justify = Justify.right})
      : assert(columnWidth > 0);
}

/// An interface for an object that can be tracked by a [Tracker].
///
/// Any item that `implements` this class can be tracked.
abstract class Trackable {
  /// Returns a formatted [String] value associated with [field] in this object.
  String? trackerString(TrackerField field);
}

/// A logger that tracks a sequence of [Trackable] events into multiple output formats.
///
/// By default, [Tracker] outputs to both a ASCII table format (*.tracker.log) and a
/// JSON format (*.tracker.json).
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
      fileNameStart = outputFolder! + '/' + fileNameStart;
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

  Tracker(this.name, List<TrackerField> fields,
      {String spacer = ' | ',
      String separator = '-',
      String overflow = '*',
      this.outputFolder,
      this.dumpTable = true,
      this.dumpJson = true}) {
    var fileNameStart = name;
    if (outputFolder != null) {
      fileNameStart = outputFolder! + '/' + fileNameStart;
    }
    _dumpers = [
      if (dumpJson) _JsonDumper<TrackableType>(jsonFileName, fields),
      if (dumpTable)
        _TableDumper<TrackableType>(tableFileName, fields,
            spacer: spacer, separator: separator, overflow: overflow)
    ];
  }

  /// Records [trackable] into all enabled logs.
  void record(TrackableType trackable) {
    for (var dumper in _dumpers) {
      dumper.record(trackable);
    }
  }

  /// Cleans up and finalizes all logs.
  ///
  /// If this is not called, the logs may be left in an
  /// incomplete/invalid format.
  Future<void> terminate() async {
    for (var dumper in _dumpers) {
      dumper.terminate();
    }
  }
}

/// A generic interface for an object which dumps to a log file
/// for a [Tracker].
abstract class _TrackerDumper<TrackableType extends Trackable> {
  /// All the [TrackerField]s to be dumped in the intended order.
  final List<TrackerField> _fields;

  /// The [File] to dump output to.
  final File _file;

  /// Constructs a new [_TrackerDumper], erasing any existing file with the same name.
  _TrackerDumper(String fileName, List<TrackerField> fields)
      : _fields = List.from(fields),
        _file = File(fileName) {
    _file.writeAsStringSync(''); // empty out existing files
  }

  /// Prints [message] to [_file], with a new line at the end.
  void logln(String message) {
    if (_hasTerminated) {
      throw Exception('Log has already terminated, cannot log more!');
    }
    _file.writeAsStringSync(message + '\n', mode: FileMode.append);
  }

  /// Logs [trackable] into the log controlled by this [_TrackerDumper].
  void record(TrackableType trackable);

  /// Keeps track if this has already performed a termination.
  bool _hasTerminated = false;

  /// Performs any clean-up or file ending at the end of the log.
  ///
  /// No more can be logged after this is called.
  void terminate() {
    if (_hasTerminated) {
      throw Exception('Already terminated.');
    }
    _hasTerminated = true;
  }
}

/// A dumper for ASCII tables.
class _TableDumper<TrackableType extends Trackable>
    extends _TrackerDumper<TrackableType> {
  final String spacer;
  final String separator;
  final String overflow;
  _TableDumper(String fileName, List<TrackerField> fields,
      {required this.spacer, required this.separator, required this.overflow})
      : super(fileName, fields) {
    _recordHeader();
  }

  @override
  void record(TrackableType trackable) {
    _recordLine(
        {for (var field in _fields) field: trackable.trackerString(field)});
  }

  /// Prints the table header with vertically printed titles and separators.
  void _recordHeader() {
    var headerHeight =
        _fields.map((field) => field.title.length).reduce((a, b) => max(a, b));

    _recordSeparator();
    for (var charIdx = 0; charIdx < headerHeight; charIdx++) {
      var entry = <TrackerField, String>{};
      for (var field in _fields) {
        if (charIdx < field.title.length) {
          entry[field] = field.title[charIdx];
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
                .map((field) => field.columnWidth + spacer.length)
                .reduce((l1, l2) => l1 + l2) +
            spacer.length,
        (index) => separator).join());
  }

  void _recordLine(Map<TrackerField, String?> entry,
      {Justify? justify, String? emptyFill, bool includeMap = true}) {
    var fieldVals = _fields.map((field) {
      var value = entry[field] ?? emptyFill ?? field.emptyFill;
      var fieldJustify = justify ?? field.justify;

      if (value.length > field.columnWidth) {
        if (overflow.length > field.columnWidth) {
          value = overflow.substring(0, field.columnWidth);
        } else {
          value = value.substring(0, field.columnWidth - overflow.length) +
              overflow;
        }
      }

      int leftPadding = 0, rightPadding = 0;
      var totalPadding = field.columnWidth - value.length;

      if (fieldJustify == Justify.left) {
        rightPadding = totalPadding;
      } else if (fieldJustify == Justify.right) {
        leftPadding = totalPadding;
      } else if (fieldJustify == Justify.center) {
        leftPadding = totalPadding ~/ 2;
        rightPadding = totalPadding - leftPadding;
      }
      var leftPaddingStr = List.generate(leftPadding, (index) => ' ').join();
      var rightPaddingStr = List.generate(rightPadding, (index) => ' ').join();
      return leftPaddingStr + value + rightPaddingStr;
    });

    var map = {for (var field in _fields) field.title: entry[field]};
    var line = [
      ...fieldVals,
      if (includeMap) map.toString() else '',
    ].join(spacer);
    logln(spacer + line);
  }
}

/// A dumper for JSON files.
class _JsonDumper<TrackableType extends Trackable>
    extends _TrackerDumper<TrackableType> {
  _JsonDumper(String fileName, List<TrackerField> fields)
      : super(fileName, fields) {
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
  void record(TrackableType trackable) {
    var start = _isFirst ? ' ' : ',';
    _isFirst = false;
    var map = {
      for (var field in _fields)
        '"${field.title}"': '"${trackable.trackerString(field)}"'
    };
    logln('$start $map');
  }

  @override
  void terminate() {
    _recordEnd();
    super.terminate();
  }
}
