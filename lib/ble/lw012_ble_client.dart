import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'lw012_constants.dart';
import 'lw012_disconnect_event.dart';
import 'lw012_protocol_codec.dart';
import 'lw012_protocol_logger.dart';

class Lw012BleClient {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _passwordChar;
  BluetoothCharacteristic? _disconnectChar;
  BluetoothCharacteristic? _paramsChar;
  BluetoothCharacteristic? _storageDataNotifyChar;
  BluetoothCharacteristic? _modelNumberChar;
  BluetoothCharacteristic? _serialNumberChar;
  BluetoothCharacteristic? _firmwareRevisionChar;
  BluetoothCharacteristic? _hardwareRevisionChar;
  BluetoothCharacteristic? _softwareRevisionChar;
  BluetoothCharacteristic? _manufacturerNameChar;

  final Map<String, StreamSubscription<List<int>>> _notifySubscriptions = {};
  final Map<String, Completer<List<int>>> _pendingRequests = {};
  final Map<String, List<List<int>>> _packetBuffers = {};
  final _disconnectController = StreamController<Lw012DisconnectEvent>.broadcast();
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Future<void> _requestChain = Future<void>.value();

  Stream<Lw012DisconnectEvent> get disconnectEvents => _disconnectController.stream;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  Future<void> connectWithRetry(BluetoothDevice device) async {
    _device = device;
    final deadline = DateTime.now().add(Lw012ProtocolConstants.connectTotalTimeout);
    Object? lastError;

    for (var attempt = 0; attempt < Lw012ProtocolConstants.connectMaxAttempts; attempt++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Connection timed out after ${Lw012ProtocolConstants.connectTotalTimeout.inSeconds}s',
        );
      }

