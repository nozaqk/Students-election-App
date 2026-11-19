import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_error.dart';
import '../../api/models.dart';
import '../../config.dart';
import '../../widgets/candidate_tile.dart';
import '../../widgets/common.dart';
import '../../widgets/countdown.dart';
import 'results_view.dart';
import 'vote_flow.dart';

/// One election: status, countdown, positions and candidates, and the entry point to voting.
/// Refreshes every 10 s so a paused or closed election is reflected promptly.
class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key, required this.id, ApiClient? api}) : _api = api;

  final String id;
  final ApiClient? _api;

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  late final ApiClient _api = widget._api ?? ApiClient.instance;
  ElectionDetail? _d;
  String? _err;
  bool _voting = false;
  Duration _skew = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(AppConfig.overviewRefresh, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final x = await _api.election(widget.id);
      if (!mounted) return;
      setState(() {
        _d = x;
        _skew = x.serverTime.difference(DateTime.now());
        _err = null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final err = _err;
    if (d == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [if (err != null) ErrorBox(err) else const LoadingText()],
      );
    }
    if (d.isPublished) return ResultsView(id: widget.id, api: _api);
    if (_voting && d.isActive) {
      return VoteFlow(
        election: d,
        api: _api,
        onExit: () {
          setState(() => _voting = false);
          unawaited(_load());
        },
      );
    }

    final text = Theme.of(context).textTheme;
    final startAt = d.startAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(d.title, style: text.titleLarge)),
                  const SizedBox(width: 12),
                  Padding(padding: const EdgeInsets.only(top: 6), child: StatusPill(d.status)),
                ],
              ),
              if (d.description.isNotEmpty) Muted(d.description, margin: const EdgeInsets.only(top: 6)),
              NoticeBox(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: d.ui.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (d.ui.body.isNotEmpty) TextSpan(text: '\n${d.ui.body}'),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
              ),
              if (d.isScheduled && startAt != null) ...[
                const Muted('Voting opens in'),
                Countdown(to: startAt, skew: _skew),
              ],
              if (d.hasVoted)
                const NoticeBox(
                  text: '✓ You have voted in this election. Your choices are private and cannot be viewed.',
                  margin: EdgeInsets.only(top: 12),
                ),
              if (d.canVote)
                AppButton('Vote Now', margin: const EdgeInsets.only(top: 12), onPressed: () => setState(() => _voting = true)),
            ],
          ),
        ),
        const SectionTitle('Positions and candidates'),
        for (final p in d.positions)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(p.title, style: text.titleMedium)),
                for (final c in p.candidates) CandidateTile(candidate: c, showManifesto: true),
                if (p.candidates.isEmpty) const Muted('No candidates have been announced yet.'),
              ],
            ),
          ),
      ],
    );
  }
}
