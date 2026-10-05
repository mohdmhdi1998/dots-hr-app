import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/ui.dart';

class AppraisalsScreen extends StatelessWidget {
  const AppraisalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييم الأداء')),
      body: Loader(
        load: () async => (await Api.instance.get('appraisals')).map,
        builder: (context, data, reload) {
          final d = mapOf(data);
          final own = listOf(d['own']);
          final team = listOf(d['team']);
          Widget tile(Map<String, dynamic> a, bool mine) => ItemTile(
                icon: mine ? Icons.insights_outlined : Icons.person_search_outlined,
                iconColor: boolOf(a['needs_action']) ? AppColors.accent : AppColors.primary,
                title: mine ? str(a['cycle']) : str(a['employee_name']),
                subtitle: [if (!mine) str(a['cycle']), str(a['status_label']), if (a['grade_label'] != null) '${num1(a['total_percentage'])}% · ${str(a['grade_label'])}']
                    .join(' · '),
                onTap: () async {
                  await openPage(context, AppraisalScreen(id: intOf(a['id'])));
                  reload();
                },
              );
          return RefreshList(onRefresh: reload, children: [
            if (team.isNotEmpty) ...[
              const _Header('أقيّمهم'),
              ...team.map((a) => tile(a, false)),
            ],
            const _Header('تقييماتي'),
            if (own.isEmpty) const EmptyView(icon: Icons.insights_outlined, text: 'لا توجد تقييمات بعد.'),
            ...own.map((a) => tile(a, true)),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;

  const _Header(this.text);

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: Text(text, style: Theme.of(context).textTheme.titleLarge));
}

/// One appraisal: result, self-assessment form, acknowledgement, or the manager's rating form.
class AppraisalScreen extends StatefulWidget {
  final int id;

  const AppraisalScreen({super.key, required this.id});

  @override
  State<AppraisalScreen> createState() => _AppraisalScreenState();
}

class _AppraisalScreenState extends State<AppraisalScreen> {
  final _loader = GlobalKey<LoaderState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييم الأداء')),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('appraisals/${widget.id}')).map,
        builder: (context, data, reload) {
          final a = mapOf(data);
          final criteria = listOf(a['criteria']);
          final goals = listOf(a['goals']);
          final manager = a['role'] == 'manager';
          return RefreshList(onRefresh: reload, children: [
            SectionCard(
              title: manager ? str(mapOf(a['employee'])['name']) : str(a['cycle']),
              trailing: StatusBadge(str(a['status_label']), status: str(a['status'], '')),
              child: Column(children: [
                if (manager) InfoRow('الدورة', str(a['cycle'])),
                InfoRow('الفترة', str(a['period'])),
                if (!manager && a['appraiser_name'] != null) InfoRow('المقيِّم', str(a['appraiser_name'])),
                if (a['self_due'] != null && boolOf(a['can_self'])) InfoRow('آخر موعد للتقييم الذاتي', fmtDate(a['self_due'])),
              ]),
            ),
            if (a['total_percentage'] != null)
              Card(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text('${num1(a['total_percentage'])}%', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
                    Text(str(a['grade_label']), style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ]),
                ),
              ),
            if (criteria.isNotEmpty)
              SectionCard(
                title: 'الكفاءات',
                child: Column(
                  children: criteria
                      .map((c) => InfoRow(
                            str(c['name']),
                            [
                              if (c['self_score'] != null) 'ذاتي ${num1(c['self_score'])}',
                              if (c['manager_score'] != null) 'المدير ${num1(c['manager_score'])}',
                              'من ${num1(c['max_score'])}',
                            ].join(' · '),
                          ))
                      .toList(),
                ),
              ),
            if (goals.isNotEmpty)
              SectionCard(
                title: 'الأهداف',
                child: Column(
                  children: goals
                      .map((g) => InfoRow(str(g['name']),
                          'المحقق ${num1(g['actual'])} من ${num1(g['target'])} ${str(g['unit'], '')} (${num1(g['achievement'])}%)${g['rating'] != null ? ' · تقدير ${g['rating']}/5' : ''}'))
                      .toList(),
                ),
              ),
            if (a['strengths'] != null) SectionCard(title: 'نقاط القوة', child: Text(str(a['strengths']))),
            if (a['weaknesses'] != null) SectionCard(title: 'ما يحتاج إلى تطوير', child: Text(str(a['weaknesses']))),
            if (a['recommendations'] != null) SectionCard(title: 'التوصيات', child: Text(str(a['recommendations']))),
            if (a['hr_comments'] != null) SectionCard(title: 'ملاحظات الموارد البشرية', child: Text(str(a['hr_comments']))),
            if (a['self_comments'] != null) SectionCard(title: 'ملاحظات الموظف على تقييمه الذاتي', child: Text(str(a['self_comments']))),
            if (a['employee_comments'] != null) SectionCard(title: 'تعليق الموظف على النتيجة', child: Text(str(a['employee_comments']))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (boolOf(a['can_self']))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('ابدأ تقييمي الذاتي'),
                    onPressed: () async {
                      if (await openPage<bool>(context, SelfAssessmentScreen(appraisal: a)) == true) reload();
                    },
                  ),
                if (boolOf(a['can_rate']))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('تقييم الموظف'),
                    onPressed: () async {
                      if (await openPage<bool>(context, RateScreen(appraisal: a)) == true) reload();
                    },
                  ),
                if (boolOf(a['can_acknowledge']))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all),
                    label: const Text('اطلعت على التقييم'),
                    onPressed: () async {
                      final comment = await askText(context, 'تأكيد الاطلاع', hint: 'تعليقك على التقييم (اختياري)', required: false, ok: 'تأكيد');
                      if (comment == null || !context.mounted) return;
                      if (await runAction(context, () => Api.instance.post('appraisals/${widget.id}/acknowledge', data: {if (comment.isNotEmpty) 'employee_comments': comment}))) {
                        reload();
                      }
                    },
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

/// A 1..max rating picker for one criterion.
class _ScorePicker extends StatelessWidget {
  final String title;
  final String? hint;
  final double max;
  final double? value;
  final ValueChanged<double> onChanged;

  const _ScorePicker({required this.title, this.hint, required this.max, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final steps = max.round().clamp(1, 10);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (hint != null && hint!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(steps, (i) {
              final v = (i + 1).toDouble();
              return ChoiceChip(label: Text('${i + 1}'), selected: value == v, onSelected: (_) => onChanged(v));
            }),
          ),
        ]),
      ),
    );
  }
}

class SelfAssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> appraisal;

