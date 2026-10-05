import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/ui.dart';

/// Requests waiting for the manager's decision in their approval route.
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  IconData _icon(String? type) => switch (type) {
        'leave' => Icons.beach_access_outlined,
        'loan' => Icons.payments_outlined,
        'letter' => Icons.mail_outline,
        'expense' => Icons.receipt_outlined,
        'compensation' => Icons.trending_up,
        _ => Icons.approval_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بانتظار اعتمادي')),
      body: Loader(
        load: () async => (await Api.instance.get('manager/approvals')).map,
        builder: (context, data, reload) {
          final rows = listOf(mapOf(data)['approvals']);
          return RefreshList(onRefresh: reload, children: [
            if (rows.isEmpty) const EmptyView(icon: Icons.done_all, text: 'لا توجد طلبات بانتظار قرارك.'),
            ...rows.map((a) => ItemTile(
                  icon: _icon(a['type'] as String?),
                  iconColor: AppColors.info,
                  title: '${str(a['type_label'])} · ${str(a['employee'])}',
                  subtitle: '${str(a['summary'])}\n${str(a['stage'], '')}',
                  onTap: () async {
                    await openPage(context, ApprovalScreen(id: intOf(a['id'])));
                    reload();
                  },
                )),
          ]);
        },
      ),
    );
  }
}

class ApprovalScreen extends StatefulWidget {
  final int id;

  const ApprovalScreen({super.key, required this.id});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    final comment = await askText(
      context,
      approve ? 'اعتماد الطلب' : 'رفض الطلب',
      hint: approve ? 'ملاحظة (اختياري)' : 'سبب الرفض',
      required: !approve,
      ok: approve ? 'اعتماد' : 'رفض',
    );
    if (comment == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await runAction(context, () => Api.instance.post('manager/approvals/${widget.id}/${approve ? 'approve' : 'reject'}',
        data: {if (comment.isNotEmpty) 'comments': comment}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب للاعتماد')),
      body: Loader(
        load: () async => (await Api.instance.get('manager/approvals/${widget.id}')).map,
        builder: (context, data, reload) {
          final a = mapOf(data);
          final steps = listOf(a['steps']);
          return Column(children: [
            Expanded(
              child: RefreshList(onRefresh: reload, children: [
                SectionCard(
                  title: str(a['type_label']),
                  trailing: StatusBadge(str(a['status_label']), status: str(a['status'], '')),
                  child: Column(children: [
                    InfoRow('الموظف', str(a['employee'])),
                    InfoRow('القسم', str(a['department'])),
                    InfoRow('الطلب', str(a['summary'])),
                    if (a['amount'] != null) InfoRow('المبلغ', money(a['amount'])),
                    InfoRow('قدّمه', str(a['requested_by'])),
                    InfoRow('التاريخ', str(a['created_at'])),
                    if (a['notes'] != null) InfoRow('ملاحظات', str(a['notes'])),
                  ]),
                ),
                if (steps.isNotEmpty)
                  SectionCard(
                    title: 'مسار الاعتماد',
                    child: Column(
                      children: steps.map((s) {
                        final state = str(s['state'], '');
                        final icon = switch (state) {
                          'done' => Icons.check_circle,
                          'rejected' => Icons.cancel,
                          'current' => Icons.radio_button_checked,
                          'skipped' => Icons.redo,
                          _ => Icons.radio_button_unchecked,
                        };
                        final color = switch (state) {
                          'done' => AppColors.success,
                          'rejected' => AppColors.error,
                          'current' => AppColors.warning,
                          _ => AppColors.textSecondary,
                        };
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: color),
                          title: Text(str(s['title'])),
                          subtitle: Text([str(s['who'], ''), if (s['by'] != null) '${str(s['by'])} · ${str(s['at'], '')}', if (s['comment'] != null) str(s['comment'])]
                              .where((x) => x.isNotEmpty)
                              .join('\n')),
                        );
                      }).toList(),
                    ),
                  ),
              ]),
            ),
            if (['pending', 'in_progress'].contains(a['status']))
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        onPressed: _busy ? null : () => _decide(true),
                        icon: const Icon(Icons.check),
                        label: const Text('اعتماد'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: _busy ? null : () => _decide(false),
                        child: const Text('رفض'),
                      ),
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
