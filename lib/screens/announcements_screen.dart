import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../widgets/ui.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات')),
      body: Loader(
        load: () async => (await Api.instance.get('announcements', query: {'per_page': 50})).map,
        builder: (context, data, reload) {
          final rows = listOf(mapOf(data)['data']);
          return RefreshList(onRefresh: reload, children: [
            if (rows.isEmpty) const EmptyView(icon: Icons.campaign_outlined, text: 'لا توجد إعلانات.'),
            ...rows.map((a) => ItemTile(
                  icon: boolOf(a['is_pinned']) ? Icons.push_pin : Icons.campaign_outlined,
                  iconColor: boolOf(a['is_pinned']) ? AppColors.accent : AppColors.primary,
                  title: str(a['title']),
                  subtitle: fmtDate(a['published_at'] ?? a['created_at']),
                  onTap: () => openPage(context, AnnouncementScreen(id: intOf(a['id']))),
                )),
          ]);
        },
      ),
    );
  }
}

class AnnouncementScreen extends StatelessWidget {
  final int id;

  const AnnouncementScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعلان')),
      body: Loader(
        load: () async => (await Api.instance.get('announcements/$id')).map,
        builder: (context, data, reload) {
          final a = mapOf(data);
          return ListView(padding: const EdgeInsets.all(8), children: [
            SectionCard(
              title: str(a['title']),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fmtDate(a['published_at'] ?? a['created_at']), style: Theme.of(context).textTheme.bodySmall),
                if (a['event_date'] != null) Text('موعد الفعالية: ${fmtDate(a['event_date'])}', style: const TextStyle(color: AppColors.info)),
                const SizedBox(height: 12),
                SelectableText(str(a['content'], ''), style: const TextStyle(height: 1.8)),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
