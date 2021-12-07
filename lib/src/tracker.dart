import 'dart:io';
import 'dart:math';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
// import 'package:rohd/rohd.dart';

enum Justify { right, left, center }

class TrackerField {
  final int columnWidth;
  final String title;
  final String emptyFill;
  final Justify justify;
  const TrackerField(this.title, this.columnWidth,
      {this.emptyFill = '', this.justify = Justify.right});
}

abstract class Trackable {
  String? trackerString(TrackerField field);
}

enum TrackerStyle { table, json }

class Tracker<TrackableType extends Trackable> {
  final String? outputFolder;

  final bool dumpTable, dumpJson;

  String get _fileNameStart {
    var fileNameStart = name;
    if (outputFolder != null) {
      fileNameStart = outputFolder! + '/' + fileNameStart;
    }
    return fileNameStart;
  }

  String get jsonFileName => '$_fileNameStart.tracker.json';
  String get logFileName => '$_fileNameStart.tracker.log';

  final String name;
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
        _TableDumper<TrackableType>(logFileName, fields,
            spacer: spacer, separator: separator, overflow: overflow)
    ];
  }

  void record(TrackableType trackable) {
    for (var dumper in _dumpers) {
      dumper.record(trackable);
    }
  }

  Future<void> terminate() async {
    for (var dumper in _dumpers) {
      dumper.terminate();
    }
  }
}

abstract class _TrackerDumper<TrackableType extends Trackable> {
  final List<TrackerField> _fields;
  final File _file;
  _TrackerDumper(String fileName, List<TrackerField> fields)
      : _fields = List.from(fields),
        _file = File(fileName) {
    _file.writeAsStringSync(''); // empty out existing files
  }

  void logln(String message) {
    _file.writeAsStringSync(message + '\n', mode: FileMode.append);
  }

  void record(TrackableType trackable);

  void terminate() {}
}

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
    var line = [...fieldVals, if (includeMap) map.toString()].join(spacer);
    logln(spacer + line);
  }
}

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

  // TODO: add some sort of clean-up stage at the end of a test for stuff like this

  @override
  void terminate() {
    _recordEnd();
    super.terminate();
  }
}
