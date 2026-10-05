import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../widgets/ui.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دليل الموظفين')),
      body: Loader(
        load: () async => (await Api.instance.get('directory')).map,
        builder: (context, data, reload) {
          final all = listOf(mapOf(data)['employees']);
          final rows = _query.isEmpty
              ? all
              : all.where((e) => '${e['name']} ${e['department']} ${e['job_title']} ${e['code']}'.contains(_query)).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(hintText: 'ابحث بالاسم أو القسم أو الوظيفة', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: RefreshList(onRefresh: reload, children: [
                if (rows.isEmpty) const EmptyView(icon: Icons.person_search_outlined, text: 'لا توجد نتائج.'),
                ...rows.map((e) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: e['photo'] != null ? NetworkImage(str(e['photo'])) : null,
                          child: e['photo'] == null ? Text(str(e['name']).characters.first, style: const TextStyle(color: AppColors.primary)) : null,
                        ),
                        title: Text(str(e['name'])),
                        subtitle: Text('${str(e['job_title'], '')} · ${str(e['department'], '')}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (e['phone'] != null)
                            IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => launchUrl(Uri.parse('tel:${e['phone']}'))),
                          if (e['email'] != null)
                            IconButton(icon: const Icon(Icons.mail_outline), onPressed: () => launchUrl(Uri.parse('mailto:${e['email']}'))),
                        ]),
                      ),
                    )),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
