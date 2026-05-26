import 'package:flutter/material.dart';

import '../../../../../../ble/lw012_device_session.dart';
import '../../../../../../ble/lw012_param_helpers.dart';
import '../../../../../../ble/lw012_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class AlarmFunctionPage extends StatefulWidget {
  const AlarmFunctionPage({super.key, required this.session});
  final Lw012DeviceSession session;

  @override
  State<AlarmFunctionPage> createState() => _AlarmFunctionPageState();
}

class _AlarmFunctionPageState extends State<AlarmFunctionPage> {
  bool _enabled = false;
  final _threshold = TextEditingController();
  final _interval = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readTamperAlarmEnable(),
        api.readTamperAlarmThreshold(),
        api.readTamperAlarmReportInterval(),
      ]);
      if (!mounted) return;
      _enabled = Lw012ParamHelpers.uint8(results[0].data) == 1;
      _threshold.text = Lw012ParamHelpers.uint8(results[1].data).toString();
      _interval.text = Lw012ParamHelpers.uint16(results[2].data).toString();
      setState(() {});
    });
  }

  bool _validate() {
    final threshold = int.tryParse(_threshold.text.trim());
    final interval = int.tryParse(_interval.text.trim());
    if (threshold == null || threshold < 10 || threshold > 200) return false;
    if (interval == null || interval < 1 || interval > 14400) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Para error!')));
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeTamperAlarmEnable([_enabled ? 1 : 0]),
        api.writeTamperAlarmThreshold([int.parse(_threshold.text.trim())]),
        api.writeTamperAlarmReportInterval(
          Lw012ParamHelpers.uint16Bytes(int.parse(_interval.text.trim())),
        ),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _threshold.dispose();
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Tamper Alarm Function',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsSwitchRow(
              label: 'Tamper Alarm Enable',
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Threshold',
              child: SettingsTextField(controller: _threshold, hint: '10~200', suffix: ''),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Report Interval',
              child: SettingsTextField(controller: _interval, hint: '1~14400', suffix: 's'),
            ),
          ),
        ],
      ),
    );
  }
}
