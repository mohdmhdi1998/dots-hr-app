import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';

class PayslipsScreen extends StatelessWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = str(context.read<Session>().employee['currency'], '');
    return Scaffold(
      appBar: AppBar(title: const Text('كشوف الرواتب')),
      body: Loader(
        load: () async => (await Api.instance.get('payslips')).map,
        builder: (context, data, reload) {
          final d = mapOf(data);
          final salary = mapOf(d['current_salary']);
          final slips = listOf(d['payslips']);
          return RefreshList(onRefresh: reload, children: [
            SectionCard(
              title: 'راتبي الحالي',
              child: Column(children: [
                InfoRow('الأساسي', '${money(salary['basic'])} $currency'),
                if (numOf(salary['housing']) > 0) InfoRow('بدل السكن', '${money(salary['housing'])} $currency'),
                if (numOf(salary['transportation']) > 0) InfoRow('بدل المواصلات', '${money(salary['transportation'])} $currency'),
                if (numOf(salary['other']) > 0) InfoRow('بدلات أخرى', '${money(salary['other'])} $currency'),
                const Divider(),
                InfoRow('الإجمالي', '${money(salary['total'])} $currency', bold: true),
              ]),
            ),
            if (slips.isEmpty) const EmptyView(icon: Icons.receipt_long_outlined, text: 'لا توجد كشوف رواتب بعد.'),
            ...slips.map((p) => ItemTile(
                  icon: Icons.receipt_long_outlined,
                  title: fmtMonth(p['month']),
                  subtitle: 'الصافي ${money(p['net_salary'])} $currency',
                  onTap: () => openPage(context, PayslipScreen(id: intOf(p['id']), currency: currency)),
                )),
          ]);
        },
      ),
    );
  }
}

class PayslipScreen extends StatelessWidget {
  final int id;
  final String currency;

  const PayslipScreen({super.key, required this.id, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف الراتب')),
      body: Loader(
        load: () async => (await Api.instance.get('payslips/$id')).map,
        builder: (context, data, reload) {
          final p = mapOf(data);
          String m(String key) => '${money(p[key])} $currency';
          final earnings = <(String, String)>[
            ('الراتب الأساسي', 'basic_salary'),
            ('بدل السكن', 'housing_allowance'),
            ('بدل المواصلات', 'transportation_allowance'),
            ('بدلات أخرى', 'other_allowances'),
            ('العمل الإضافي', 'overtime_amount'),
          ].where((e) => numOf(p[e.$2]) > 0).toList();
          final deductions = <(String, String)>[
            ('الغياب', 'deductions_absence'),
            ('التأخير', 'deductions_late'),
            ('التأمينات', 'deductions_gosi'),
            ('أقساط السلف', 'deductions_loan'),
            ('خصومات أخرى', 'deductions_other'),
          ].where((e) => numOf(p[e.$2]) > 0).toList();
          return RefreshList(onRefresh: reload, children: [
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(fmtMonth(p['month']), style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(m('net_salary'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                  const Text('صافي الراتب', style: TextStyle(color: Colors.white70)),
                ]),
              ),
            ),
            SectionCard(title: 'المستحقات', child: Column(children: earnings.map((e) => InfoRow(e.$1, m(e.$2))).toList())),
            if (deductions.isNotEmpty)
              SectionCard(title: 'الاستقطاعات', child: Column(children: deductions.map((e) => InfoRow(e.$1, m(e.$2))).toList())),
          ]);
        },
      ),
    );
  }
}
