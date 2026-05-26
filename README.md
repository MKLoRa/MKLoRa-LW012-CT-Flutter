# MKLoRa LW012-CT Flutter

Flutter client for LW012-CT devices. Supports BLE scanning, connection, parameter read/write, disconnect notifications, and Nordic DFU firmware updates on Android and iOS physical devices.

Native Android reference project: `LW012_CT_Android`.

## BLE scan

Scanning filters LW012 advertisements by Service Data UUID `0000aa17-...`. Parsed fields match the native app:

- `deviceType` at byte 0
- `lowPowerState` at bit 4 of byte 1
- `passwordEnabled` at bit 5 of byte 1
- `batteryVoltageMv` at bytes 2–3

## Android package

`com.moko.ft.lw012ct`

## Protocol layer

Dart package: `lw012ct_flutter`

BLE modules live under `lib/ble/lw012_*.dart`.
