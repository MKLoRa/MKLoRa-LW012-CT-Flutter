import 'package:flutter/material.dart';

import '../../../../../ble/lw012.dart';
import '../../../../../ble/lw012_device_session.dart';
import '../../../../../ble/lw012_param_helpers.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device/export_data_page.dart';
import '../device/indicator_settings_page.dart';
import '../device/on_off_settings_page.dart';
import '../device/system_info_page.dart';

class DeviceTab extends StatefulWidget {
  const DeviceTab({super.key, required this.session, required this.onSaveReady});

  final Lw012DeviceSession session;
  final void Function(Future<bool> Function() save) onSaveReady;

  @override
  State<DeviceTab> createState() => DeviceTabState();
}

class DeviceTabState extends State<DeviceTab> {
  int _timeZoneIndex = 40;
  bool _lowPowerPayload = true;
  final _reportIntervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSaveReady(_save);
  }

  Future<void> reload({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final timeZone = await api.readTimeZone();
        final payload = await api.readLowPowerPayloadEnable();
        final interval = await api.readLowPowerReportInterval();
        if (!mounted) return;
        setState(() {
          _timeZoneIndex = Lw012ParamHelpers.timeZoneIndexFromBytes(timeZone.data);
          _lowPowerPayload = Lw012ParamHelpers.uint8(payload.data) == 1;
          _reportIntervalController.text =
              Lw012ParamHelpers.uint8(interval.data).toString();
        });
      },
      showOverlay: showOverlay,
    );
  }

  Future<bool> _save() async {
    final intervalText = _reportIntervalController.text.trim();
    final interval = int.tryParse(intervalText);
    if (interval == null || interval < 1 || interval > 255) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Low-power report interval must be 1~255')),
        );
      }
      return false;
    }
    final api = widget.session.protocol;
    final results = await Future.wait([
      api.writeTimeZone(Lw012ParamHelpers.timeZoneBytesFromIndex(_timeZoneIndex)),
      api.writeLowPowerPayloadEnable([_lowPowerPayload ? 1 : 0]),
      api.writeLowPowerReportInterval([interval]),
    ]);
    return results.every((r) => r);
  }

  Future<void> _pickTimeZone() async {
    final zones = Lw012OptionLists.timeZones();
    final index = await showBottomPicker(
      context: context,
      options: zones,
      selectedIndex: _timeZoneIndex,
    );
    if (index != null) setState(() => _timeZoneIndex = index);
  }

  Future<void> _factoryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      message: 'Are you sure you want to factory reset?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeResetEmpty());
  }

  @override
  void dispose() {
    _reportIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zones = Lw012OptionLists.timeZones();
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsNavRow(
            title: 'Local Data Sync',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExportDataPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Indicator Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IndicatorSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Current Time Zone',
            child: BlueValueButton(
              text: zones[_timeZoneIndex.clamp(0, zones.length - 1)],
              onTap: _pickTimeZone,
            ),
          ),
        ),
        SettingsCard(
          child: Column(
            children: [
              SettingsCheckboxRow(
                label: 'Low-power Payload',
                value: _lowPowerPayload,
                onChanged: (v) => setState(() => _lowPowerPayload = v ?? false),
              ),
              const SizedBox(height: 16),
              SettingsLabelRow(
                label: 'Low-power Report Interval',
                child: SettingsTextField(
                  controller: _reportIntervalController,
                  hint: '1~255',
                  maxLength: 3,
                  width: 80,
                  suffix: 'x30mins',
                ),
              ),
            ],
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'On/Off Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OnOffSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Device Information',
            onTap: () async {
              final result = await Navigator.of(context).push<SystemInfoDfuResult>(
                MaterialPageRoute(
                  builder: (_) => SystemInfoPage(session: widget.session),
                ),
              );
              if (!context.mounted) return;
              if (result == SystemInfoDfuResult.success ||
                  result == SystemInfoDfuResult.failed) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Factory Reset',
            onTap: _factoryReset,
          ),
        ),
      ],
    );
  }
}
