import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/format.dart';

/// Loads data once, shows a spinner, an error with «إعادة المحاولة», or the content.
/// The content gets a `reload` callback for pull-to-refresh and after actions.
class Loader extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext context, dynamic data, Future<void> Function() reload) builder;

  const Loader({super.key, required this.load, required this.builder});

  @override
  State<Loader> createState() => LoaderState();
}

class LoaderState extends State<Loader> {
  dynamic _data;
  ApiError? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = _data == null);
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiError('حدث خطأ غير متوقع.');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return ErrorView(message: _error!.message, onRetry: reload);
    }
    return widget.builder(context, _data, reload);
  }
}

/// A scrollable page that refreshes when pulled down.
class RefreshList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsets padding;

  const RefreshList({super.key, required this.onRefresh, required this.children, this.padding = const EdgeInsets.only(top: 8, bottom: 24)});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ],
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyView({super.key, this.icon = Icons.inbox_outlined, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(children: [
        Icon(icon, size: 52, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      ]),
    );
  }
}

/// A titled white card.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionCard({super.key, this.title, required this.child, this.trailing, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Row(children: [
              Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleLarge)),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
          ],
          child,
        ]),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: theme.bodySmall)),
        Expanded(child: Text(value, style: bold ? theme.titleMedium : theme.bodyMedium)),
      ]),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final String? status;

  const StatusBadge(this.label, {super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// A list row inside a card: title, subtitle, trailing badge, tap.
class ItemTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ItemTile({super.key, this.icon, this.iconColor, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: icon == null
            ? null
            : CircleAvatar(
                backgroundColor: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
              ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle == null ? null : Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_left) : null),
      ),
    );
  }
}

/// A small figure with a caption, for summary rows.
class StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const StatBox(this.value, this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: (color ?? AppColors.primary).withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color ?? AppColors.primary)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class Busy extends StatelessWidget {
  const Busy({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}

void toast(BuildContext context, String? message, {bool error = false}) {
  if (message == null || message.isEmpty) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'تأكيد'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for a line of text (a reason, a comment). Returns null when cancelled.
Future<String?> askText(BuildContext context, String title, {String? hint, bool required = true, String ok = 'إرسال'}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setLocal) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
          onChanged: (_) => setLocal(() {}),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: required && controller.text.trim().isEmpty ? null : () => Navigator.pop(c, controller.text.trim()),
            child: Text(ok),
          ),
        ],
      );
    }),
  );
  return result;
}

/// Runs an action that calls the server, shows its message, and returns whether it worked.
Future<bool> runAction(BuildContext context, Future<ApiResult> Function() action, {String? success}) async {
  try {
    final result = await action();
    if (context.mounted) toast(context, result.message ?? success);
    return true;
  } on ApiError catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
    return false;
  }
}

/// Opens a page and returns whatever it pops with.
Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// Pill-shaped floating action button (icon + label) used for «طلب ...» actions.
/// Built without FloatingActionButton so no theme constraint can turn it into a circle.
class ActionFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const ActionFab({super.key, required this.label, required this.onPressed, this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      elevation: 4,
      shadowColor: Colors.black38,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.textOnAccent, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(color: AppColors.textOnAccent, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