  const SelfAssessmentScreen({super.key, required this.appraisal});

  @override
  State<SelfAssessmentScreen> createState() => _SelfAssessmentScreenState();
}

class _SelfAssessmentScreenState extends State<SelfAssessmentScreen> {
  late final List<Map<String, dynamic>> _criteria = listOf(widget.appraisal['criteria']);
  late final List<double?> _scores = List<double?>.filled(_criteria.length, null);
  final _comments = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (_scores.any((s) => s == null)) {
      toast(context, 'قيّم نفسك في كل كفاءة.', error: true);
      return;
    }
    if (!await confirm(context, 'إرسال التقييم الذاتي', 'لا يمكن تعديله بعد الإرسال، ويصل إلى مديرك.', ok: 'إرسال')) return;
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('appraisals/${widget.appraisal['id']}/self', data: {
        'scores': _scores,
        if (_comments.text.trim().isNotEmpty) 'self_comments': _comments.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقييم الذاتي')),
      body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text('قيّم أداءك بصدق في كل كفاءة؛ يطّلع مديرك على تقييمك قبل أن يضع تقييمه.'),
        ),
        ...List.generate(_criteria.length, (i) {
          final c = _criteria[i];
          return _ScorePicker(
            title: str(c['name']),
            hint: c['description'] as String?,
            max: numOf(c['max_score']).toDouble(),
            value: _scores[i],
            onChanged: (v) => setState(() => _scores[i] = v),
          );
        }),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(controller: _comments, maxLines: 4, decoration: const InputDecoration(labelText: 'إنجازاتك وملاحظاتك (اختياري)')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(onPressed: _busy ? null : _submit, child: _busy ? const Busy() : const Text('إرسال إلى مديري')),
        ),
      ]),
    );
  }
}

