import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/ui.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _loader = GlobalKey<LoaderState>();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      Api.instance.get('attendance/today'),
      Api.instance.get('attendance', query: {'month': _month.month, 'year': _month.year}),
    ]);
    return {'today': results[0].map, 'month': results[1].map};
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw ApiError('فعّل خدمة الموقع (GPS) في جهازك ثم حاول مجددًا.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw ApiError('اسمح للتطبيق بالوصول إلى موقعك لتسجيل الحضور من الإعدادات.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
    );
  }

  Future<void> _punch(bool checkIn) async {
    setState(() => _busy = true);
    try {
      final pos = await _position();
      final result = await Api.instance.post(checkIn ? 'attendance/check-in' : 'attendance/check-out',
          data: {'latitude': pos.latitude, 'longitude': pos.longitude});
      if (mounted) toast(context, result.message);
      await _loader.currentState?.reload();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'تعذّر تحديد موقعك. حاول في مكان مفتوح.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = _month.year == DateTime.now().year && _month.month == DateTime.now().month;
    return Scaffold(
      appBar: AppBar(title: const Text('الحضور والانصراف')),
      body: Loader(
        key: _loader,
        load: _load,
        builder: (context, data, reload) {
          final today = mapOf(mapOf(data)['today']);
          final month = mapOf(mapOf(data)['month']);
          final stats = mapOf(month['stats']);
          final records = listOf(month['records']);
          final shift = today['shift'] == null ? null : mapOf(today['shift']);
          final checkedIn = today['check_in'] != null;
          final checkedOut = today['check_out'] != null;
          return RefreshList(onRefresh: reload, children: [
            SectionCard(
              title: 'اليوم · ${fmtDate(today['date'])}',
              trailing: today['status_label'] == null ? null : StatusBadge(str(today['status_label']), status: str(today['status'], '')),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (shift != null) InfoRow('الوردية', '${str(shift['name'])} (${str(shift['start'])} – ${str(shift['end'])})'),
                if (boolOf(today['day_off'])) const InfoRow('اليوم', 'يوم راحة أو عطلة رسمية'),
                const SizedBox(height: 8),
                Row(children: [
                  StatBox(str(today['check_in'], '--:--'), 'الحضور', color: checkedIn ? AppColors.success : AppColors.textSecondary),
                  StatBox(str(today['check_out'], '--:--'), 'الانصراف', color: checkedOut ? AppColors.info : AppColors.textSecondary),
                ]),
                const SizedBox(height: 14),
                if (!checkedOut)
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _punch(!checkedIn),
                    icon: _busy ? const Busy() : const Icon(Icons.my_location),
                    label: Text(checkedIn ? 'تسجيل الانصراف' : 'تسجيل الحضور'),
                  )
                else
                  const Text('اكتمل تسجيل اليوم.', textAlign: TextAlign.center),
                if (listOf(today['locations']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('يُقبل التسجيل من: ${listOf(today['locations']).map((l) => str(l['name'])).join('، ')}',
                        style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_right)),
                Expanded(child: Text('${monthName(_month.month)} ${_month.year}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: isCurrent ? null : () => _shiftMonth(1), icon: const Icon(Icons.chevron_left)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                StatBox('${intOf(stats['days'])}', 'يوم حضور', color: AppColors.success),
                StatBox('${intOf(stats['late'])}', 'تأخير', color: const Color(0xFFEA7317)),
                StatBox('${intOf(stats['absent'])}', 'غياب', color: AppColors.error),
              ]),
            ),
            const SizedBox(height: 8),
            if (records.isEmpty) const EmptyView(icon: Icons.event_busy, text: 'لا توجد سجلات في هذا الشهر.'),
            ...records.map((r) => ItemTile(
                  icon: Icons.calendar_today_outlined,
                  iconColor: statusColor(str(r['status'], '')),
                  title: fmtDate(r['date']),
                  subtitle: 'حضور ${str(r['check_in'], '--:--')} · انصراف ${str(r['check_out'], '--:--')}'
                      '${intOf(r['late_minutes']) > 0 ? ' · تأخير ${intOf(r['late_minutes'])} د' : ''}',
                  trailing: StatusBadge(str(r['status_label']), status: str(r['status'], '')),
                )),
          ]);
        },
      ),
    );
  }
}
