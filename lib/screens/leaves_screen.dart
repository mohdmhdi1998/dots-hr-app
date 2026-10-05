import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/ui.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  final _loader = GlobalKey<LoaderState>();
  Map<String, dynamic> _data = {};

  Future<void> _new() async {
    final done = await openPage<bool>(context, LeaveFormScreen(types: listOf(_data['types']), balances: listOf(_data['balances'])));
    if (done == true) _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإجازات')),
      floatingActionButton: ActionFab(label: 'طلب إجازة', onPressed: _new),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('leaves')).map,
        builder: (context, data, reload) {
          _data = mapOf(data);
          final leaves = listOf(_data['leaves']);
          final balances = listOf(_data['balances']);
          return RefreshList(onRefresh: reload, padding: const EdgeInsets.only(top: 8, bottom: 90), children: [
            if (balances.isNotEmpty)
              SectionCard(
                title: 'أرصدتي ${DateTime.now().year}',
                child: Column(
                  children: balances
                      .map((b) => InfoRow(str(b['name']),
                          '${num1(b['remaining'])} متبقٍ · ${num1(b['used'])} مستخدم${numOf(b['pending']) > 0 ? ' · ${num1(b['pending'])} محجوز' : ''}'))
                      .toList(),
                ),
              ),
            if (leaves.isEmpty) const EmptyView(icon: Icons.beach_access_outlined, text: 'لم تقدّم أي طلب إجازة بعد.'),
            ...leaves.map((l) => ItemTile(
                  icon: Icons.beach_access_outlined,
                  iconColor: statusColor(str(l['status'], '')),
                  title: '${str(l['leave_type'])} · ${num1(l['days'])} يوم',
                  subtitle: '${fmtDate(l['start_date'], year: false)} ← ${fmtDate(l['end_date'])}'
                      '${l['rejection_reason'] != null ? '\nالسبب: ${str(l['rejection_reason'])}' : ''}',
                  trailing: StatusBadge(str(l['status_label']), status: str(l['status'], '')),
                  onTap: () => _details(l, reload),
                )),
          ]);
        },
      ),
    );
  }

  void _details(Map<String, dynamic> l, Future<void> Function() reload) {
    final canCancel = ['pending', 'returned'].contains(l['status']);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(str(l['leave_type']), style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 12),
            InfoRow('الحالة', str(l['status_label'])),
            InfoRow('من', fmtDate(l['start_date'])),
            InfoRow('إلى', fmtDate(l['end_date'])),
            InfoRow('عدد الأيام', num1(l['days'])),
            if (l['reason'] != null) InfoRow('السبب', str(l['reason'])),
            if (l['rejection_reason'] != null) InfoRow('ملاحظة الموارد البشرية', str(l['rejection_reason'])),
            if (canCancel) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء الطلب'),
                onPressed: () async {
                  Navigator.pop(c);
                  if (!await confirm(context, 'إلغاء الطلب', 'تُعاد الأيام المحجوزة إلى رصيدك.', ok: 'إلغاء الطلب')) return;
                  if (!mounted) return;
                  if (await runAction(context, () => Api.instance.post('leaves/${l['id']}/cancel'))) reload();
                },
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class LeaveFormScreen extends StatefulWidget {
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> balances;

  const LeaveFormScreen({super.key, required this.types, required this.balances});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  int? _typeId;
  DateTime? _start;
  DateTime? _end;
  bool _half = false;
  final _reason = TextEditingController();
  XFile? _attachment;
  bool _busy = false;

  Map<String, dynamic> get _type => widget.types.firstWhere((t) => intOf(t['id']) == _typeId, orElse: () => {});
  Map<String, dynamic> get _balance => widget.balances.firstWhere((b) => intOf(b['leave_type_id']) == _typeId, orElse: () => {});

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? _start ?? now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end == null || _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
      if (_start != _end) _half = false;
    });
  }

  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('تصوير'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('من الصور'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1800);
    if (file != null) setState(() => _attachment = file);
  }

  Future<void> _submit() async {
    if (_typeId == null || _start == null || _end == null) {
      toast(context, 'اختر نوع الإجازة وتاريخيها.', error: true);
      return;
    }
    setState(() => _busy = true);
    final fields = <String, dynamic>{
      'leave_type_id': _typeId,
      'start_date': apiDate(_start!),
      'end_date': apiDate(_end!),
      'is_half_day': _half ? 1 : 0,
      if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
    };
    try {
      final body = _attachment == null
          ? fields
          : FormData.fromMap({...fields, 'attachment': await MultipartFile.fromFile(_attachment!.path, filename: _attachment!.name)});
      final result = await Api.instance.post('leaves', data: body);
      if (!mounted) return;
      toast(context, result.message);
      Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameDay = _start != null && _start == _end;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب إجازة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<int>(
          initialValue: _typeId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'نوع الإجازة'),
          items: widget.types.map((t) => DropdownMenuItem(value: intOf(t['id']), child: Text(str(t['name'])))).toList(),
          onChanged: (v) => setState(() {
            _typeId = v;
            _half = false;
          }),
        ),
        if (_balance.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: Text('رصيدك المتاح: ${num1(_balance['remaining'])} يوم', style: const TextStyle(color: AppColors.info)),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _dateField('من', _start, () => _pickDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _dateField('إلى', _end, () => _pickDate(false))),
        ]),
        if (sameDay && boolOf(_type['half_day']))
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _half, onChanged: (v) => setState(() => _half = v), title: const Text('نصف يوم')),
        const SizedBox(height: 16),
        TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'السبب (اختياري)')),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickAttachment,
          icon: const Icon(Icons.attach_file),
          label: Text(_attachment == null
              ? (boolOf(_type['requires_attachment']) ? 'إرفاق مستند (مطلوب)' : 'إرفاق مستند (اختياري)')
              : 'تم إرفاق: ${_attachment!.name}'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _busy ? null : _submit, child: _busy ? const Busy() : const Text('تقديم الطلب')),
        const SizedBox(height: 8),
        Text('تُحجز الأيام من رصيدك حتى يُبت في الطلب.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event)),
        child: Text(value == null ? 'اختر' : fmtDate(apiDate(value))),
      ),
    );
  }
}
