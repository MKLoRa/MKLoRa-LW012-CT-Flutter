import 'package:flutter/material.dart';

import '../../../../../../ble/lw012_device_session.dart';
import '../../../../../../ble/lw012_option_lists.dart';
import '../../../../../../ble/lw012_param_helpers.dart';
import '../../../../../../ble/lw012_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

/// Motion Mode settings — aligned with native [MotionModeActivity] / lw012_activity_motion_mode.xml.
class MotionModePage extends StatefulWidget {
  const MotionModePage({super.key, required this.session});
  final Lw012DeviceSession session;

  @override
  State<MotionModePage> createState() => _MotionModePageState();
}

class _MotionModePageState extends State<MotionModePage> {
  bool _fixOnStart = false;
  bool _fixInTrip = false;
  bool _fixOnEnd = false;
  bool _fixOnStationary = false;
  bool _notifyOnStart = false;
  bool _notifyInTrip = false;
  bool _notifyOnEnd = false;

  int _startStrategy = 0;
  int _tripStrategy = 0;
  int _endStrategy = 0;
  int _stationaryStrategy = 0;

  final _fixOnStartNumber = TextEditingController();
  final _reportIntervalInTrip = TextEditingController();
  final _tripEndTimeout = TextEditingController();
  final _fixOnEndNumber = TextEditingController();
  final _reportIntervalOnEnd = TextEditingController();
  final _reportIntervalOnStationary = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final startEnable = await api.readMotionModeStartEnable();
      final startFix = await api.readMotionModeStartFixEnable();
      final startNumber = await api.readMotionModeStartNumber();
      final startStrategy = await api.readMotionModeStartPosStrategy();
      final tripEnable = await api.readMotionModeTripEnable();
      final tripFix = await api.readMotionModeTripFixEnable();
      final tripInterval = await api.readMotionModeTripReportInterval();
      final tripStrategy = await api.readMotionModeTripPosStrategy();
      final endEnable = await api.readMotionModeEndEnable();
      final endFix = await api.readMotionModeEndFixEnable();
      final endTimeout = await api.readMotionModeEndTimeout();
      final endNumber = await api.readMotionModeEndNumber();
      final endInterval = await api.readMotionModeEndReportInterval();
      final endStrategy = await api.readMotionModeEndPosStrategy();
      final stationaryFix = await api.readMotionModeStationaryFixEnable();
      final stationaryInterval = await api.readMotionModeStationaryReportInterval();
      final stationaryStrategy = await api.readMotionModeStationaryPosStrategy();
      if (!mounted) return;
      _notifyOnStart = Lw012ParamHelpers.uint8(startEnable.data) == 1;
      _fixOnStart = Lw012ParamHelpers.uint8(startFix.data) == 1;
      _fixOnStartNumber.text = Lw012ParamHelpers.uint8(startNumber.data).toString();
      _startStrategy = Lw012ParamHelpers.uint8(startStrategy.data).clamp(0, 3);
      _notifyInTrip = Lw012ParamHelpers.uint8(tripEnable.data) == 1;
      _fixInTrip = Lw012ParamHelpers.uint8(tripFix.data) == 1;
      _reportIntervalInTrip.text = Lw012ParamHelpers.int32(tripInterval.data).toString();
      _tripStrategy = Lw012ParamHelpers.uint8(tripStrategy.data).clamp(0, 4);
      _notifyOnEnd = Lw012ParamHelpers.uint8(endEnable.data) == 1;
      _fixOnEnd = Lw012ParamHelpers.uint8(endFix.data) == 1;
      _tripEndTimeout.text = Lw012ParamHelpers.uint8(endTimeout.data).toString();
      _fixOnEndNumber.text = Lw012ParamHelpers.uint8(endNumber.data).toString();
      _reportIntervalOnEnd.text =
          Lw012ParamHelpers.bytesToInt(endInterval.data).toString();
      _endStrategy = Lw012ParamHelpers.uint8(endStrategy.data).clamp(0, 3);
      _fixOnStationary = Lw012ParamHelpers.uint8(stationaryFix.data) == 1;
      _reportIntervalOnStationary.text =
          Lw012ParamHelpers.bytesToInt(stationaryInterval.data).toString();
      _stationaryStrategy = Lw012ParamHelpers.uint8(stationaryStrategy.data).clamp(0, 3);
      setState(() {});
    });
  }

  bool _validate() {
    final startNumber = int.tryParse(_fixOnStartNumber.text.trim());
    final tripInterval = int.tryParse(_reportIntervalInTrip.text.trim());
    final endTimeout = int.tryParse(_tripEndTimeout.text.trim());
    final endNumber = int.tryParse(_fixOnEndNumber.text.trim());
    final endInterval = int.tryParse(_reportIntervalOnEnd.text.trim());
    final stationaryInterval = int.tryParse(_reportIntervalOnStationary.text.trim());
    if (startNumber == null || startNumber < 1 || startNumber > 10) return false;
    if (tripInterval == null || tripInterval < 10 || tripInterval > 86400) return false;
    if (endTimeout == null || endTimeout < 1 || endTimeout > 180) return false;
    if (endNumber == null || endNumber < 1 || endNumber > 10) return false;
    if (endInterval == null || endInterval < 10 || endInterval > 300) return false;
    if (stationaryInterval == null || stationaryInterval < 1 || stationaryInterval > 14400) {
      return false;
    }
    return true;
  }

  Future<bool> _writeAll() async {
    final api = widget.session.protocol;
    final startNumber = int.parse(_fixOnStartNumber.text.trim());
    final tripInterval = int.parse(_reportIntervalInTrip.text.trim());
    final endTimeout = int.parse(_tripEndTimeout.text.trim());
    final endNumber = int.parse(_fixOnEndNumber.text.trim());
    final endInterval = int.parse(_reportIntervalOnEnd.text.trim());
    final stationaryInterval = int.parse(_reportIntervalOnStationary.text.trim());

    final steps = <Future<bool> Function()>[
      () => api.writeMotionModeStartEnable([_notifyOnStart ? 1 : 0]),
      () => api.writeMotionModeStartFixEnable([_fixOnStart ? 1 : 0]),
      () => api.writeMotionModeStartNumber([startNumber]),
      () => api.writeMotionModeStartPosStrategy([_startStrategy]),
      () => api.writeMotionModeTripEnable([_notifyInTrip ? 1 : 0]),
      () => api.writeMotionModeTripFixEnable([_fixInTrip ? 1 : 0]),
      () => api.writeMotionModeTripReportInterval(
            Lw012ParamHelpers.int32Bytes(tripInterval),
          ),
      () => api.writeMotionModeTripPosStrategy([_tripStrategy]),
      () => api.writeMotionModeEndEnable([_notifyOnEnd ? 1 : 0]),
      () => api.writeMotionModeEndFixEnable([_fixOnEnd ? 1 : 0]),
      () => api.writeMotionModeEndTimeout([endTimeout]),
      () => api.writeMotionModeEndNumber([endNumber]),
      () => api.writeMotionModeEndReportInterval(
            Lw012ParamHelpers.uint16Bytes(endInterval),
          ),
      () => api.writeMotionModeEndPosStrategy([_endStrategy]),
      () => api.writeMotionModeStationaryFixEnable([_fixOnStationary ? 1 : 0]),
      () => api.writeMotionModeStationaryReportInterval(
            Lw012ParamHelpers.uint16Bytes(stationaryInterval),
          ),
      () => api.writeMotionModeStationaryPosStrategy([_stationaryStrategy]),
    ];
    for (final step in steps) {
      if (!await step()) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    await runWithBleLoading(context, () async {
      final ok = await _writeAll();
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _pickStrategy(
    List<String> options,
    int selected,
    ValueChanged<int> onSelected,
  ) async {
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: selected,
    );
    if (index != null) setState(() => onSelected(index));
  }

  Widget _sectionCard(List<Widget> children) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _fieldRow({
    required String label,
    required Widget child,
    bool topSpacing = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing ? 10 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topSpacing) const SettingsDivider(),
          SettingsLabelRow(label: label, child: child),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fixOnStartNumber.dispose();
    _reportIntervalInTrip.dispose();
    _tripEndTimeout.dispose();
    _fixOnEndNumber.dispose();
    _reportIntervalOnEnd.dispose();
    _reportIntervalOnStationary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Motion Mode',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _sectionCard([
            SettingsSwitchRow(
              label: 'Fix On Start',
              value: _fixOnStart,
              onChanged: (v) => setState(() => _fixOnStart = v),
            ),
            _fieldRow(
              label: 'Number Of Fix On Start',
              topSpacing: true,
              child: SettingsTextField(
                controller: _fixOnStartNumber,
                hint: '1~10',
                maxLength: 2,
                width: 80,
              ),
            ),
            _fieldRow(
              label: 'Pos-Strategy On Start',
              topSpacing: true,
              child: BlueValueButton(
                text: Lw012OptionLists.posStrategy4[_startStrategy],
                onTap: () => _pickStrategy(
                  Lw012OptionLists.posStrategy4,
                  _startStrategy,
                  (i) => _startStrategy = i,
                ),
              ),
            ),
          ]),
          _sectionCard([
            SettingsSwitchRow(
              label: 'Fix In Trip',
              value: _fixInTrip,
              onChanged: (v) => setState(() => _fixInTrip = v),
            ),
            _fieldRow(
              label: 'Report Interval In Trip',
              topSpacing: true,
              child: SettingsTextField(
                controller: _reportIntervalInTrip,
                hint: '10~86400',
                maxLength: 5,
                width: 100,
                suffix: 's',
              ),
            ),
            _fieldRow(
              label: 'Pos-Strategy In Trip',
              topSpacing: true,
              child: BlueValueButton(
                text: Lw012OptionLists.posStrategy5[_tripStrategy],
                onTap: () => _pickStrategy(
                  Lw012OptionLists.posStrategy5,
                  _tripStrategy,
                  (i) => _tripStrategy = i,
                ),
              ),
            ),
          ]),
          _sectionCard([
            SettingsSwitchRow(
              label: 'Fix On End',
              value: _fixOnEnd,
              onChanged: (v) => setState(() => _fixOnEnd = v),
            ),
            _fieldRow(
              label: 'Trip End Timeout',
              topSpacing: true,
              child: SettingsTextField(
                controller: _tripEndTimeout,
                hint: '1~180',
                maxLength: 3,
                width: 80,
                suffix: 'x10s',
              ),
            ),
            _fieldRow(
              label: 'Number Of Fix On End',
              topSpacing: true,
              child: SettingsTextField(
                controller: _fixOnEndNumber,
                hint: '1~10',
                maxLength: 3,
                width: 80,
              ),
            ),
            _fieldRow(
              label: 'Report Interval On End',
              topSpacing: true,
              child: SettingsTextField(
                controller: _reportIntervalOnEnd,
                hint: '10~300',
                maxLength: 3,
                width: 80,
                suffix: 's',
              ),
            ),
            _fieldRow(
              label: 'Pos-Strategy On End',
              topSpacing: true,
              child: BlueValueButton(
                text: Lw012OptionLists.posStrategy4[_endStrategy],
                onTap: () => _pickStrategy(
                  Lw012OptionLists.posStrategy4,
                  _endStrategy,
                  (i) => _endStrategy = i,
                ),
              ),
            ),
          ]),
          _sectionCard([
            SettingsSwitchRow(
              label: 'Fix On Stationary State',
              value: _fixOnStationary,
              onChanged: (v) => setState(() => _fixOnStationary = v),
            ),
            _fieldRow(
              label: 'Report Interval On Stationary',
              topSpacing: true,
              child: SettingsTextField(
                controller: _reportIntervalOnStationary,
                hint: '1~14400',
                maxLength: 5,
                width: 80,
                suffix: 'Mins',
              ),
            ),
            _fieldRow(
              label: 'Pos-Strategy On Stationary',
              topSpacing: true,
              child: BlueValueButton(
                text: Lw012OptionLists.posStrategy4[_stationaryStrategy],
                onTap: () => _pickStrategy(
                  Lw012OptionLists.posStrategy4,
                  _stationaryStrategy,
                  (i) => _stationaryStrategy = i,
                ),
              ),
            ),
          ]),
          _sectionCard([
            SettingsSwitchRow(
              label: 'Notify Event On Start',
              value: _notifyOnStart,
              onChanged: (v) => setState(() => _notifyOnStart = v),
            ),
            const SettingsDivider(),
            SettingsSwitchRow(
              label: 'Notify Event In Trip',
              value: _notifyInTrip,
              onChanged: (v) => setState(() => _notifyInTrip = v),
            ),
            const SettingsDivider(),
            SettingsSwitchRow(
              label: 'Notify Event On End',
              value: _notifyOnEnd,
              onChanged: (v) => setState(() => _notifyOnEnd = v),
            ),
          ]),
        ],
      ),
    );
  }
}
