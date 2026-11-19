import 'package:flutter/material.dart';

import '../state/importance.dart';
import '../state/overview_controller.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';

/// News tab: one announcement card per election with its current headline and voting window.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.overview, required this.onOpen});

  final OverviewController overview;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return AnimatedBuilder(
      animation: overview,
      builder: (context, _) {
        final data = overview.data;
        final err = overview.error;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const PageTitle('News'),
            if (err != null) ErrorBox(err),
            if (data == null && err == null) const LoadingText(),
            if (data != null && data.elections.isEmpty)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No news yet', style: text.titleMedium),
                    const SizedBox(height: 6),
                    const Muted('Election announcements and results will appear here.'),
                  ],
                ),
              ),
            if (data != null)
              for (final e in byImportance(data.elections))
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Muted(e.title)),
                          const SizedBox(width: 12),
                          StatusPill(e.status, label: StatusPill.labelFor(e.status)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Text(e.ui.headline, style: text.titleMedium),
                      ),
                      if (e.ui.body.isNotEmpty) Muted(e.ui.body),
                      if (e.startLabel != null && e.endLabel != null)
                        Muted('Voting: ${e.startLabel} to ${e.endLabel}', margin: const EdgeInsets.only(top: 8)),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          onTap: () => onOpen(e.id),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Text(
                              '${e.isPublished ? 'View results' : 'Open election'} →',
                              style: TextStyle(color: p.green2, decoration: TextDecoration.underline, decorationColor: p.green2, fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
