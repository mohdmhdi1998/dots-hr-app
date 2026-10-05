import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/ui.dart';
import 'leaves_screen.dart';
import 'letters_screen.dart';
import 'loans_screen.dart';
import 'payslips_screen.dart';
import 'attendance_screen.dart';

/// Everything the employee asks HR for, in one place.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.beach_access_outlined, 'الإجازات', 'طلب إجازة، متابعة الطلبات والأرصدة', const LeavesScreen()),
      (Icons.payments_outlined, 'السلف والقروض', 'طلب سلفة وجدول أقساطها', const LoansScreen()),
      (Icons.mail_outline, 'الخطابات الرسمية', 'شهادة راتب، خطاب تعريف، شهادة خبرة', const LettersScreen()),
      (Icons.receipt_long_outlined, 'كشوف الرواتب', 'تفاصيل راتب كل شهر', const PayslipsScreen()),
      (Icons.fingerprint, 'الحضور والانصراف', 'التسجيل من الجوال وسجل الشهر', const AttendanceScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: items
            .map((i) => ItemTile(icon: i.$1, iconColor: AppColors.primary, title: i.$2, subtitle: i.$3, onTap: () => openPage(context, i.$4)))
            .toList(),
      ),
    );
  }
}
