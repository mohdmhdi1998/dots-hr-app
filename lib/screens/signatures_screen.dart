import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/signature_pad.dart';
import '../widgets/ui.dart';

class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  final _loader = GlobalKey<LoaderState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستندات والتوقيعات')),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('signatures')).map,
        builder: (context, data, reload) {
          final rows = listOf(mapOf(data)['signatures']);
          return RefreshList(onRefresh: reload, children: [
            if (rows.isEmpty) const EmptyView(icon: Icons.draw_outlined, text: 'لا توجد مستندات مطلوب توقيعها.'),
            ...rows.map((s) => ItemTile(
                  icon: s['status'] == 'signed' ? Icons.verified_outlined : Icons.draw_outlined,
                  iconColor: statusColor(str(s['status'], '')),
                  title: str(s['title']),
                  subtitle: s['status'] == 'signed' ? 'وُقّع ${str(s['signed_at'])}' : '${str(s['type_label'])} · طُلب ${fmtDate(s['requested_at'])}',
                  trailing: StatusBadge(str(s['status_label']), status: str(s['status'], '')),
                  onTap: () async {
                    await openPage(context, SignatureScreen(id: intOf(s['id'])));
                    reload();
                  },
                )),
          ]);
        },
      ),
    );
  }
}

/// Reads the document, then signs or declines it.
class SignatureScreen extends StatefulWidget {
  final int id;

  const SignatureScreen({super.key, required this.id});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _loader = GlobalKey<LoaderState>();

  Future<void> _decline() async {
    final reason = await askText(context, 'رفض التوقيع', hint: 'اكتب سبب رفضك ليصل إلى الموارد البشرية');
    if (reason == null || !mounted) return;
    if (await runAction(context, () => Api.instance.post('signatures/${widget.id}/decline', data: {'reason': reason}))) {
      _loader.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مستند للتوقيع')),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('signatures/${widget.id}')).map,
        builder: (context, data, reload) {
          final s = mapOf(data);
          final doc = mapOf(s['document']);
          final sections = listOf(doc['sections']);
          final blockers = (s['blockers'] as List? ?? []).map((e) => e.toString()).toList();
          final pending = s['status'] == 'pending';
          return Column(children: [
            Expanded(
              child: RefreshList(onRefresh: reload, children: [
                SectionCard(
                  title: str(doc['title'], str(s['title'])),
                  trailing: StatusBadge(str(s['status_label']), status: str(s['status'], '')),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (doc['subtitle'] != null) Text(str(doc['subtitle']), style: Theme.of(context).textTheme.bodySmall),
                    if (pending && s['expires_at'] != null) InfoRow('آخر موعد للتوقيع', fmtDate(s['expires_at'])),
                    if (s['status'] == 'signed') ...[
                      InfoRow('وُقّع في', str(s['signed_at'])),
                      InfoRow('رمز التحقق', str(s['verification_code'])),
                    ],
                    if (s['decline_reason'] != null) InfoRow('سبب الرفض', str(s['decline_reason'])),
                  ]),
                ),
                if (blockers.isNotEmpty)
                  Card(
                    color: const Color(0xFFFFF4E5),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('قبل هذا المستند وقّع على: ${blockers.join('، ثم ')}. تجدها في قائمة المهام.',
                          style: const TextStyle(color: Color(0xFF92400E))),
                    ),
                  ),
                if (sections.isEmpty && doc.isEmpty) const EmptyView(icon: Icons.description_outlined, text: 'نص المستند غير متاح في التطبيق؛ اطلبه من الموارد البشرية.'),
                ...sections.map((x) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (str(x['title'], '').isNotEmpty) ...[
                            Text(str(x['title']), style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                          ],
                          SelectableText(str(x['body'], ''), style: const TextStyle(height: 1.9, fontSize: 14.5)),
                        ]),
                      ),
                    )),
              ]),
            ),
            if (pending && blockers.isEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.draw),
                        label: const Text('قرأت المستند وأوقّع'),
                        onPressed: () async {
                          final signed = await openPage<bool>(context, SignPage(id: widget.id, title: str(s['title']), hasSaved: false));
                          if (signed == true) reload();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.error), onPressed: _decline, child: const Text('رفض')),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// The signing step: agree, draw the signature (or use the saved one), submit.
class SignPage extends StatefulWidget {
  final int id;
  final String title;
  final bool hasSaved;

  const SignPage({super.key, required this.id, required this.title, required this.hasSaved});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  final _pad = GlobalKey<SignaturePadState>();
  bool _agree = false;
  bool _save = true;
  bool _busy = false;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _hasSaved = widget.hasSaved;
    Api.instance.get('signatures').then((r) {
      if (mounted) setState(() => _hasSaved = boolOf(r.map['has_saved_signature']));
    }).catchError((_) {});
  }

  Future<void> _submit({bool useSaved = false}) async {
    if (!_agree) {
      toast(context, 'أكّد أنك قرأت المستند وتوافق عليه.', error: true);
      return;
    }
    String? image;
    if (!useSaved) {
      image = await _pad.currentState?.toDataUri();
      if (image == null) {
        if (mounted) toast(context, 'ارسم توقيعك في المربع.', error: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final result = await Api.instance.post('signatures/${widget.id}/sign', data: {
        'agree': 1,
        if (useSaved) 'use_saved': 1,
        if (image != null) 'signature_data': image,
        if (image != null && _save) 'save_signature': 1,
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('التوقيع')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              title: const Text('قرأت المستند كاملًا وأوافق على ما فيه، وأقر بأن توقيعي الإلكتروني ملزم لي كتوقيعي بخط اليد.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            SignaturePad(key: _pad, onChanged: () => setState(() {})),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? false),
              title: const Text('احفظ توقيعي لاستخدامه لاحقًا'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            ElevatedButton(onPressed: _busy ? null : () => _submit(), child: _busy ? const Busy() : const Text('توقيع')),
            if (_hasSaved)
              TextButton(onPressed: _busy ? null : () => _submit(useSaved: true), child: const Text('استخدم توقيعي المحفوظ')),
          ]),
        ),
      ),
    );
  }
}
