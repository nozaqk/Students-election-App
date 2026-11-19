import 'package:flutter/material.dart';

import '../api/models.dart';
import 'common.dart';
import 'countdown.dart';

/// Summary card for one election, used on Home and the Elections list.
class ElectionCard extends StatelessWidget {
  const ElectionCard({super.key, required this.election, required this.skew, required this.onOpen});

  final ElectionSummary election;
  final Duration skew;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = election;
    final text = Theme.of(context).textTheme;
    final startAt = e.startAt;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(e.title, style: text.titleLarge)),
              const SizedBox(width: 12),
              Padding(padding: const EdgeInsets.only(top: 6), child: StatusPill(e.status, label: StatusPill.labelFor(e.status))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(e.ui.headline, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.5)),
          ),
          if (e.ui.body.isNotEmpty) Muted(e.ui.body),
          if (e.isScheduled && startAt != null) ...[
            const Muted('Voting opens in', margin: EdgeInsets.only(top: 8)),
            Countdown(to: startAt, skew: skew),
          ],
          if (e.hasVoted) const NoticeBox(text: '✓ You have voted in this election.', margin: EdgeInsets.only(top: 12)),
          AppButton(
            e.canVote
                ? 'Vote Now'
                : e.isPublished
                    ? 'View results'
                    : 'View details',
            onPressed: onOpen,
            margin: const EdgeInsets.only(top: 12),
          ),
        ],
      ),
    );
  }
}
