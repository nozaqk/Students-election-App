import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_error.dart';
import '../../api/models.dart';
import '../../theme/palette.dart';
import '../../widgets/common.dart';

/// Published results: turnout, then one card per position with a vote bar per candidate.
class ResultsView extends StatefulWidget {
  const ResultsView({super.key, required this.id, ApiClient? api}) : _api = api;

  final String id;
  final ApiClient? _api;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  late final ApiClient _api = widget._api ?? ApiClient.instance;
  Results? _r;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.results(widget.id);
      if (mounted) setState(() => _r = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final err = _err;
    if (err != null) return ListView(padding: const EdgeInsets.all(16), children: [ErrorBox(err)]);
    if (r == null) return const Padding(padding: EdgeInsets.all(16), child: LoadingText('Loading results…'));

    final text = Theme.of(context).textTheme;
    final p = context.palette;
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
                  Expanded(child: Text(r.title, style: text.titleLarge)),
                  const SizedBox(width: 12),
                  const Padding(padding: EdgeInsets.only(top: 6), child: StatusPill('PUBLISHED', label: 'Published')),
                ],
              ),
              const SizedBox(height: 6),
              Muted('Official results · published ${r.publishedLabel ?? ''}\nTotal ballots cast: ${r.turnout}'),
            ],
          ),
        ),
        for (final pos in r.results)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(pos.title, style: text.titleMedium),
                const SizedBox(height: 6),
                if (pos.tie) const NoticeBox(text: 'Tie: a runoff is required between the tied candidates.'),
                for (final c in pos.candidates) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (c.winner) const TextSpan(text: '★ '),
                              TextSpan(text: c.name),
                              TextSpan(text: '  #${c.number}', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w400)),
                              if (c.tied) const TextSpan(text: ' (tied)'),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: c.winner ? p.win : p.ink,
                            fontWeight: c.winner ? FontWeight.w800 : FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${c.votes}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pos.share(c).clamp(0, 1).toDouble(),
                        minHeight: 8,
                        backgroundColor: p.line,
                        color: p.green2,
                      ),
                    ),
                  ),
                ],
                Muted('Abstained: ${pos.abstained}'),
              ],
            ),
          ),
      ],
    );
  }
}
