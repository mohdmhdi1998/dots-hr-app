import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = str(context.read<Session>().employee['currency'], '');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التدريب'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.accent,
            tabs: [Tab(text: 'تدريباتي'), Tab(text: 'الدورات المتاحة')],
          ),
        ),
        body: TabBarView(children: [
          Loader(
            load: () async => (await Api.instance.get('training')).map,
            builder: (context, data, reload) {
              final d = mapOf(data);
              final rows = listOf(d['enrollments']);
              final certs = listOf(d['certificates']);
              return RefreshList(onRefresh: reload, children: [
                if (rows.isEmpty) const EmptyView(icon: Icons.school_outlined, text: 'لست مسجلًا في أي دورة.'),
                ...rows.map((e) {
                  final pledge = e['pledge'] == null ? null : mapOf(e['pledge']);
                  return SectionCard(
                    title: str(e['course']),
                    trailing: StatusBadge(str(e['status_label']), status: str(e['status'], '')),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (e['start_date'] != null) InfoRow('الموعد', '${fmtDate(e['start_date'])}${e['end_date'] != null ? ' ← ${fmtDate(e['end_date'])}' : ''}'),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: intOf(e['progress']) / 100, minHeight: 8, backgroundColor: AppColors.surface),
                      ),
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text('التقدم ${intOf(e['progress'])}%', style: Theme.of(context).textTheme.bodySmall)),
                      if (pledge != null) ...[
                        const Divider(height: 24),
                        Text('تعهد تكاليف التدريب', style: Theme.of(context).textTheme.titleMedium),
                        InfoRow('التكلفة', '${money(pledge['amount'])} $currency'),
                        InfoRow('مدة الالتزام', '${intOf(pledge['months'])} شهرًا${pledge['until'] != null ? ' حتى ${fmtDate(pledge['until'])}' : ' بعد الإتمام'}'),
                        InfoRow('المستحق لو تركت العمل اليوم', '${money(pledge['balance'])} $currency', bold: true),
                      ],
                    ]),
                  );
                }),
                if (certs.isNotEmpty)
                  SectionCard(
                    title: 'شهاداتي',
                    child: Column(
                      children: certs
                          .map((c) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.workspace_premium_outlined, color: AppColors.success),
                                title: Text(str(c['title'])),
                                subtitle: Text('${str(c['number'])} · ${fmtDate(c['issued_at'])}'),
                              ))
                          .toList(),
                    ),
                  ),
              ]);
            },
          ),
          Loader(
            load: () async => (await Api.instance.get('training/programs')).map,
            builder: (context, data, reload) {
              final rows = listOf(mapOf(data)['programs']);
              return RefreshList(onRefresh: reload, children: [
                if (rows.isEmpty) const EmptyView(icon: Icons.menu_book_outlined, text: 'لا توجد دورات متاحة الآن.'),
                ...rows.map((c) => ItemTile(
                      icon: Icons.menu_book_outlined,
                      title: str(c['name']),
                      subtitle: [
                        str(c['category'], ''),
                        str(c['type'], ''),
                        if (c['start_date'] != null) fmtDate(c['start_date']),
                        if (c['duration_hours'] != null) '${num1(c['duration_hours'])} ساعة',
                        if (boolOf(c['is_mandatory'])) 'إلزامية',
                      ].where((s) => s.isNotEmpty).join(' · '),
                    )),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('للالتحاق بدورة تواصل مع مديرك أو الموارد البشرية.', textAlign: TextAlign.center),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
