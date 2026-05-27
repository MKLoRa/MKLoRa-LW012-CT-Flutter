import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/ble_device_info.dart';
import 'lw012_ble_client.dart';
import 'lw012_export_data_store.dart';
import 'lw012_protocol_api.dart';

class Lw012DeviceSession {
  Lw012DeviceSession._({
    required this.deviceInfo,
    required this.client,
    required this.protocol,
    required this.deviceInfoApi,
  });

  final BleDeviceInfo deviceInfo;
  final Lw012BleClient client;
  final Lw012ProtocolApi protocol;
  final Lw012DeviceInfoApi deviceInfoApi;
  final Lw012ExportDataStore exportData = Lw012ExportDataStore();

  static Lw012DeviceSession? _active;

  static Lw012DeviceSession? get active => _active;

  static Future<Lw012DeviceSession> connect({
    required BleDeviceInfo deviceInfo,
    String? password,
  }) async {
    final bluetoothDevice = BluetoothDevice.fromId(deviceInfo.id.str);
    final client = Lw012BleClient();

    await client.connectWithRetry(bluetoothDevice);

    if (password != null && password.isNotEmpty) {
      final verified = await client.verifyPassword(password);
      if (!verified) {
        await client.disconnect();
        throw Lw012ProtocolException('Password verification failed');
      }
    }

    final session = Lw012DeviceSession._(
      deviceInfo: deviceInfo,
      client: client,
      protocol: Lw012ProtocolApi(client),
      deviceInfoApi: Lw012DeviceInfoApi(client),
    );
    _active = session;
    return session;
  }

  Future<void> disconnect() async {
    await client.disconnect();
    clearActiveIfMatches(this);
  }

  static void clearActiveIfMatches(Lw012DeviceSession session) {
    if (_active == session) {
      _active = null;
    }
  }
}
