import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'appraisals_screen.dart';
import 'manager/approvals_screen.dart';
import 'reviews360_screen.dart';
import 'signatures_screen.dart';

/// What is waiting for the user: documents to sign, appraisals, 360 reviews and, for managers, approvals.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _loader = GlobalKey<LoaderState>();

  Future<Map<String, dynamic>> _load(bool manager) async {
    final calls = <Future<ApiResult>>[
      Api.instance.get('signatures'),
      Api.instance.get('appraisals'),
      Api.instance.get('reviews-360'),
      if (manager) Api.instance.get('manager/approvals'),
    ];
    final r = await Future.wait(calls);
    return {
      'signatures': listOf(r[0].map['signatures']).where((s) => s['status'] == 'pending').toList(),
      'own': listOf(r[1].map['own']).where((a) => boolOf(a['needs_action'])).toList(),
      'team': listOf(r[1].map['team']).where((a) => boolOf(a['needs_action'])).toList(),
      'reviews': listOf(r[2].map['reviews']).where((x) => x['status'] == 'pending').toList(),
      'approvals': manager ? listOf(r[3].map['approvals']) : <Map<String, dynamic>>[],
    };
  }

  Future<void> _open(Widget page) async {
    await openPage(context, page);
    _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<Session>().isManager;
    return Scaffold(
      appBar: AppBar(title: const Text('المهام')),
      body: Loader(
        key: _loader,
        load: () => _load(manager),
        builder: (context, data, reload) {
          final d = mapOf(data);
          final signatures = listOf(d['signatures']);
          final own = listOf(d['own']);
          final team = listOf(d['team']);
          final reviews = listOf(d['reviews']);
          final approvals = listOf(d['approvals']);
          final empty = signatures.isEmpty && own.isEmpty && team.isEmpty && reviews.isEmpty && approvals.isEmpty;
          return RefreshList(onRefresh: reload, children: [
            if (empty) const EmptyView(icon: Icons.task_alt, text: 'لا توجد مهام بانتظارك الآن.'),
            if (signatures.isNotEmpty) _header('مستندات بانتظار توقيعك', signatures.length),
            ...signatures.map((s) => ItemTile(
                  icon: Icons.draw_outlined,
                  iconColor: AppColors.accent,
                  title: str(s['title']),
                  subtitle: '${str(s['type_label'])} · المهلة حتى ${fmtDate(s['expires_at'])}',
                  onTap: () => _open(SignatureScreen(id: intOf(s['id']))),
                )),
            if (approvals.isNotEmpty) _header('طلبات بانتظار اعتمادك', approvals.length),
            ...approvals.map((a) => ItemTile(
                  icon: Icons.approval_outlined,
                  iconColor: AppColors.info,
                  title: '${str(a['type_label'])} · ${str(a['employee'])}',
                  subtitle: str(a['summary']),
                  onTap: () => _open(ApprovalScreen(id: intOf(a['id']))),
                )),
            if (own.isNotEmpty) _header('تقييم أدائي', own.length),
            ...own.map((a) => ItemTile(
                  icon: Icons.insights_outlined,
                  iconColor: AppColors.success,
                  title: str(a['cycle']),
                  subtitle: str(a['status_label']),
                  onTap: () => _open(AppraisalScreen(id: intOf(a['id']))),
                )),
            if (team.isNotEmpty) _header('تقييم أداء فريقي', team.length),
            ...team.map((a) => ItemTile(
                  icon: Icons.person_search_outlined,
                  iconColor: AppColors.primary,
                  title: str(a['employee_name']),
                  subtitle: '${str(a['cycle'])} · ${str(a['status_label'])}',
                  onTap: () => _open(AppraisalScreen(id: intOf(a['id']))),
                )),
            if (reviews.isNotEmpty) _header('تقييمات 360 المطلوبة منك', reviews.length),
            ...reviews.map((r) => ItemTile(
                  icon: Icons.donut_large_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  title: str(r['employee']),
                  subtitle: '${str(r['reviewer_type_label'])} · ${str(r['cycle'])}',
                  onTap: () => _open(Review360Screen(id: intOf(r['id']))),
                )),
            const SizedBox(height: 12),
            const Divider(indent: 16, endIndent: 16),
            ListTile(leading: const Icon(Icons.folder_open_outlined), title: const Text('كل المستندات الموقّعة'), trailing: const Icon(Icons.chevron_left), onTap: () => _open(const SignaturesScreen())),
            ListTile(leading: const Icon(Icons.insights_outlined), title: const Text('كل تقييمات الأداء'), trailing: const Icon(Icons.chevron_left), onTap: () => _open(const AppraisalsScreen())),
            ListTile(leading: const Icon(Icons.donut_large_outlined), title: const Text('تقييمات 360'), trailing: const Icon(Icons.chevron_left), onTap: () => _open(const Reviews360Screen())),
          ]);
        },
      ),
    );
  }

  Widget _header(String text, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
          CircleAvatar(radius: 12, backgroundColor: AppColors.accent, child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12))),
        ]),
      );
}
