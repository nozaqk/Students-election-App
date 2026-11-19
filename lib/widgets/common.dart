import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// White card with a hairline border and 14px corners (`.card`).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 14),
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(Palette.radius),
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 6))]
            : null,
      ),
      child: child,
    );
  }
}

/// Secondary text (`.muted`).
class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.textAlign, this.margin = EdgeInsets.zero});

  final String text;
  final TextAlign? textAlign;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Text(text, textAlign: textAlign, style: Theme.of(context).textTheme.bodySmall),
      );
}

/// Page heading (`h2.page`).
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

/// Section heading (`h3.section`).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.padding = const EdgeInsets.only(top: 6, bottom: 8)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Status chip (`.pill`): colour-coded by election status.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});

  final String status;
  final String? label;

  static const Map<String, List<Color>> _colors = {
    'ACTIVE': [Color(0xFFD8F3E4), Color(0xFF0A6B3D)],
    'SCHEDULED': [Color(0xFFFDF0C7), Color(0xFF7A5600)],
    'PAUSED': [Color(0xFFF4DEDE), Color(0xFFA62D2D)],
    'DEACTIVATED': [Color(0xFFF4DEDE), Color(0xFFA62D2D)],
    'PUBLISHED': [Color(0xFFDDE8FB), Color(0xFF1D4BA0)],
  };

  /// Text shown for an election status in lists ("Voting open" for ACTIVE, else lower-cased).
  static String labelFor(String status) => status == 'ACTIVE' ? 'Voting open' : status.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colors = _colors[status];
    final bg = colors != null ? colors[0] : const Color(0xFFE7EFE9);
    final fg = colors != null ? colors[1] : p.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        (label ?? status.toLowerCase()).toUpperCase(),
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, height: 1.5),
      ),
    );
  }
}

enum ButtonVariant { primary, secondary, danger }

/// Full-width action button (`.btn`, `.btn.secondary`, `.btn.danger`).
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.busy = false,
    this.margin = EdgeInsets.zero,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool busy;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !busy;
    final Color bg;
    final Color fg;
    BorderSide? border;
    switch (variant) {
      case ButtonVariant.primary:
        bg = p.green2;
        fg = Colors.white;
      case ButtonVariant.danger:
        bg = p.red;
        fg = Colors.white;
      case ButtonVariant.secondary:
        bg = Colors.transparent;
        fg = p.ink;
        border = BorderSide(color: p.line);
    }
    return Padding(
      padding: margin,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: border ?? BorderSide.none),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy) ...[
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline underlined text button (`.link`).
class LinkButton extends StatelessWidget {
  const LinkButton(this.label, {super.key, required this.onPressed, this.fontSize = 14.7});

  final String label;
  final VoidCallback? onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          style: TextStyle(color: p.green2, decoration: TextDecoration.underline, decorationColor: p.green2, fontSize: fontSize),
        ),
      ),
    );
  }
}

/// Small outlined pill button used in card headers (`.link-btn`) and the top bar.
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onPressed, this.light = false});

  final String label;
  final VoidCallback? onPressed;

  /// White text and border, for the green header.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = light ? Colors.white : p.ink;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: light ? Colors.white.withAlpha(102) : p.line)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14.5)),
        ),
      ),
    );
  }
}

/// Gold-edged notice (`.notice`). Either [text] or [child].
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, this.text, this.child, this.margin = const EdgeInsets.only(bottom: 12)})
      : assert(text != null || child != null, 'NoticeBox needs text or a child');

  final String? text;
  final Widget? child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: p.gold.withAlpha(36),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: p.gold, width: 4)),
      ),
      child: child ?? Text(text!, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// Red error banner (`.err`).
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.text, {super.key, this.margin = const EdgeInsets.only(bottom: 12)});

  final String text;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.errBg,
          border: Border.all(color: p.errBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(color: p.errInk, fontSize: 16, height: 1.5)),
      ),
    );
  }
}

/// Labelled form control (`.field`).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: TextStyle(color: p.muted, fontSize: 13.6)),
          ),
          child,
        ],
      ),
    );
  }
}

/// Loading placeholder text.
class LoadingText extends StatelessWidget {
  const LoadingText([this.text = 'Loading…', Key? key]) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) => Muted(text, margin: const EdgeInsets.symmetric(vertical: 8));
}

/// Two-column definition list (`.kv`).
class KeyValueList extends StatelessWidget {
  const KeyValueList(this.rows, {super.key});

  /// Label → value pairs, in display order.
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final row in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14, bottom: 6),
                  child: Text(row.key, style: TextStyle(color: p.muted, fontSize: 16, height: 1.5)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(row.value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, height: 1.5)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
