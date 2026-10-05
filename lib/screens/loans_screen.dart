import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _loader = GlobalKey<LoaderState>();
  Map<String, dynamic> _data = {};

  @override
  Widget build(BuildContext context) {
    final currency = str(context.read<Session>().employee['currency'], '');
    return Scaffold(
      appBar: AppBar(title: const Text('السلف والقروض')),
      floatingActionButton: ActionFab(
        label: 'طلب سلفة',
        onPressed: () async {
          if (await openPage<bool>(context, LoanFormScreen(info: _data, currency: currency)) == true) _loader.currentState?.reload();
        },
      ),
      body: Loader(
        key: _loader,
        load: () async => (await Api.instance.get('loans')).map,
        builder: (context, data, reload) {
          _data = mapOf(data);
          final loans = listOf(_data['loans']);
          return RefreshList(onRefresh: reload, padding: const EdgeInsets.only(top: 8, bottom: 90), children: [
            if (loans.isEmpty) const EmptyView(icon: Icons.payments_outlined, text: 'ليس لديك سلف أو قروض.'),
            ...loans.map((l) => ItemTile(
                  icon: Icons.payments_outlined,
                  iconColor: statusColor(str(l['status'], '')),
                  title: '${str(l['type_label'])} · ${money(l['amount'])} $currency',
                  subtitle: '${intOf(l['installments_count'])} قسط × ${money(l['installment_amount'])} · المتبقي ${money(l['remaining_amount'])}',
                  trailing: StatusBadge(str(l['status_label']), status: str(l['status'], '')),
                  onTap: () => openPage(context, LoanScreen(id: intOf(l['id']), currency: currency)),
                )),
          ]);
        },
      ),
    );
  }
}

class LoanScreen extends StatelessWidget {
  final int id;
  final String currency;

  const LoanScreen({super.key, required this.id, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل السلفة')),
      body: Loader(
        load: () async => (await Api.instance.get('loans/$id')).map,
        builder: (context, data, reload) {
          final l = mapOf(data);
          final rows = listOf(l['installments']);
          return RefreshList(onRefresh: reload, children: [
            SectionCard(
              title: str(l['type_label']),
              trailing: StatusBadge(str(l['status_label']), status: str(l['status'], '')),
              child: Column(children: [
                InfoRow('المبلغ', '${money(l['amount'])} $currency'),
                InfoRow('المسدد', '${money(l['paid_amount'])} $currency'),
                InfoRow('المتبقي', '${money(l['remaining_amount'])} $currency', bold: true),
                InfoRow('الأقساط', '${intOf(l['installments_count'])} × ${money(l['installment_amount'])}'),
                if (l['reason'] != null) InfoRow('السبب', str(l['reason'])),
                if (l['rejection_reason'] != null) InfoRow('سبب الرفض', str(l['rejection_reason'])),
              ]),
            ),
            SectionCard(
              title: 'جدول الأقساط',
              child: Column(
                children: rows
                    .map((r) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(radius: 14, child: Text('${intOf(r['number'])}', style: const TextStyle(fontSize: 12))),
                          title: Text(fmtMonth(r['month'])),
                          subtitle: Text('${money(r['amount'])} $currency'),
                          trailing: StatusBadge(str(r['status_label']), status: r['status'] == 'paid' ? 'paid' : 'pending'),
                        ))
                    .toList(),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class LoanFormScreen extends StatefulWidget {
  final Map<String, dynamic> info;
  final String currency;

  const LoanFormScreen({super.key, required this.info, required this.currency});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  String? _type;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  int _count = 3;
  bool _busy = false;

  double get _installment => (double.tryParse(_amount.text) ?? 0) / _count;

  Future<void> _submit() async {
    if (_type == null) {
      toast(context, 'لا توجد أنواع سلف متاحة.', error: true);
      return;
    }
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      toast(context, 'اكتب مبلغ السلفة.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await Api.instance.post('loans', data: {
        'type': _type,
        'amount': amount,
        'installments_count': _count,
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      toast(context, result.message);
      Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = listOf(widget.info['types']);
    final keys = types.map((t) => str(t['key'])).toList();
    if (_type == null || !keys.contains(_type)) _type = keys.isNotEmpty ? keys.first : null;
    final salary = numOf(widget.info['salary']);
    final cap = numOf(widget.info['deduction_cap']);
    final overCap = salary > 0 && cap > 0 && _installment > salary * cap / 100;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب سلفة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'النوع'),
          items: types.map((t) => DropdownMenuItem(value: str(t['key']), child: Text(str(t['label'])))).toList(),
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'المبلغ', suffixText: widget.currency),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('عدد الأقساط: $_count', style: Theme.of(context).textTheme.titleMedium),
        Slider(value: _count.toDouble(), min: 1, max: 24, divisions: 23, label: '$_count', onChanged: (v) => setState(() => _count = v.round())),
        if (_installment > 0)
          Text('القسط الشهري ≈ ${money(_installment)} ${widget.currency}، يبدأ في ${fmtMonth(widget.info['first_month'])}',
              style: TextStyle(color: overCap ? AppColors.error : AppColors.info)),
        if (overCap)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('القسط يتجاوز ${num1(cap)}% من راتبك؛ قد تطلب الموارد البشرية زيادة عدد الأقساط.', style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        TextField(controller: _reason, maxLines: 2, decoration: const InputDecoration(labelText: 'السبب (اختياري)')),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _busy ? null : _submit, child: _busy ? const Busy() : const Text('تقديم الطلب')),
      ]),
    );
  }
}
