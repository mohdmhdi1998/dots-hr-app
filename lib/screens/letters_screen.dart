import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/ui.dart';

class LettersScreen extends StatefulWidget {
  const LettersScreen({super.key});

  @override
  State<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends State<LettersScreen> {
  final _loader = GlobalKey<LoaderState>();
  List<Map<String, dynamic>> _templates = [];

  Future<void> _new() async {
    if (_templates.isEmpty) {
      toast(context, 'لا توجد خطابات متاحة للطلب حاليًا.', error: true);
      return;
    }
    int? templateId;
    final purpose = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setLocal) {
        return AlertDialog(
          title: const Text('طلب خطاب'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: templateId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع الخطاب'),
              items: _templates.map((t) => DropdownMenuItem(value: intOf(t['id']), child: Text(str(t['name'])))).toList(),
              onChanged: (v) => setLocal(() => templateId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: purpose, maxLines: 2, decoration: const InputDecoration(labelText: 'الجهة أو الغرض (اختياري)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: templateId == null ? null : () => Navigator.pop(c, true), child: const Text('طلب')),
          ],
        );
      }),
    );
    if (ok != true || !mounted) return;
    final done = await runAction(context, () => Api.instance.post('letters', data: {
          'letter_template_id': templateId,
          if (purpose.text.trim().isNotEmpty) 'purpose': purpose.text.trim(),
        }));
    if (done) _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخطابات الرسمية')),
      floatingActionButton: ActionFab(label: 'طلب خطاب', onPressed: _new),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('letters')).map,
        builder: (context, data, reload) {
          final d = mapOf(data);
          _templates = listOf(d['templates']);
          final letters = listOf(d['letters']);
          return RefreshList(onRefresh: reload, padding: const EdgeInsets.only(top: 8, bottom: 90), children: [
            if (letters.isEmpty) const EmptyView(icon: Icons.mail_outline, text: 'اطلب شهادة راتب أو خطاب تعريف أو شهادة خبرة من الزر بالأسفل.'),
            ...letters.map((l) => ItemTile(
                  icon: Icons.mail_outline,
                  iconColor: statusColor(str(l['status'], '')),
                  title: str(l['template']),
                  subtitle: '${str(l['number'])} · ${fmtDate(l['created_at'])}${l['purpose'] != null ? '\n${str(l['purpose'])}' : ''}',
                  trailing: StatusBadge(str(l['status_label']), status: str(l['status'], '')),
                  onTap: () => openPage(context, LetterScreen(id: intOf(l['id']))),
                )),
          ]);
        },
      ),
    );
  }
}

class LetterScreen extends StatelessWidget {
  final int id;

  const LetterScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخطاب')),
      body: Loader(
        load: () async => (await Api.instance.get('letters/$id')).map,
        builder: (context, data, reload) {
          final l = mapOf(data);
          return RefreshList(onRefresh: reload, children: [
            SectionCard(
              title: str(l['template']),
              trailing: StatusBadge(str(l['status_label']), status: str(l['status'], '')),
              child: Column(children: [
                InfoRow('رقم الطلب', str(l['number'])),
                InfoRow('التاريخ', fmtDate(l['created_at'])),
                if (l['purpose'] != null) InfoRow('الغرض', str(l['purpose'])),
                if (l['rejection_reason'] != null) InfoRow('سبب الرفض', str(l['rejection_reason'])),
              ]),
            ),
            if (l['content'] != null)
              SectionCard(title: 'نص الخطاب', child: SelectableText(str(l['content']), style: const TextStyle(height: 1.8)))
            else
              const EmptyView(icon: Icons.hourglass_top, text: 'يظهر نص الخطاب هنا بعد اعتماده، وتستلم النسخة المختومة من الموارد البشرية.'),
          ]);
        },
      ),
    );
  }
}
