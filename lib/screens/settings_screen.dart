import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../api/models.dart';
import '../widgets/common.dart';

const List<int> _levels = [100, 200, 300, 400, 500, 600];

/// Settings tab: the student's account (name, level and semester are editable), an About note and
/// sign out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.me, required this.onSaved, required this.onSignOut, ApiClient? api})
      : _api = api;

  final Me? me;
  final ValueChanged<Me> onSaved;
  final VoidCallback onSignOut;
  final ApiClient? _api;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ApiClient _api = widget._api ?? ApiClient.instance;
  final _name = TextEditingController();
  bool _editing = false;
  int _level = 100;
  int _semester = 1;
  bool _busy = false;
  bool? _msgOk;
  String? _msg;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _startEdit() {
    final me = widget.me;
    if (me == null) return;
    setState(() {
      _name.text = me.fullName;
      _level = me.level;
      _semester = me.semester ?? 1;
      _msg = null;
      _editing = true;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final m = await _api.updateProfile(fullName: _name.text.trim(), level: _level, semester: _semester);
      widget.onSaved(m);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _msgOk = true;
        _msg = 'Saved.';
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _msgOk = false;
        _msg = e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your index number and password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (yes == true) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final text = Theme.of(context).textTheme;
    final levels = _levels.contains(_level) ? _levels : ([..._levels, _level]..sort());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const PageTitle('Settings'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('My account', style: text.titleMedium)),
                  if (me != null && !_editing) PillButton('Edit', onPressed: _startEdit),
                ],
              ),
              const SizedBox(height: 6),
              if (_msg != null) (_msgOk == true ? NoticeBox(text: _msg!) : ErrorBox(_msg!)),
              if (me == null)
                const LoadingText()
              else if (_editing)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      label: 'Name',
                      child: TextField(
                        controller: _name,
                        enabled: !_busy,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(counterText: ''),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    LabeledField(
                      label: 'Level',
                      child: DropdownButtonFormField<int>(
                        value: _level,
                        items: [for (final l in levels) DropdownMenuItem(value: l, child: Text('Level $l'))],
                        onChanged: _busy ? null : (v) => setState(() => _level = v ?? _level),
                      ),
                    ),
                    LabeledField(
                      label: 'Semester',
                      child: DropdownButtonFormField<int>(
                        value: _semester,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Semester 1')),
                          DropdownMenuItem(value: 2, child: Text('Semester 2')),
                        ],
                        onChanged: _busy ? null : (v) => setState(() => _semester = v ?? _semester),
                      ),
                    ),
                    AppButton(
                      _busy ? 'Saving…' : 'Save changes',
                      busy: _busy,
                      onPressed: _name.text.trim().length < 2 ? null : _save,
                    ),
                    AppButton(
                      'Cancel',
                      variant: ButtonVariant.secondary,
                      margin: const EdgeInsets.only(top: 8),
                      onPressed: _busy ? null : () => setState(() => _editing = false),
                    ),
                  ],
                )
              else
                KeyValueList([
                  MapEntry('Name', me.fullName),
                  MapEntry('Index number', me.indexNumber),
                  MapEntry('Department', me.department),
                  MapEntry('Programme', me.programme),
                  MapEntry('Level', 'Level ${me.level}'),
                  MapEntry('Semester', me.semester != null ? 'Semester ${me.semester}' : 'Not set'),
                ]),
              const SizedBox(height: 8),
              const Muted(
                'Only your name, level and semester can be changed here, and only on your profile. Department, programme and which elections you can vote in come from the official student register.',
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About', style: text.titleMedium),
              const SizedBox(height: 6),
              const Muted('All election times are shown in Ghana time (Africa/Accra). Your votes are private and cannot be linked back to you.'),
            ],
          ),
        ),
        AppButton('Sign out', variant: ButtonVariant.danger, onPressed: _confirmSignOut),
      ],
    );
  }
}
