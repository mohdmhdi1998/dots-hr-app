import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'directory_screen.dart';
import 'notifications_screen.dart';
import 'signatures_screen.dart';
import 'training_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final e = s.employee;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await s.refresh();
          } on ApiError catch (err) {
            if (context.mounted) toast(context, err.message, error: true);
          }
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 24), children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: e['photo'] != null ? NetworkImage(str(e['photo'])) : null,
                child: e['photo'] == null ? Text(s.name.isEmpty ? '?' : s.name.characters.first, style: const TextStyle(fontSize: 30, color: AppColors.primary)) : null,
              ),
              const SizedBox(height: 10),
              Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${str(e['job_title'], '')} · ${s.roleLabel}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          SectionCard(
            title: 'بياناتي',
            child: Column(children: [
              InfoRow('الرقم الوظيفي', str(e['code'])),
              InfoRow('القسم', str(e['department'])),
              InfoRow('المدير المباشر', str(e['manager'])),
              if (e['branch'] != null) InfoRow('الفرع', str(e['branch'])),
              InfoRow('تاريخ التعيين', fmtDate(e['hire_date'])),
              InfoRow('الجوال', str(e['phone'])),
              InfoRow('البريد', str(e['email'])),
              if (e['national_id'] != null) InfoRow('رقم الهوية', str(e['national_id'])),
            ]),
          ),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.folder_open_outlined), title: const Text('مستنداتي الموقّعة'), trailing: const Icon(Icons.chevron_left), onTap: () => openPage(context, const SignaturesScreen())),
              ListTile(leading: const Icon(Icons.school_outlined), title: const Text('تدريباتي وشهاداتي'), trailing: const Icon(Icons.chevron_left), onTap: () => openPage(context, const TrainingScreen())),
              ListTile(leading: const Icon(Icons.notifications_none), title: const Text('الإشعارات'), trailing: const Icon(Icons.chevron_left), onTap: () => openPage(context, const NotificationsScreen())),
              ListTile(leading: const Icon(Icons.contacts_outlined), title: const Text('دليل الموظفين'), trailing: const Icon(Icons.chevron_left), onTap: () => openPage(context, const DirectoryScreen())),
            ]),
          ),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.dns_outlined), title: const Text('الخادم'), subtitle: Text(s.serverUrl, textDirection: TextDirection.ltr)),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  if (await confirm(context, 'تسجيل الخروج', 'هل تريد الخروج من حسابك على هذا الجهاز؟', ok: 'خروج')) {
                    await s.logout();
                  }
                },
              ),
            ]),
          ),
          Center(child: Text('بيانات غير صحيحة؟ تواصل مع الموارد البشرية لتحديثها.', style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
  }
}
