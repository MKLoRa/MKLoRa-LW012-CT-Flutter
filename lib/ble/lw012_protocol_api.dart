import 'lw012_ble_client.dart';
import 'lw012_param_key.dart';

class Lw012ProtocolApi {
  Lw012ProtocolApi(this._client);

  final Lw012BleClient _client;

  Lw012BleClient get client => _client;

  Future<bool> verifyPassword(String password) {
    return _client.verifyPassword(password);
  }

  Future<Lw012ParamResult> readParam(
    Lw012ParamKey key, {
    Lw012ParamChannel channel = Lw012ParamChannel.runtime,
    bool packet = false,
  }) {
    if (!key.canRead) {
      throw Lw012ProtocolException('Parameter ${key.name} is write-only');
    }
    return _client.readParam(
      cmd: key.cmd,
      subCmd: key.subCmd,
      channel: channel,
      packet: packet,
    );
  }

  Future<bool> writeParam(
    Lw012ParamKey key,
    List<int> data, {
    Lw012ParamChannel channel = Lw012ParamChannel.runtime,
    bool packet = false,
  }) {
    if (!key.canWrite) {
      throw Lw012ProtocolException('Parameter ${key.name} is read-only');
    }
    return _client.writeParam(
      cmd: key.cmd,
      subCmd: key.subCmd,
      data: data,
      channel: channel,
      packet: packet,
    );
  }

}

class Lw012DeviceInfoApi {
  Lw012DeviceInfoApi(this._client);

  final Lw012BleClient _client;

  Future<String> readModelNumber() => _client.readModelNumber();
  Future<String> readSerialNumber() => _client.readSerialNumber();
  Future<String> readFirmwareRevision() => _client.readFirmwareRevision();
  Future<String> readHardwareRevision() => _client.readHardwareRevision();
  Future<String> readSoftwareRevision() => _client.readSoftwareRevision();
  Future<String> readManufacturerName() => _client.readManufacturerName();
}
