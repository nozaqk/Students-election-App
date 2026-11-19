import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme/palette.dart';
import 'avatar.dart';

/// One candidate row (`.cand`). On the ballot it is selectable and shows a radio or checkbox;
/// on the information page it shows the programme and an expandable manifesto.
class CandidateTile extends StatelessWidget {
  const CandidateTile({
    super.key,
    required this.candidate,
    this.selected = false,
    this.onTap,
    this.multiple = false,
    this.showManifesto = false,
  });

  final Candidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  /// Draw a checkbox (several seats) instead of a radio (one seat).
  final bool multiple;
  final bool showManifesto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = candidate;
    final subtitle = c.programme ?? c.department;
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onTap != null) ...[
            _Control(selected: selected, multiple: multiple, onTap: onTap!),
            const SizedBox(width: 12),
          ],
          Avatar(name: c.name, src: c.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '  #${c.number}', style: TextStyle(color: p.muted, fontSize: 12)),
                    ],
                  ),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                if (showManifesto && c.manifesto.trim().isNotEmpty) _Manifesto(text: c.manifesto),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Abstain" row at the bottom of a position on the ballot.
class AbstainTile extends StatelessWidget {
  const AbstainTile({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _TileFrame(
        selected: selected,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Control(selected: selected, multiple: true, onTap: onTap),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Abstain', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.5)),
                  Text('I choose not to vote for this position.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.child, required this.selected, this.onTap});

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? p.green2 : p.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(selected ? 11 : 12), child: child),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.selected, required this.multiple, required this.onTap});

  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: 22,
        height: 22,
        child: multiple
            ? Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : Radio<bool>(
                value: true,
                groupValue: selected ? true : null,
                onChanged: (_) => onTap(),
                toggleable: true,
                activeColor: p.green2,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
      ),
    );
  }
}

/// `<details class="m"><summary>Manifesto</summary>…</details>`
class _Manifesto extends StatefulWidget {
  const _Manifesto({required this.text});

  final String text;

  @override
  State<_Manifesto> createState() => _ManifestoState();
}

class _ManifestoState extends State<_Manifesto> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_open ? Icons.expand_more : Icons.chevron_right, size: 18, color: p.green2),
                Text('Manifesto', style: TextStyle(color: p.green2, fontSize: 14)),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(widget.text, style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
      ],
    );
  }
}