class RateScreen extends StatefulWidget {
  final Map<String, dynamic> appraisal;

  const RateScreen({super.key, required this.appraisal});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  late final List<Map<String, dynamic>> _criteria = listOf(widget.appraisal['criteria']);
  late final List<Map<String, dynamic>> _goals = listOf(widget.appraisal['goals']);
  late final List<double?> _scores = _criteria.map((c) => c['manager_score'] == null ? null : numOf(c['manager_score']).toDouble()).toList();
  late final Map<int, int> _goalRatings = {
    for (final g in _goals) intOf(g['id']): g['rating'] != null ? intOf(g['rating']) : intOf(g['suggested_rating']).clamp(1, 5),
  };
  late final _strengths = TextEditingController(text: widget.appraisal['strengths'] as String?);
  late final _weaknesses = TextEditingController(text: widget.appraisal['weaknesses'] as String?);
  late final _recommendations = TextEditingController(text: widget.appraisal['recommendations'] as String?);
  bool _busy = false;

  Future<void> _send(bool submit) async {
    if (submit) {
      if (_scores.any((s) => s == null) || _strengths.text.trim().isEmpty || _weaknesses.text.trim().isEmpty) {
        toast(context, 'قيّم كل الكفاءات واكتب نقاط القوة وما يحتاج إلى تطوير.', error: true);
        return;
      }
      if (!await confirm(context, 'إرسال التقييم', 'يُرسل التقييم لاعتماد الموارد البشرية ولا يمكن تعديله بعدها إلا إذا أُعيد إليك.', ok: 'إرسال')) return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('appraisals/${widget.appraisal['id']}/rate', data: {
        'action': submit ? 'submit' : 'save',
        'scores': _scores,
        'goals': _goalRatings.map((k, v) => MapEntry('$k', v)),
        'strengths': _strengths.text.trim(),
        'weaknesses': _weaknesses.text.trim(),
        'recommendations': _recommendations.text.trim(),
      });
      if (!mounted) return;
      toast(context, r.message);
      if (submit) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تقييم ${str(mapOf(widget.appraisal['employee'])['name'])}')),
      body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        if (widget.appraisal['self_comments'] != null)
          SectionCard(title: 'ملاحظات الموظف', child: Text(str(widget.appraisal['self_comments']))),
        const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: Text('الكفاءات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        ...List.generate(_criteria.length, (i) {
          final c = _criteria[i];
          return _ScorePicker(
            title: str(c['name']),
            hint: c['self_score'] != null ? 'تقييم الموظف لنفسه: ${num1(c['self_score'])}' : c['description'] as String?,
            max: numOf(c['max_score']).toDouble(),
            value: _scores[i],
            onChanged: (v) => setState(() => _scores[i] = v),
          );
        }),
        if (_goals.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 0), child: Text('الأهداف (من 1 إلى 5)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ..._goals.map((g) => _ScorePicker(
                title: str(g['name']),
                hint: 'المحقق ${num1(g['actual'])} من ${num1(g['target'])} (${num1(g['achievement'])}%)',
                max: 5,
                value: _goalRatings[intOf(g['id'])]?.toDouble(),
                onChanged: (v) => setState(() => _goalRatings[intOf(g['id'])] = v.round()),
              )),
        ],
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(controller: _strengths, maxLines: 3, decoration: const InputDecoration(labelText: 'نقاط القوة')),
            const SizedBox(height: 12),
            TextField(controller: _weaknesses, maxLines: 3, decoration: const InputDecoration(labelText: 'ما يحتاج إلى تطوير')),
            const SizedBox(height: 12),
            TextField(controller: _recommendations, maxLines: 2, decoration: const InputDecoration(labelText: 'توصيات (اختياري)')),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _send(false), child: const Text('حفظ مسودة'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(onPressed: _busy ? null : () => _send(true), child: _busy ? const Busy() : const Text('إرسال للاعتماد'))),
            ]),
          ]),
        ),
      ]),
    );
  }
}
