import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String hexString(List<int> data) {
  return data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

class BleDeviceInfo {
  final DeviceIdentifier id;
  final String name;
  final String macAddress;
  final int rssi;
  final int? txPowerLevel;
  final int deviceType;
  final int lowPowerState;
  final int batteryVoltageMv;
  final bool passwordEnabled;
  final List<int> rawServiceData;
  final int lastScanMs;
  final int scanIntervalMs;

  BleDeviceInfo({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    required this.txPowerLevel,
    required this.deviceType,
    required this.lowPowerState,
    required this.batteryVoltageMv,
    required this.passwordEnabled,
    required this.rawServiceData,
    this.lastScanMs = 0,
    this.scanIntervalMs = 0,
  });

  String get scanIntervalLabel =>
      scanIntervalMs == 0 ? '<->N/A' : '<->${scanIntervalMs}ms';

  BleDeviceInfo copyWith({
    DeviceIdentifier? id,
    String? name,
    String? macAddress,
    int? rssi,
    int? txPowerLevel,
    int? deviceType,
    int? lowPowerState,
    int? batteryVoltageMv,
    bool? passwordEnabled,
    List<int>? rawServiceData,
    int? lastScanMs,
    int? scanIntervalMs,
  }) {
    return BleDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      txPowerLevel: txPowerLevel ?? this.txPowerLevel,
      deviceType: deviceType ?? this.deviceType,
      lowPowerState: lowPowerState ?? this.lowPowerState,
      batteryVoltageMv: batteryVoltageMv ?? this.batteryVoltageMv,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
      rawServiceData: rawServiceData ?? this.rawServiceData,
      lastScanMs: lastScanMs ?? this.lastScanMs,
      scanIntervalMs: scanIntervalMs ?? this.scanIntervalMs,
    );
  }

  /// Service Data (AD type 0x16) payload: leading fields + last 6 bytes = MAC.
  static String _macFromServiceData(List<int> data) {
    final macBytes = data.sublist(data.length - 6);
    return macBytes
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static BleDeviceInfo? fromScanResult(ScanResult result) {
    for (final data in result.advertisementData.serviceData.values) {
      // AA17 service data: min 4-byte header + 6-byte MAC at tail.
      if (data.length >= 10) {
        final deviceType = data[0] & 0xFF;
        final lowPowerState = (data[1] >> 4) & 0x01;
        final passwordEnabled = ((data[1] >> 5) & 0x01) == 1;
        final batteryVoltageMv =
            ((data[2] & 0xFF) << 8) | (data[3] & 0xFF);

        return BleDeviceInfo(
          id: result.device.remoteId,
          name: result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : result.device.advName,
          macAddress: _macFromServiceData(data),
          rssi: result.rssi,
          txPowerLevel: result.advertisementData.txPowerLevel,
          deviceType: deviceType,
          lowPowerState: lowPowerState,
          batteryVoltageMv: batteryVoltageMv,
          passwordEnabled: passwordEnabled,
          rawServiceData: data,
        );
      }
    }
    return null;
  }
}