      try {
        if (device.isConnected) {
          await device.disconnect();
        }
        await device.connect(
          timeout: remaining,
          autoConnect: false,
        );
        if (Platform.isAndroid) {
          await device.requestMtu(247);
        }
        await _discoverServices(device);
        await _enableNotifications();
        // Match Android: wait briefly after connect before sending protocol frames.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _listenConnectionState(device);
        return;
      } catch (error) {
        lastError = error;
        debugPrint('LW012 connect attempt ${attempt + 1} failed: $error');
        if (attempt < Lw012ProtocolConstants.connectMaxAttempts - 1) {
          await Future<void>.delayed(
            const Duration(milliseconds: Lw012ProtocolConstants.connectRetryDelayMs),
          );
        }
      }
    }

    throw lastError ?? Exception('Connection failed');
  }

  Future<void> disconnect() async {
    await _clearSubscriptions();
    final device = _device;
    _device = null;
    if (device != null && device.isConnected) {
      await device.disconnect();
    }
  }

  Future<bool> verifyPassword(String password) async {
    final characteristic = _requireCharacteristic(_passwordChar, 'password');
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw012ProtocolCodec.buildPasswordFrame(password),
      cmd: Lw012ProtocolConstants.passwordCmd,
      subCmd: Lw012ProtocolConstants.passwordSubCmd,
      matcher: Lw012ProtocolCodec.isPasswordSuccess,
    );
    return Lw012ProtocolCodec.isPasswordSuccess(response);
  }

  Future<Lw012ParamResult> readParam({
    required int cmd,
    required int subCmd,
    Lw012ParamChannel channel = Lw012ParamChannel.runtime,
    bool packet = false,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw012ProtocolCodec.buildReadFrame(
        cmd: cmd,
        subCmd: subCmd,
        packet: packet,
      ),
      cmd: cmd,
      subCmd: subCmd,
    );
    final parsed = Lw012ProtocolCodec.parseReadResponse(response);
    if (parsed == null) {
      throw Lw012ProtocolException('Invalid read response for 0x${cmd.toRadixString(16)}${subCmd.toRadixString(16)}');
    }
    return Lw012ParamResult(
      cmd: parsed.cmd,
      subCmd: parsed.subCmd,
      data: parsed.data,
      raw: response,
    );
  }

  Future<bool> writeParam({
    required int cmd,
    required int subCmd,
    required List<int> data,
    Lw012ParamChannel channel = Lw012ParamChannel.runtime,
    bool packet = false,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw012ProtocolCodec.buildWriteFrame(
        cmd: cmd,
        subCmd: subCmd,
        data: data,
        packet: packet,
      ),
      cmd: cmd,
      subCmd: subCmd,
      matcher: (value) => Lw012ProtocolCodec.isWriteSuccess(value, cmd, subCmd),
    );
    return Lw012ProtocolCodec.isWriteSuccess(response, cmd, subCmd);
  }

  Future<String> readDeviceInfoString(
    BluetoothCharacteristic characteristic, {
    required String name,
  }) async {
    final value = await characteristic.read();
    Lw012ProtocolLogger.logGattRead(name: name, value: value);
    return String.fromCharCodes(value.where((b) => b != 0)).trim();
  }

  Future<String> readModelNumber() => readDeviceInfoString(
        _requireCharacteristic(_modelNumberChar, 'model number'),
        name: 'modelNumber',
      );
  Future<String> readSerialNumber() => readDeviceInfoString(
        _requireCharacteristic(_serialNumberChar, 'serial number'),
        name: 'serialNumber',
      );
  Future<String> readFirmwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_firmwareRevisionChar, 'firmware revision'),
        name: 'firmwareRevision',
      );
  Future<String> readHardwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_hardwareRevisionChar, 'hardware revision'),
        name: 'hardwareRevision',
      );
  Future<String> readSoftwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_softwareRevisionChar, 'software revision'),
        name: 'softwareRevision',
      );
  Future<String> readManufacturerName() => readDeviceInfoString(
        _requireCharacteristic(_manufacturerNameChar, 'manufacturer name'),
        name: 'manufacturerName',
      );

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final deviceInfo = _findService(services, Lw012Uuids.deviceInfoService);
    final custom = _findService(services, Lw012Uuids.customService);

    if (deviceInfo == null) {
      throw Lw012ProtocolException('Device Information Service not found');
    }
    if (custom == null) {
      throw Lw012ProtocolException('Custom service 0xAA00 not found');
    }

    _modelNumberChar = _findCharacteristic(deviceInfo, Lw012Uuids.modelNumber);
    _serialNumberChar = _findCharacteristic(deviceInfo, Lw012Uuids.serialNumber);
    _firmwareRevisionChar = _findCharacteristic(deviceInfo, Lw012Uuids.firmwareRevision);
    _hardwareRevisionChar = _findCharacteristic(deviceInfo, Lw012Uuids.hardwareRevision);
    _softwareRevisionChar = _findCharacteristic(deviceInfo, Lw012Uuids.softwareRevision);
    _manufacturerNameChar = _findCharacteristic(deviceInfo, Lw012Uuids.manufacturerName);

    _passwordChar = _findCharacteristic(custom, Lw012Uuids.password);
    _disconnectChar = _findCharacteristic(custom, Lw012Uuids.disconnectNotify);
    _paramsChar = _findCharacteristic(custom, Lw012Uuids.params);
    _storageDataNotifyChar = _findCharacteristic(custom, Lw012Uuids.storageDataNotify);

    if (_passwordChar == null || _paramsChar == null || _disconnectChar == null) {
      throw Lw012ProtocolException('Required custom characteristics not found');
    }
  }

  Future<void> _enableNotifications() async {
    await _subscribeCharacteristic(_passwordChar!, 'password');
    await _subscribeCharacteristic(_disconnectChar!, 'disconnect');
    await _subscribeCharacteristic(_paramsChar!, 'params');
    if (_storageDataNotifyChar != null) {
      await _subscribeCharacteristic(_storageDataNotifyChar!, 'storageData');
    }
  }

  Future<void> _subscribeCharacteristic(
    BluetoothCharacteristic characteristic,
    String key,
  ) async {
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions[key]?.cancel();
    _notifySubscriptions[key] = characteristic.onValueReceived.listen(
      (value) => _handleNotification(key, value),
    );
  }

  void _handleNotification(String key, List<int> value) {
    if (value.isEmpty) {
      return;
    }

    if (key == 'disconnect') {
      Lw012ProtocolLogger.logDisconnectNotify(value);
      final event = Lw012DisconnectEvent.fromNotificationBytes(value);
      if (event != null) {
        _disconnectController.add(event);
      }
      return;
    }

    if (value[0] == Lw012ProtocolConstants.headPacket) {
      Lw012ProtocolLogger.logRx(channel: key, payload: value, partialPacket: true);
      final requestKey = _requestKeyFromPacket(value);
      _packetBuffers.putIfAbsent(requestKey, () => []).add(value);
      final packets = _packetBuffers[requestKey]!;
      final expectedCount = value[4];
      if (packets.length >= expectedCount) {
        final merged = Lw012ProtocolCodec.reassemblePacketResponses(packets);
        _packetBuffers.remove(requestKey);
        Lw012ProtocolLogger.logRx(channel: key, payload: merged);
        _completeRequest(requestKey, merged);
      }
      return;
    }

    Lw012ProtocolLogger.logRx(channel: key, payload: value);
    final requestKey = _requestKeyFromFrame(value);
    _completeRequest(requestKey, value);
  }

  Future<List<int>> _sendFrame({
    required BluetoothCharacteristic characteristic,
    required List<int> payload,
    required int cmd,
    required int subCmd,
    bool Function(List<int> value)? matcher,
  }) {
    return _enqueueRequest(() async {
      final requestKey = _requestKey(cmd, subCmd);
      final completer = Completer<List<int>>();
      _pendingRequests[requestKey] = completer;

      try {
        Lw012ProtocolLogger.logTx(
          channel: _channelNameForCharacteristic(characteristic),
          cmd: cmd,
          subCmd: subCmd,
          payload: payload,
        );
        final withoutResponse = _shouldWriteWithoutResponse(characteristic);
        await characteristic.write(payload, withoutResponse: withoutResponse);
        final response = await completer.future.timeout(
          Lw012ProtocolConstants.requestTimeout,
          onTimeout: () {
            Lw012ProtocolLogger.logError('Request timeout for $requestKey');
            throw TimeoutException('Request timeout for $requestKey');
          },
        );
        if (matcher != null && !matcher(response)) {
          Lw012ProtocolLogger.logError('Unexpected response for $requestKey');
          throw Lw012ProtocolException('Unexpected response for $requestKey');
        }
        return response;
      } finally {
        _pendingRequests.remove(requestKey);
        _packetBuffers.remove(requestKey);
      }
    });
  }

  Future<T> _enqueueRequest<T>(Future<T> Function() action) {
    final task = _requestChain.then((_) => action());
    _requestChain = task.then((_) {}, onError: (_) {});
    return task;
  }

  bool _shouldWriteWithoutResponse(BluetoothCharacteristic characteristic) {
    final properties = characteristic.properties;
    if (properties.write) {
      return false;
    }
    return properties.writeWithoutResponse;
  }

  void _completeRequest(String requestKey, List<int> value) {
    final completer = _pendingRequests[requestKey];
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  BluetoothCharacteristic _characteristicForChannel(Lw012ParamChannel channel) {
    switch (channel) {
      case Lw012ParamChannel.runtime:
        return _requireCharacteristic(_paramsChar, 'params');
      case Lw012ParamChannel.storageData:
        return _requireCharacteristic(_storageDataNotifyChar, 'storage data');
    }
  }

  BluetoothService? _findService(List<BluetoothService> services, String uuid) {
    final target = Guid(uuid);
    for (final service in services) {
      if (service.uuid == target) {
        return service;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    String uuid,
  ) {
    final target = Guid(uuid);
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == target) {
        return characteristic;
      }
    }
    return null;
  }

  BluetoothCharacteristic _requireCharacteristic(
    BluetoothCharacteristic? characteristic,
    String name,
  ) {
    if (characteristic == null) {
      throw Lw012ProtocolException('$name characteristic unavailable');
    }
    return characteristic;
  }

  String _channelNameForCharacteristic(BluetoothCharacteristic characteristic) {
    if (identical(characteristic, _passwordChar)) return 'password';
    if (identical(characteristic, _paramsChar)) return 'params';
    if (identical(characteristic, _storageDataNotifyChar)) return 'storageData';
    return characteristic.uuid.toString();
  }

  String _requestKey(int cmd, int subCmd) => '${cmd.toRadixString(16)}_${subCmd.toRadixString(16)}';

  String _requestKeyFromFrame(List<int> value) {
    if (value.length < 4) {
      return 'unknown';
    }
    return _requestKey(value[2], value[3]);
  }

  String _requestKeyFromPacket(List<int> value) {
    if (value.length < 4) {
      return 'unknown';
    }
    return _requestKey(value[2], value[3]);
  }

  void _listenConnectionState(BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _disconnectController.add(Lw012DisconnectEvent.generic);
      }
    });
  }

  Future<void> _clearSubscriptions() async {
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    for (final subscription in _notifySubscriptions.values) {
      await subscription.cancel();
    }
    _notifySubscriptions.clear();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          Lw012ProtocolException('Connection closed'),
        );
      }
    }
    _pendingRequests.clear();
    _packetBuffers.clear();
  }
}

enum Lw012ParamChannel {
  runtime,
  storageData,
}

class Lw012ParamResult {
  const Lw012ParamResult({
    required this.cmd,
    required this.subCmd,
    required this.data,
    required this.raw,
  });

  final int cmd;
  final int subCmd;
  final List<int> data;
  final List<int> raw;

  int get key => ((cmd & 0xFF) << 8) | (subCmd & 0xFF);
}

class Lw012ProtocolException implements Exception {
  Lw012ProtocolException(this.message);

  final String message;

  @override
  String toString() => 'Lw012ProtocolException: $message';
}
