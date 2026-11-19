import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_error.dart';
import '../../api/models.dart';
import '../../native/beacon_parser.dart';
import '../../native/ble_scanner.dart';
import '../../native/bluetooth_monitor.dart';
import '../../native/native_error.dart';
import '../../native/permissions.dart';
import '../../widgets/candidate_tile.dart';
import '../../widgets/common.dart';

enum VoteStep { verify, ballot, review, done }

/// The voting journey: verify presence at the polling location (Bluetooth beacon), fill the
/// ballot within the authorisation window, review, submit, receipt.
class VoteFlow extends StatefulWidget {
  const VoteFlow({
    super.key,
    required this.election,
    required this.onExit,
    ApiClient? api,
    BleScanner? scanner,
    BluetoothMonitor? monitor,
  })  : _api = api,
        _scanner = scanner,
        _monitor = monitor;

  final ElectionDetail election;
  final VoidCallback onExit;
  final ApiClient? _api;
  final BleScanner? _scanner;
  final BluetoothMonitor? _monitor;

  @override
  State<VoteFlow> createState() => _VoteFlowState();
}

class _VoteFlowState extends State<VoteFlow> {
  late final ApiClient _api = widget._api ?? ApiClient.instance;
  late final BleScanner _scanner = widget._scanner ?? BleScanner.instance;
  late final BluetoothMonitor _monitor = widget._monitor ?? BluetoothMonitor.instance;

  ElectionDetail get d => widget.election;

  VoteStep _step = VoteStep.verify;
  VoteAuthorization? _auth;
  final Map<String, PositionChoice> _choices = {};
  String? _err;
  bool _busy = false;
  bool _needSettings = false;
  String? _receipt;
  int _left = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Presence is not required: obtain the single-use authorisation straight away.
    if (!d.requirePresence) unawaited(_verify());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Step 1: presence ────────────────────────────────────────────────────────

  Future<void> _verify() async {
    setState(() {
      _err = null;
      _busy = true;
      _needSettings = false;
    });
    try {
      // Try each nearby beacon (strongest first) until the server accepts one; ignore look-alikes
      // from other devices.
      final List<BeaconClaim?> claims = d.requirePresence ? await _scanner.scan() : const [null];
      if (d.requirePresence) _monitor.markNodeSeen();
      VoteAuthorization? r;
      ApiError? last;
      for (final claim in claims) {
        try {
          r = await _api.presence(d.id, claim: claim);
          break;
        } on ApiError catch (e) {
          last = e;
          if (e.code != 'NODE_REJECTED') rethrow;
        }
      }
      final auth = r;
      if (auth == null) throw last ?? const ApiError(0, 'Could not verify your location.');
      if (!mounted) return;
      setState(() {
        _auth = auth;
        _step = VoteStep.ballot;
      });
      _startTicker();
    } on NativeError catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.message;
        _needSettings = e.needsSettings;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _err = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = 'Something went wrong while verifying. Try again. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final auth = _auth;
    if (auth == null || _step == VoteStep.done) {
      _ticker?.cancel();
      return;
    }
    final s = auth.expiresAt.difference(DateTime.now()).inSeconds;
    if (!mounted) return;
    if (s <= 0) {
      _ticker?.cancel();
      setState(() {
        _left = 0;
        _auth = null;
        _step = VoteStep.verify;
        _err = 'Your voting authorisation expired. Verify again to continue; your selections are kept.';
      });
    } else {
      setState(() => _left = s);
    }
  }

  // ── Step 2: ballot ──────────────────────────────────────────────────────────

  void _toggle(Position p, String cid) {
    setState(() {
      final cur = _choices[p.id] ?? const PositionChoice();
      List<String> ids;
      if (p.single) {
        ids = cur.candidateIds.contains(cid) ? const [] : [cid];
      } else {
        ids = cur.candidateIds.contains(cid)
            ? cur.candidateIds.where((x) => x != cid).toList()
            : [...cur.candidateIds, cid];
      }
      if (ids.length > p.maxSelections) return;
      _choices[p.id] = PositionChoice(candidateIds: ids);
    });
  }

  void _abstain(Position p) {
    setState(() {
      final cur = _choices[p.id] ?? const PositionChoice();
      _choices[p.id] = PositionChoice(abstain: !cur.abstain);
    });
  }

  bool get _complete => d.positions.every((p) => _choices[p.id]?.complete ?? false);

