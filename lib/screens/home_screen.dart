import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'announcements_screen.dart';
import 'attendance_screen.dart';
import 'directory_screen.dart';
import 'leaves_screen.dart';
import 'letters_screen.dart';
import 'loans_screen.dart';
import 'notifications_screen.dart';
import 'payslips_screen.dart';
import 'shell.dart';
import 'training_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int tab) onOpenTab;

  const HomeScreen({super.key, required this.onOpenTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _loader = GlobalKey<LoaderState>();

  Future<void> _reload() async => _loader.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: Text(str(session.company['name'], 'DOTS HR')),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_none),
            onPressed: () async {
              await openPage(context, const NotificationsScreen());
              _reload();
            },
          ),
        ],
      ),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('dashboard')).map,
        builder: (context, data, reload) {
          final d = mapOf(data);
          final today = mapOf(d['today']);
          final tasks = mapOf(d['tasks']);
          final team = d['team'] == null ? null : mapOf(d['team']);
          return RefreshList(onRefresh: reload, children: [
            _greeting(context, session, intOf(d['unread_notifications'])),
            _attendanceCard(context, today, reload),
            if (intOf(d['tasks_total']) > 0) _tasksCard(context, tasks),
            if (team != null) _teamCard(context, team),
            _quickActions(context, reload),
            _balances(context, listOf(d['leave_balances']), intOf(d['pending_leaves'])),
            _announcements(context, listOf(d['announcements'])),
          ]);
        },
      ),
    );
  }

  Widget _greeting(BuildContext context, Session s, int unread) {
    final hour = DateTime.now().hour;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${hour < 12 ? 'صباح الخير' : 'مساء الخير'}، ${s.firstName}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text([str(s.employee['job_title'], ''), str(s.employee['department'], '')].where((e) => e.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall),
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('لديك $unread إشعار غير مقروء', style: const TextStyle(color: AppColors.accent, fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _attendanceCard(BuildContext context, Map<String, dynamic> today, Future<void> Function() reload) {
    final checkedIn = today['check_in'] != null;
    final checkedOut = today['check_out'] != null;
    return SectionCard(
      title: 'حضور اليوم',
      trailing: today['status_label'] == null ? null : StatusBadge(str(today['status_label']), status: str(today['status'], '')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          StatBox(str(today['check_in'], '--:--'), 'الحضور', color: checkedIn ? AppColors.success : AppColors.textSecondary),
          StatBox(str(today['check_out'], '--:--'), 'الانصراف', color: checkedOut ? AppColors.info : AppColors.textSecondary),
        ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            await openPage(context, const AttendanceScreen());
            reload();
          },
          icon: Icon(checkedOut ? Icons.history : Icons.fingerprint),
          label: Text(checkedOut ? 'سجل الحضور' : (checkedIn ? 'تسجيل الانصراف' : 'تسجيل الحضور')),
        ),
      ]),
    );
  }

  Widget _tasksCard(BuildContext context, Map<String, dynamic> t) {
    final items = <MapEntry<String, int>>[
      MapEntry('مستندات بانتظار توقيعك', intOf(t['signatures'])),
      MapEntry('تقييم ذاتي مطلوب', intOf(t['self_appraisals'])),
      MapEntry('تقييم معتمد للاطلاع', intOf(t['acknowledge'])),
      MapEntry('تقييمات 360 مطلوبة منك', intOf(t['reviews_360'])),
      MapEntry('طلبات بانتظار اعتمادك', intOf(t['approvals'])),
      MapEntry('تقييمات أداء لفريقك', intOf(t['team_appraisals'])),
    ].where((e) => e.value > 0).toList();
    return Card(
      color: const Color(0xFFFFF8EC),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpenTab(Tabs.tasks),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.assignment_late_outlined, color: AppColors.warning, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مهام تنتظرك', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                ...items.map((e) => Text('• ${e.key}: ${e.value}', style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            ),
            const Icon(Icons.chevron_left),
          ]),
        ),
      ),
    );
  }

  Widget _teamCard(BuildContext context, Map<String, dynamic> team) {
    return SectionCard(
      title: 'فريقي اليوم',
      child: Row(children: [
        StatBox('${intOf(team['count'])}', 'الفريق'),
        StatBox('${intOf(team['present'])}', 'حاضر', color: AppColors.success),
        StatBox('${intOf(team['on_leave'])}', 'إجازة', color: const Color(0xFFEA7317)),
        StatBox('${intOf(team['not_in'])}', 'لم يسجّل', color: AppColors.warning),
      ]),
    );
  }

  Widget _quickActions(BuildContext context, Future<void> Function() reload) {
    final actions = <(IconData, String, Widget)>[
      (Icons.fingerprint, 'الحضور', const AttendanceScreen()),
      (Icons.beach_access_outlined, 'الإجازات', const LeavesScreen()),
      (Icons.receipt_long_outlined, 'الرواتب', const PayslipsScreen()),
      (Icons.payments_outlined, 'السلف', const LoansScreen()),
      (Icons.mail_outline, 'الخطابات', const LettersScreen()),
      (Icons.school_outlined, 'التدريب', const TrainingScreen()),
      (Icons.campaign_outlined, 'الإعلانات', const AnnouncementsScreen()),
      (Icons.contacts_outlined, 'الدليل', const DirectoryScreen()),
    ];
    return SectionCard(
      title: 'الخدمات',
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        children: actions
            .map((a) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await openPage(context, a.$3);
                    reload();
                  },
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(radius: 22, backgroundColor: AppColors.primary.withValues(alpha: 0.08), child: Icon(a.$1, color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(a.$2, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _balances(BuildContext context, List<Map<String, dynamic>> balances, int pending) {
    if (balances.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'أرصدة الإجازات',
      trailing: pending > 0 ? StatusBadge('$pending طلب معلّق', status: 'pending') : null,
      child: Column(
        children: balances
            .map((b) => InfoRow(str(b['name']), '${num1(b['remaining'])} يوم متبقٍ${numOf(b['total']) > 0 ? ' من ${num1(b['total'])}' : ''}'))
            .toList(),
      ),
    );
  }

  Widget _announcements(BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'آخر الإعلانات',
      trailing: TextButton(onPressed: () => openPage(context, const AnnouncementsScreen()), child: const Text('الكل')),
      child: Column(
        children: items
            .map((a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(boolOf(a['is_pinned']) ? Icons.push_pin : Icons.campaign_outlined, color: AppColors.primary),
                  title: Text(str(a['title'])),
                  subtitle: Text(fmtDate(a['date'])),
                  onTap: () => openPage(context, AnnouncementScreen(id: intOf(a['id']))),
                ))
            .toList(),
      ),
    );
  }
}
