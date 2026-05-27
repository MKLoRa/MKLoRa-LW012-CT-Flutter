import 'lw012_param_helpers.dart';

class Lw012PayloadConfig {
  const Lw012PayloadConfig({required this.confirmed, required this.retransIndex});

  final bool confirmed;
  final int retransIndex;

  static Lw012PayloadConfig fromBytes(List<int> data) {
    if (data.length < 2) {
      return const Lw012PayloadConfig(confirmed: false, retransIndex: 0);
    }
    return Lw012PayloadConfig(
      confirmed: data[0] == 1,
      retransIndex: (data[1] - 1).clamp(0, 3),
    );
  }

  List<int> toBytes() => [confirmed ? 1 : 0, retransIndex + 1];
}

class Lw012TimePoint {
  Lw012TimePoint({required this.hour, required this.minute});

  int hour;
  int minute;

  int toMinutes() => hour * 60 + minute;

  static Lw012TimePoint fromMinutes(int value) {
    if (value == 0) {
      return Lw012TimePoint(hour: 0, minute: 0);
    }
    final hour = value ~/ 60;
    final minute = value % 60;
    return Lw012TimePoint(hour: hour == 24 ? 0 : hour, minute: minute);
  }
}

class Lw012TimeSegment {
  Lw012TimeSegment({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.reportInterval,
  });

  int startHour;
  int startMinute;
  int endHour;
  int endMinute;
  int reportInterval;

  List<int> encode() {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return [
      ...Lw012ParamHelpers.uint16Bytes(start),
      ...Lw012ParamHelpers.uint16Bytes(end),
      ...Lw012ParamHelpers.int32Bytes(reportInterval),
    ];
  }
}

class Lw012ExportRecord {
  Lw012ExportRecord({required this.rawData, DateTime? time}) : time = time ?? DateTime.now();

  final DateTime time;
  final String rawData;
}

class Lw012StorageNotifyParseResult {
  const Lw012StorageNotifyParseResult({this.records, this.totalSum});

  final List<Lw012ExportRecord>? records;
  final int? totalSum;
}

class Lw012DataCodec {
  Lw012DataCodec._();

  static List<int> encodeTimePoints(List<Lw012TimePoint> points) {
    final bytes = <int>[];
    for (final point in points) {
      bytes.addAll(Lw012ParamHelpers.uint16Bytes(point.toMinutes()));
    }
    return bytes;
  }

  static List<Lw012TimePoint> decodeTimePoints(List<int> data) {
    final points = <Lw012TimePoint>[];
    for (var i = 0; i + 1 < data.length; i += 2) {
      final minutes = Lw012ParamHelpers.uint16(data.sublist(i, i + 2));
      points.add(Lw012TimePoint.fromMinutes(minutes));
    }
    return points;
  }

  static List<int> encodeTimeSegments(List<Lw012TimeSegment> segments) {
    final bytes = <int>[];
    for (final segment in segments) {
      bytes.addAll(segment.encode());
    }
    return bytes;
  }

  static List<Lw012TimeSegment> decodeTimeSegments(List<int> data) {
    final segments = <Lw012TimeSegment>[];
    for (var i = 0; i + 7 < data.length; i += 8) {
      final start = Lw012ParamHelpers.uint16(data.sublist(i, i + 2));
      final end = Lw012ParamHelpers.uint16(data.sublist(i + 2, i + 4));
      final interval = Lw012ParamHelpers.int32(data.sublist(i + 4, i + 8));
      final startPoint = Lw012TimePoint.fromMinutes(start);
      final endPoint = Lw012TimePoint.fromMinutes(end);
      segments.add(
        Lw012TimeSegment(
          startHour: startPoint.hour,
          startMinute: startPoint.minute,
          endHour: endPoint.hour,
          endMinute: endPoint.minute,
          reportInterval: interval,
        ),
      );
    }
    return segments;
  }

