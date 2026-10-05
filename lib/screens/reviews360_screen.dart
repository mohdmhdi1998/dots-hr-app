import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/ui.dart';

class Reviews360Screen extends StatelessWidget {
  const Reviews360Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييمات 360')),
      body: Loader(
        load: () async => (await Api.instance.get('reviews-360')).map,
        builder: (context, data, reload) {
          final rows = listOf(mapOf(data)['reviews']);
          return RefreshList(onRefresh: reload, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('رأيك في أداء زملائك يساعدهم على التطور. لا يظهر اسمك للموظف المقيَّم.'),
            ),
            if (rows.isEmpty) const EmptyView(icon: Icons.donut_large_outlined, text: 'لا توجد تقييمات مطلوبة منك.'),
            ...rows.map((r) => ItemTile(
                  icon: Icons.donut_large_outlined,
                  iconColor: statusColor(r['status'] == 'pending' ? 'pending' : 'submitted'),
                  title: str(r['employee']),
                  subtitle: '${str(r['reviewer_type_label'])} · ${str(r['cycle'])}${r['due_date'] != null ? ' · حتى ${fmtDate(r['due_date'])}' : ''}',
                  trailing: Text(str(r['status_label']), style: Theme.of(context).textTheme.bodySmall),
                  onTap: () async {
                    await openPage(context, Review360Screen(id: intOf(r['id'])));
                    reload();
                  },
                )),
          ]);
        },
      ),
    );
  }
}

class Review360Screen extends StatefulWidget {
  final int id;

  const Review360Screen({super.key, required this.id});

  @override
  State<Review360Screen> createState() => _Review360ScreenState();
}

class _Review360ScreenState extends State<Review360Screen> {
  final Map<String, int> _scores = {};
  int? _overall;
  final _strengths = TextEditingController();
  final _improvements = TextEditingController();
  final _comments = TextEditingController();
  bool _busy = false;

  Future<void> _submit(List<Map<String, dynamic>> competencies) async {
    if (_scores.length < competencies.length || _overall == null) {
      toast(context, 'قيّم كل الكفاءات وضع تقييمًا عامًا.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('reviews-360/${widget.id}', data: {
        'criteria_scores': _scores,
        'overall_rating': _overall,
        'strengths': _strengths.text.trim(),
        'improvements': _improvements.text.trim(),
        'comments': _comments.text.trim(),
      });
      if (!mounted) return;
      toast(context, r.message);
      Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stars(int? value, ValueChanged<int> onChanged, {bool enabled = true}) {
    return Row(
      children: List.generate(5, (i) {
        final filled = value != null && i < value;
        return IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: enabled ? () => onChanged(i + 1) : null,
          icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF5A623), size: 30),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييم 360')),
      body: Loader(
        load: () async => (await Api.instance.get('reviews-360/${widget.id}')).map,
        builder: (context, data, reload) {
          final r = mapOf(data);
          final competencies = listOf(r['competencies']);
          final done = r['status'] != 'pending';
          return ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
            SectionCard(
              title: str(r['employee']),
              child: Column(children: [
                InfoRow('القسم', str(r['department'])),
                InfoRow('صفتك', str(r['reviewer_type_label'])),
                InfoRow('الدورة', str(r['cycle'])),
              ]),
            ),
            ...competencies.map((c) {
              final key = str(c['key']);
              final value = done ? (c['score'] == null ? null : intOf(c['score'])) : _scores[key];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(c['label']), style: Theme.of(context).textTheme.titleMedium),
                    _stars(value, (v) => setState(() => _scores[key] = v), enabled: !done),
                  ]),
                ),
              );
            }),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('التقييم العام', style: Theme.of(context).textTheme.titleLarge),
                  _stars(done ? (r['overall_rating'] == null ? null : intOf(r['overall_rating'])) : _overall, (v) => setState(() => _overall = v), enabled: !done),
                ]),
              ),
            ),
            if (done)
              SectionCard(
                title: 'ملاحظاتك',
                child: Column(children: [
                  InfoRow('نقاط القوة', str(r['strengths'])),
                  InfoRow('جوانب التحسين', str(r['improvements'])),
                  InfoRow('تعليقات', str(r['comments'])),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(controller: _strengths, maxLines: 2, decoration: const InputDecoration(labelText: 'نقاط القوة')),
                  const SizedBox(height: 12),
                  TextField(controller: _improvements, maxLines: 2, decoration: const InputDecoration(labelText: 'جوانب التحسين')),
                  const SizedBox(height: 12),
                  TextField(controller: _comments, maxLines: 2, decoration: const InputDecoration(labelText: 'تعليق إضافي (اختياري)')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _busy ? null : () => _submit(competencies), child: _busy ? const Busy() : const Text('إرسال التقييم')),
                  ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
