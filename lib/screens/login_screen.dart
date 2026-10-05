import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  bool _showServer = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _server.text = session.serverUrl;
    _showServer = session.serverUrl.isEmpty;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<Session>().login(_server.text, _email.text, _password.text);
    } on ApiError catch (e) {
      if (mounted) {
        toast(context, e.message, error: true);
        if (e.status == null) setState(() => _showServer = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF2A3F6A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('DOTS HR', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text('بوابة الموظفين والمدراء', style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 28),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('تسجيل الدخول', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        if (_showServer) ...[
                          TextFormField(
                            controller: _server,
                            keyboardType: TextInputType.url,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(labelText: 'عنوان خادم الشركة', hintText: 'hr.company.com', prefixIcon: Icon(Icons.dns_outlined)),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب عنوان الخادم الذي أعطتك إياه الموارد البشرية.' : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.alternate_email)),
                          validator: (v) => (v ?? '').contains('@') ? null : 'اكتب بريدك الإلكتروني.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _hide,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
                          ),
                          validator: (v) => (v ?? '').isEmpty ? 'اكتب كلمة المرور.' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: _busy ? null : _submit, child: _busy ? const Busy() : const Text('دخول')),
                        if (!_showServer)
                          TextButton(onPressed: () => setState(() => _showServer = true), child: const Text('تغيير عنوان الخادم')),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('نسيت كلمة المرور؟ تواصل مع الموارد البشرية.', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
