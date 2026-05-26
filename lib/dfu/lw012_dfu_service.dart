import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nordic_dfu/nordic_dfu.dart';

class Lw012DfuException implements Exception {
  Lw012DfuException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Lw012DfuService {
  Lw012DfuService._();

  static Future<void> start({
    required String address,
    required String filePath,
    void Function(String status)? onStatus,
    void Function(int percent)? onProgress,
  }) async {
    final completer = Completer<void>();
    var connectAttempts = 0;
    var finished = false;

    void finishError(Object error) {
      if (finished) return;
      finished = true;
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    void finishSuccess() {
      if (finished) return;
      finished = true;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    onStatus?.call('Waiting...');
    debugPrint('[LW012 DFU] start address=$address file=$filePath');

    NordicDfu()
        .startDfu(
          address,
          filePath,
          darwinParameters: Platform.isIOS
              ? const DarwinParameters(
                  forceScanningForNewAddressInLegacyDfu: true,
                  alternativeAdvertisingNameEnabled: true,
                )
              : const DarwinParameters(),
          androidParameters: const AndroidParameters(
            keepBond: false,
            disableNotification: true,
            startAsForegroundService: false,
          ),
          dfuEventHandler: DfuEventHandler(
            onDeviceConnecting: (_) {
              connectAttempts++;
              onStatus?.call('Connecting...');
              if (connectAttempts > 3) {
                onStatus?.call('Error:DFU Failed');
                NordicDfu().abortDfu();
                finishError(Lw012DfuException('Error:DFU Failed'));
              }
            },
            onDfuProcessStarting: (_) => onStatus?.call('DfuProcessStarting...'),
            onEnablingDfuMode: (_) => onStatus?.call('EnablingDfuMode...'),
            onFirmwareValidating: (_) => onStatus?.call('FirmwareValidating...'),
            onProgressChanged: (_, percent, __, ___, ____, _____) {
              onProgress?.call(percent);
              onStatus?.call('Progress:$percent%');
            },
            onDfuAborted: (_) {
              onStatus?.call('DfuAborted...');
              finishError(Lw012DfuException('DfuAborted'));
            },
            onError: (_, __, ___, message) {
              debugPrint('[LW012 DFU] error: $message');
              finishError(
                Lw012DfuException(
                  message.isEmpty ? 'Opps!DFU Failed. Please try again!' : message,
                ),
              );
            },
            onDfuCompleted: (_) => finishSuccess(),
          ),
        )
        .then((_) => finishSuccess())
        .catchError((Object error) {
      debugPrint('[LW012 DFU] startDfu failed: $error');
      if (error is Lw012DfuException) {
        finishError(error);
      } else if (error is PlatformException) {
        finishError(Lw012DfuException(error.message ?? 'Opps!DFU Failed. Please try again!'));
      } else {
        finishError(Lw012DfuException('Opps!DFU Failed. Please try again!'));
      }
    });

    return completer.future;
  }
}
