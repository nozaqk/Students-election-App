import 'package:flutter/material.dart';

import '../state/importance.dart';
import '../state/overview_controller.dart';
import '../widgets/common.dart';
import '../widgets/election_card.dart';

/// Elections tab: every election the student can see, most important first.
class ElectionsScreen extends StatelessWidget {
  const ElectionsScreen({super.key, required this.overview, required this.onOpen});

  final OverviewController overview;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: overview,
      builder: (context, _) {
        final data = overview.data;
        final err = overview.error;
        final empty = data?.empty;
        return RefreshIndicator(
          onRefresh: overview.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const PageTitle('Elections'),
              if (err != null) ErrorBox(err),
              if (data == null && err == null) const LoadingText('Loading elections…'),
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
              if (data != null)
                for (final e in byImportance(data.elections))
                  ElectionCard(election: e, skew: overview.skew, onOpen: () => onOpen(e.id)),
            ],
          ),
        );
      },
    );
  }
}
