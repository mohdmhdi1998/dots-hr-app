import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'api.dart';

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

String monthName(int month) => month >= 1 && month <= 12 ? _months[month - 1] : '';

/// `2026-10-05` → `5 أكتوبر 2026`.
String fmtDate(dynamic value, {bool year = true}) {
  final s = str(value, '');
  if (s.length < 10) return s.isEmpty ? '—' : s;
  final d = DateTime.tryParse(s.substring(0, 10));
  if (d == null) return s;
  return '${d.day} ${monthName(d.month)}${year ? ' ${d.year}' : ''}';
}

/// `2026-09` → `سبتمبر 2026`.
String fmtMonth(dynamic value) {
  final s = str(value, '');
  final parts = s.split('-');
  if (parts.length < 2) return s;
  return '${monthName(int.tryParse(parts[1]) ?? 0)} ${parts[0]}';
}

String money(dynamic value, {int digits = 2}) {
  final n = numOf(value).toDouble();
  final fixed = n.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return parts.length > 1 && digits > 0 ? '$whole.${parts[1]}' : whole;
}

String num1(dynamic value) {
  final n = numOf(value).toDouble();
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}

String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The color that goes with a status key from the server.
Color statusColor(String? status) {
  switch (status) {
    case 'approved':
    case 'signed':
    case 'active':
    case 'finalized':
    case 'completed':
    case 'submitted':
    case 'present':
    case 'paid':
    case 'printed':
    case 'delivered':
      return AppColors.success;
    case 'pending':
    case 'enrolled':
    case 'in_progress':
    case 'self_submitted':
    case 'collecting':
    case 'not_in':
      return AppColors.warning;
    case 'late':
    case 'returned':
    case 'leave':
      return const Color(0xFFEA7317);
    case 'rejected':
    case 'declined':
    case 'cancelled':
    case 'absent':
    case 'dropped':
    case 'expired':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}
