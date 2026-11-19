import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/importance.dart';
import '../state/overview_controller.dart';
import '../widgets/common.dart';
import '../widgets/election_card.dart';

/// Home tab: greeting plus the single most important election ("Happening now").
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.me,
    required this.overview,
    required this.onOpen,
    required this.onAll,
  });

  final Me? me;
  final OverviewController overview;
  final ValueChanged<String> onOpen;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: overview,
      builder: (context, _) {
        final data = overview.data;
        final err = overview.error;
        final ranked = data == null ? const <ElectionSummary>[] : byImportance(data.elections);
        final top = ranked.isEmpty ? null : ranked.first;
        final total = data?.elections.length ?? 0;
        final empty = data?.empty;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (me != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text.rich(
                  TextSpan(
                    text: 'Welcome, ',
                    children: [TextSpan(text: me!.fullName, style: const TextStyle(fontWeight: FontWeight.w700))],
                  ),
                  style: text.bodySmall,
                ),
              ),
            if (err != null) ErrorBox(err),
            if (data == null && err == null) const LoadingText(),
            if (empty != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empty.headline, style: text.titleLarge),
                    const SizedBox(height: 6),
                    Muted(empty.body),
                  ],
                ),
              ),
            if (top != null) ...[
              const SectionTitle('Happening now'),
              ElectionCard(election: top, skew: overview.skew, onOpen: () => onOpen(top.id)),
              if (total > 1) AppButton('See all elections ($total)', variant: ButtonVariant.secondary, onPressed: onAll),
            ],
          ],
        );
      },
    );
  }
}