  // ── Step 3: submit ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final auth = _auth;
    if (auth == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final receipt = await _api.vote(
        d.id,
        authorization: auth.token,
        choices: [for (final p in d.positions) (_choices[p.id] ?? const PositionChoice()).toJson(p.id)],
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _auth = null;
        _step = VoteStep.done;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.message;
        if (e.code == 'AUTH_EXPIRED' || e.code == 'AUTH_USED') {
          _auth = null;
          _step = VoteStep.verify;
        }
        if (e.code == 'ALREADY_VOTED') _step = VoteStep.done;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case VoteStep.done:
        return _done(context);
      case VoteStep.verify:
        return _verifyView(context);
      case VoteStep.review:
        return _review(context);
      case VoteStep.ballot:
        return _ballot(context);
    }
  }

  Widget _done(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final receipt = _receipt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(receipt != null ? 'Vote recorded' : 'Already voted', style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                receipt != null
                    ? 'Thank you. Your ballot was accepted.'
                    : 'Our records show you have already voted in this election.',
              ),
              if (receipt != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Receipt: '),
                        TextSpan(
                          text: receipt.length > 8 ? receipt.substring(0, 8) : receipt,
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: '\nThis receipt proves you voted, not how you voted.'),
                      ],
                    ),
                    style: text.bodySmall,
                  ),
                ),
              AppButton('Done', margin: const EdgeInsets.only(top: 8), onPressed: widget.onExit),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verifyView(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final err = _err;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(d.requirePresence ? 'Verify you are at the polling location' : 'Preparing your ballot', style: text.titleLarge),
              const SizedBox(height: 6),
              if (d.requirePresence)
                const Muted(
                  'Stand near the polling device and keep Bluetooth on. You only need to be nearby for this step; once verified you can vote from where you are.',
                  margin: EdgeInsets.only(bottom: 12),
                ),
              if (err != null) ErrorBox(err),
              if (_needSettings)
                const AppButton(
                  'Open app settings',
                  variant: ButtonVariant.secondary,
                  margin: EdgeInsets.only(bottom: 8),
                  onPressed: AppPermissions.openAppSettings,
                ),
              AppButton(
                _busy
                    ? (d.requirePresence ? 'Scanning…' : 'Please wait…')
                    : (d.requirePresence ? 'Verify my location' : 'Continue'),
                busy: _busy,
                onPressed: _verify,
              ),
              AppButton(
                'Cancel',
                variant: ButtonVariant.secondary,
                margin: const EdgeInsets.only(top: 8),
                onPressed: _busy ? null : widget.onExit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _review(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final err = _err;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review your ballot', style: text.titleLarge),
              const SizedBox(height: 6),
              Muted('Once submitted, your vote cannot be changed. Authorisation expires in ${_left < 0 ? 0 : _left}s.'),
            ],
          ),
        ),
        for (final p in d.positions)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Muted(p.title),
                Text(_summary(p), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.5)),
              ],
            ),
          ),
        if (err != null) ErrorBox(err),
        AppButton(_busy ? 'Submitting…' : 'Submit my vote', busy: _busy, onPressed: _submit),
        AppButton(
          'Back',
          variant: ButtonVariant.secondary,
          margin: const EdgeInsets.only(top: 8),
          onPressed: _busy ? null : () => setState(() => _step = VoteStep.ballot),
        ),
      ],
    );
  }

  String _summary(Position p) {
    final c = _choices[p.id] ?? const PositionChoice();
    if (c.abstain) return 'Abstain';
    return p.candidates.where((x) => c.candidateIds.contains(x.id)).map((x) => x.name).join(', ');
  }

  Widget _ballot(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final err = _err;
    final complete = _complete;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        NoticeBox(text: 'Verified. Complete your ballot within ${_left < 0 ? 0 : _left}s.'),
        if (err != null) ErrorBox(err),
        for (final p in d.positions)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(p.title, style: text.titleMedium),
                Muted(
                  p.single ? 'Choose one candidate.' : 'Choose up to ${p.maxSelections} candidates.',
                  margin: const EdgeInsets.only(bottom: 10),
                ),
                for (final cand in p.candidates)
                  CandidateTile(
                    candidate: cand,
                    multiple: !p.single,
                    selected: (_choices[p.id]?.candidateIds ?? const []).contains(cand.id),
                    onTap: () => _toggle(p, cand.id),
                  ),
                if (p.allowAbstain) AbstainTile(selected: _choices[p.id]?.abstain ?? false, onTap: () => _abstain(p)),
              ],
            ),
          ),
        AppButton('Review ballot', onPressed: complete ? () => setState(() => _step = VoteStep.review) : null),
        if (!complete)
          const Muted('Make a choice (or abstain) for every position.', textAlign: TextAlign.center, margin: EdgeInsets.only(top: 12)),
      ],
    );
  }
}
