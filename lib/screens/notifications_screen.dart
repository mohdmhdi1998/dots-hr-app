import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../widgets/ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _loader = GlobalKey<LoaderState>();

  IconData _icon(String? type) => switch (type) {
        'success' => Icons.check_circle_outline,
        'warning' => Icons.warning_amber_rounded,
        'danger' || 'error' => Icons.error_outline,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: () async {
              if (await runAction(context, () => Api.instance.post('notifications/read-all'))) _loader.currentState?.reload();
            },
            child: const Text('قراءة الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('notifications')).map,
        builder: (context, data, reload) {
          final rows = listOf(mapOf(data)['notifications']);
          return RefreshList(onRefresh: reload, children: [
            if (rows.isEmpty) const EmptyView(icon: Icons.notifications_off_outlined, text: 'لا توجد إشعارات.'),
            ...rows.map((n) {
              final read = boolOf(n['read']);
              return Card(
                color: read ? null : const Color(0xFFF0F5FF),
                child: ListTile(
                  leading: Icon(_icon(n['type'] as String?), color: read ? AppColors.textSecondary : AppColors.primary),
                  title: Text(str(n['title']), style: TextStyle(fontWeight: read ? FontWeight.w400 : FontWeight.w700)),
                  subtitle: Text('${str(n['message'], '')}\n${str(n['created_at'], '')}'),
                  isThreeLine: true,
                  onTap: read
                      ? null
                      : () async {
                          try {
                            await Api.instance.post('notifications/${n['id']}/read');
                          } catch (_) {}
                          reload();
                        },
                ),
              );
            }),
          ]);
        },
      ),
    );
  }
}
