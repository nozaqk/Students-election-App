import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../api/session.dart';
import '../config.dart';
import '../widgets/common.dart';

enum AuthMode { login, register, recover }

enum _Step { details, verify }

/// Sign in, create account (two steps: details → emailed code + password) and password reset.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onDone, ApiClient? api, Session? session})
      : _api = api,
        _session = session;

  final VoidCallback onDone;
  final ApiClient? _api;
  final Session? _session;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final ApiClient _api = widget._api ?? ApiClient.instance;
  late final Session _session = widget._session ?? Session.instance;

  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _indexNumber = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _confirm = TextEditingController();

  AuthMode _mode = AuthMode.login;
  _Step _step = _Step.details;
  String? _sentTo;
  String? _err;
  bool _recovered = false;
  bool _busy = false;

  bool get _verifying => _mode != AuthMode.login && _step == _Step.verify;

  @override
  void dispose() {
    for (final c in [_fullName, _indexNumber, _email, _password, _code, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(AuthMode m) => setState(() {
        _err = null;
        _step = _Step.details;
        _sentTo = null;
        _mode = m;
        if (m != AuthMode.login) _recovered = false;
      });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _err = null);
    final index = _indexNumber.text.trim();

    // Step 1 of register / recover: send the verification code.
    if (_mode != AuthMode.login && _step == _Step.details) {
      setState(() => _busy = true);
      try {
        if (_mode == AuthMode.register) {
          final masked = await _api.registerStart(fullName: _fullName.text.trim(), indexNumber: index, email: _email.text.trim());
          _sentTo = masked;
        } else {
          await _api.recoverStart(indexNumber: index, email: _email.text.trim());
          _sentTo = _email.text.trim();
        }
        if (!mounted) return;
        setState(() => _step = _Step.verify);
      } on ApiError catch (e) {
        if (!mounted) return;
        setState(() => _err = e.message);
        if (e.code == 'ACCOUNT_EXISTS') _go(AuthMode.login);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (_mode != AuthMode.login) {
      if (_password.text.length < 10) {
        setState(() => _err = 'Use a password of at least 10 characters.');
        return;
      }
      if (_password.text != _confirm.text) {
        setState(() => _err = 'The passwords do not match.');
        return;
      }
    }

    setState(() => _busy = true);
    try {
      switch (_mode) {
        case AuthMode.login:
          final token = await _api.login(indexNumber: index, password: _password.text);
          await _session.setToken(token);
          widget.onDone();
        case AuthMode.register:
          final token = await _api.registerFinish(indexNumber: index, code: _code.text.trim(), password: _password.text);
          await _session.setToken(token);
          widget.onDone();
        case AuthMode.recover:
          await _api.recoverFinish(indexNumber: index, code: _code.text.trim(), newPassword: _password.text);
          if (!mounted) return;
          _password.clear();
          _confirm.clear();
          _code.clear();
          setState(() => _recovered = true);
          _go(AuthMode.login);
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _err = e.message);
      if (e.code == 'ACCOUNT_EXISTS') _go(AuthMode.login);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title {
    switch (_mode) {
      case AuthMode.login:
        return 'Sign in';
      case AuthMode.register:
        return 'Create account';
      case AuthMode.recover:
        return 'Reset password';
    }
  }

  String get _submitLabel {
    if (_mode == AuthMode.login) return 'Sign in';
    if (_step == _Step.details) return 'Send verification code';
    return _mode == AuthMode.register ? 'Verify and create account' : 'Reset password';
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final verifying = _verifying;
    final locked = verifying || _busy;
    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: math.max(0.0, constraints.maxHeight - 32)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Form(
                        key: _form,
                        child: AppCard(
                          elevated: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(_title, textAlign: TextAlign.center, style: text.titleLarge),
                              ),
                              if (_mode == AuthMode.register && _step == _Step.details)
                                const Muted(
                                  'Enter your name, official index number and your institutional email. We will email a verification code to confirm it is you.',
                                  margin: EdgeInsets.only(bottom: 12),
                                ),
                              if (_mode == AuthMode.recover && _step == _Step.details)
                                const Muted(
                                  'Enter your index number and the email on your student record. We will email you a code to reset your password.',
                                  margin: EdgeInsets.only(bottom: 12),
                                ),
                              if (verifying)
                                NoticeBox(
                                  text: _mode == AuthMode.register
                                      ? 'We sent a 6-character code to $_sentTo. It expires in 10 minutes.'
                                      : 'If the details match an account, a 6-character reset code was sent to $_sentTo. It expires in 10 minutes.',
                                ),
                              if (_recovered && _mode == AuthMode.login)
                                const NoticeBox(text: 'Password updated. Sign in with your new password.'),
                              if (_err != null) ErrorBox(_err!),
                              if (_mode == AuthMode.register)
                                LabeledField(
                                  label: 'Full name',
                                  child: TextFormField(
                                    controller: _fullName,
                                    enabled: !locked,
                                    autofillHints: const [AutofillHints.name],
                                    textCapitalization: TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    validator: _required,
                                  ),
                                ),
                              LabeledField(
                                label: 'Index number',
                                child: TextFormField(
                                  controller: _indexNumber,
                                  enabled: !locked,
                                  autofillHints: const [AutofillHints.username],
                                  textCapitalization: TextCapitalization.characters,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  validator: _required,
                                ),
                              ),
                              if (_mode != AuthMode.login)
                                LabeledField(
                                  label: 'Email',
                                  child: TextFormField(
                                    controller: _email,
                                    enabled: !locked,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      return v.contains('@') ? null : 'Enter a valid email address';
                                    },
                                  ),
                                ),
                              if (verifying)
                                LabeledField(
                                  label: _mode == AuthMode.register ? 'Verification code' : 'Reset code',
                                  child: TextFormField(
                                    controller: _code,
                                    enabled: !_busy,
                                    decoration: const InputDecoration(hintText: 'ABC123'),
                                    autofillHints: const [AutofillHints.oneTimeCode],
                                    textCapitalization: TextCapitalization.characters,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                                    validator: _required,
                                  ),
                                ),
                              if (_mode == AuthMode.login || verifying)
                                LabeledField(
                                  label: _mode == AuthMode.recover ? 'New password' : 'Password',
                                  child: TextFormField(
                                    controller: _password,
                                    enabled: !_busy,
                                    obscureText: true,
                                    autofillHints: [_mode == AuthMode.login ? AutofillHints.password : AutofillHints.newPassword],
                                    textInputAction: verifying ? TextInputAction.next : TextInputAction.done,
                                    onFieldSubmitted: verifying ? null : (_) => _submit(),
                                    validator: _required,
                                  ),
                                ),
                              if (verifying)
                                LabeledField(
                                  label: 'Confirm password',
                                  child: TextFormField(
                                    controller: _confirm,
                                    enabled: !_busy,
                                    obscureText: true,
                                    autofillHints: const [AutofillHints.newPassword],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: _required,
                                  ),
                                ),
                              AppButton(_busy ? 'Please wait…' : _submitLabel, onPressed: _submit, busy: _busy),
                              if (verifying)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Center(
                                    child: LinkButton(
                                      'Resend code / change details',
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() {
                                                _err = null;
                                                _step = _Step.details;
                                              }),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _mode == AuthMode.login
                          ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('New here? ', style: text.bodySmall),
                                    LinkButton('Create account', onPressed: () => _go(AuthMode.register)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinkButton('Forgot password?', onPressed: () => _go(AuthMode.recover)),
                              ],
                            )
                          : LinkButton('Back to sign in', onPressed: () => _go(AuthMode.login)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
