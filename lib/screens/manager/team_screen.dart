import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/ui.dart';
import '../appraisals_screen.dart';
import 'approvals_screen.dart';

/// The manager's tab: who is in today, requests to decide, appraisals to give.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فريقي'),
        actions: [
          IconButton(tooltip: 'الاعتمادات', icon: const Icon(Icons.approval_outlined), onPressed: () => openPage(context, const ApprovalsScreen())),
          IconButton(tooltip: 'تقييم الأداء', icon: const Icon(Icons.insights_outlined), onPressed: () => openPage(context, const AppraisalsScreen())),
        ],
      ),
      body: Loader(
        load: () async => (await Api.instance.get('manager/team')).map,
        builder: (context, data, reload) {
          final d = mapOf(data);
          final s = mapOf(d['summary']);
          final all = listOf(d['members']);
          final rows = _filter == 'all'
              ? all
              : all.where((m) => _filter == 'present' ? ['present', 'late'].contains(m['state']) : m['state'] == _filter).toList();
          final filters = <(String, String, int)>[
            ('all', 'الكل', intOf(s['count'])),
            ('present', 'حاضر', intOf(s['present'])),
            ('late', 'متأخر', intOf(s['late'])),
            ('leave', 'إجازة', intOf(s['leave'])),
            ('not_in', 'لم يسجّل', intOf(s['not_in'])),
          ];
          return RefreshList(onRefresh: reload, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('اليوم · ${fmtDate(d['date'])}', style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: filters
                    .map((f) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(label: Text('${f.$2} (${f.$3})'), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1)),
                        ))
                    .toList(),
              ),
            ),
            if (rows.isEmpty) const EmptyView(icon: Icons.groups_outlined, text: 'لا يوجد موظفون في هذا العرض.'),
            ...rows.map((m) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor(str(m['state'], '')).withValues(alpha: 0.12),
                      child: Text(str(m['name']).characters.first, style: TextStyle(color: statusColor(str(m['state'], '')))),
                    ),
                    title: Text(str(m['name'])),
                    subtitle: Text([
                      str(m['job_title'], ''),
                      if (m['check_in'] != null) 'حضر ${str(m['check_in'])}',
                      if (m['check_out'] != null) 'انصرف ${str(m['check_out'])}',
                      if (intOf(m['late_minutes']) > 0) 'تأخر ${intOf(m['late_minutes'])} د',
                    ].where((x) => x.isNotEmpty).join(' · ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      StatusBadge(str(m['state_label']), status: str(m['state'], '')),
                      if (m['phone'] != null)
                        IconButton(icon: const Icon(Icons.call_outlined, color: AppColors.primary), onPressed: () => launchUrl(Uri.parse('tel:${m['phone']}'))),
                    ]),
                  ),
                )),
          ]);
        },
      ),
    );
  }
}