  static List<String> decodeMacRules(List<int> data) {
    final rules = <String>[];
    var index = 0;
    while (index < data.length) {
      final length = data[index];
      index++;
      if (index + length > data.length) break;
      rules.add(Lw012ParamHelpers.bytesToHex(data.sublist(index, index + length)));
      index += length;
    }
    return rules;
  }

  static List<int> encodeMacRules(List<String> macs) {
    final bytes = <int>[];
    for (final mac in macs) {
      final macBytes = Lw012ParamHelpers.hexToBytes(mac);
      if (macBytes.isEmpty) continue;
      bytes.add(macBytes.length);
      bytes.addAll(macBytes);
    }
    return bytes;
  }

  static List<String> decodeNameRules(List<int> data) {
    final rules = <String>[];
    var index = 0;
    while (index < data.length) {
      final length = data[index];
      index++;
      if (index + length > data.length) break;
      rules.add(String.fromCharCodes(data.sublist(index, index + length)));
      index += length;
    }
    return rules;
  }

  static List<int> encodeNameRules(List<String> names) {
    final bytes = <int>[];
    for (final name in names) {
      final nameBytes = name.codeUnits;
      if (nameBytes.isEmpty) continue;
      bytes.add(nameBytes.length);
      bytes.addAll(nameBytes);
    }
    return bytes;
  }

  /// LW012-CT indicator bitmask (single byte), aligned with native IndicatorSettingsActivity.
  static int encodeIndicator({
    required bool deviceState,
    required bool fix,
    required bool fixSuccess,
    required bool fixFail,
    required bool networkCheck,
    required bool lowPower,
    required bool bleAdvCheck,
  }) {
    return (fix ? 1 : 0) |
        (fixSuccess ? 2 : 0) |
        (fixFail ? 4 : 0) |
        (networkCheck ? 8 : 0) |
        (lowPower ? 16 : 0) |
        (bleAdvCheck ? 32 : 0) |
        (deviceState ? 64 : 0);
  }

  static Map<String, bool> decodeIndicator(int value) {
    final v = value & 0xFF;
    return {
      'deviceState': (v & 64) == 64,
      'fix': (v & 1) == 1,
      'fixSuccess': (v & 2) == 2,
      'fixFail': (v & 4) == 4,
      'networkCheck': (v & 8) == 8,
      'lowPower': (v & 16) == 16,
      'bleAdvCheck': (v & 32) == 32,
    };
  }

  static Lw012StorageNotifyParseResult? parseStorageNotify(List<int> value) {
    if (value.length < 6 || value[0] != 0xED || value[1] != 0x02) {
      return null;
    }
    // Native ExportDataActivity: MokoUtils.toInt(value[2..4]) == 0x01
    final cmd = Lw012ParamHelpers.uint16(value, offset: 2);
    if (cmd != 0x01) {
      return null;
    }
    final dataCount = value[5] & 0xFF;
    if (dataCount > 0) {
      final notifyTime = DateTime.now();
      final records = <Lw012ExportRecord>[];
      var index = 6;
      while (index < value.length) {
        final dataLength = value[index] & 0xFF;
        index++;
        var rawData = '';
        if (dataLength > 0 && index + dataLength <= value.length) {
          rawData = Lw012ParamHelpers.bytesToHex(
            value.sublist(index, index + dataLength),
          );
          index += dataLength;
        }
        records.add(Lw012ExportRecord(rawData: rawData, time: notifyTime));
      }
      return Lw012StorageNotifyParseResult(records: records);
    }
    if (value.length > 5) {
      var sum = 0;
      for (var i = 5; i < value.length; i++) {
        sum = (sum << 8) | (value[i] & 0xFF);
      }
      return Lw012StorageNotifyParseResult(totalSum: sum);
    }
    return null;
  }

  static List<int> encodeLoraUplinkStrategy({
    required bool adr,
    required int dr1,
    required int dr2,
  }) =>
      [adr ? 1 : 0, 1, dr1, dr2];

  static List<int> encodeAccCondition(int threshold, int duration) => [threshold, duration];
}
