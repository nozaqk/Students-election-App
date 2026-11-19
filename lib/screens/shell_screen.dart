import 'package:flutter/material.dart';

import '../api/models.dart';
import '../config.dart';
import '../state/overview_controller.dart';
import '../theme/palette.dart';
import '../widgets/bt_badge.dart';
import '../widgets/common.dart';
import 'election/election_screen.dart';
import 'elections_screen.dart';
import 'home_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';

enum AppTab { home, news, elections, settings }

extension on AppTab {
  String get label {
    switch (this) {
      case AppTab.home:
        return 'Home';
      case AppTab.news:
        return 'News';
      case AppTab.elections:
        return 'Election';
      case AppTab.settings:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case AppTab.home:
        return Icons.home_outlined;
      case AppTab.news:
        return Icons.newspaper_outlined;
      case AppTab.elections:
        return Icons.how_to_vote_outlined;
      case AppTab.settings:
        return Icons.settings_outlined;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case AppTab.home:
        return Icons.home;
      case AppTab.news:
        return Icons.newspaper;
      case AppTab.elections:
        return Icons.how_to_vote;
      case AppTab.settings:
        return Icons.settings;
    }
  }
}

/// Signed-in frame: green header (title or "← Back" plus the Bluetooth badge), the current tab,
/// and the bottom menu. The menu is hidden while an election is open so nobody leaves a
/// half-finished ballot by accident; "Back" (or the system back gesture) returns to the list.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.me, required this.onMeChanged, required this.onSignOut});

  final Me? me;
  final ValueChanged<Me> onMeChanged;
  final VoidCallback onSignOut;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final OverviewController _overview = OverviewController();
  AppTab _tab = AppTab.home;
  String? _electionId;

  @override
  void initState() {
    super.initState();
    _overview.start();
  }

  @override
  void dispose() {
    _overview.dispose();
    super.dispose();
  }

  void _open(String id) => setState(() => _electionId = id);

  void _back() {
    setState(() => _electionId = null);
    _overview.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final electionId = _electionId;
    final inElection = electionId != null;

    return PopScope(
      canPop: !inElection,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inElection) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: inElection
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: PillButton('← Back', light: true, onPressed: _back),
                )
              : const Text(AppConfig.appName),
          actions: const [
            Padding(padding: EdgeInsets.only(right: 16), child: BtBadge()),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: inElection
                  ? ElectionScreen(key: ValueKey('election-$electionId'), id: electionId)
                  : _tabBody(),
            ),
          ),
        ),
        bottomNavigationBar: inElection
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: p.card,
                  border: Border(top: BorderSide(color: p.line)),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, -4))],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                    child: Row(
                      children: [
                        for (final t in AppTab.values)
                          Expanded(
                            child: _TabButton(
                              tab: t,
                              selected: _tab == t,
                              onTap: () => setState(() => _tab = t),
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

  Widget _tabBody() {
    switch (_tab) {
      case AppTab.home:
        return HomeScreen(
          key: const ValueKey('home'),
          me: widget.me,
          overview: _overview,
          onOpen: _open,
          onAll: () => setState(() => _tab = AppTab.elections),
        );
      case AppTab.news:
        return NewsScreen(key: const ValueKey('news'), overview: _overview, onOpen: _open);
      case AppTab.elections:
        return ElectionsScreen(key: const ValueKey('elections'), overview: _overview, onOpen: _open);
      case AppTab.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          me: widget.me,
          onSaved: widget.onMeChanged,
          onSignOut: widget.onSignOut,
        );
    }
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.green2 : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: p.green2.withAlpha(26),
        highlightColor: p.green2.withAlpha(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
