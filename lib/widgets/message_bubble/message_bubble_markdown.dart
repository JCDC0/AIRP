import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';

class MessageBubbleMarkdown extends StatelessWidget {
  final String text;
  final ThemeProvider themeProvider;
  final ScaleProvider scaleProvider;
  final Color textColor;
  final bool useBloom;
  final String? searchQuery;
  final bool isCurrentSearchMessage;

  const MessageBubbleMarkdown({
    super.key,
    required this.text,
    required this.themeProvider,
    required this.scaleProvider,
    required this.textColor,
    required this.useBloom,
    this.searchQuery,
    this.isCurrentSearchMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    // One source for the bloom shadow. Copying the ternary per element is why
    // italic and bold never glowed while paragraphs, links and headings did,
    // and roleplay prose is mostly *actions* and **emphasis**, so the gap
    // showed in exactly the text the effect is for.
    List<Shadow> glow(Color color, double blurRadius) => useBloom
        ? [Shadow(color: color, blurRadius: blurRadius)]
        : const <Shadow>[];

    final codeStyle = TextStyle(
      color: textColor,
      backgroundColor: themeProvider.containerFillColor,
      shadows: glow(textColor.withValues(alpha: 0.9), 4),
      fontFamily: 'monospace',
      fontSize: scaleProvider.chatFontSize - 2,
    );

    final hasSearchQuery = searchQuery != null && searchQuery!.isNotEmpty;

    return MarkdownBody(
      data: text,
      onTapLink: (text, href, title) {
        if (href == null || href.trim().isEmpty) return;
        final uri = Uri.tryParse(href);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      inlineSyntaxes: hasSearchQuery
          ? [
              _SearchHitSyntax(
                searchQuery!,
                isCurrentMatch: isCurrentSearchMessage,
              ),
            ]
          : const [],
      builders: {
        'code': CodeElementBuilder(context, codeStyle, themeProvider),
        if (hasSearchQuery)
          'search-hit': _SearchHitBuilder(
            themeProvider: themeProvider,
            scaleProvider: scaleProvider,
            isCurrentMatch: isCurrentSearchMessage,
          ),
      },
      styleSheet: MarkdownStyleSheet(
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(color: Colors.transparent),
        p: TextStyle(
          color: themeProvider.markdownParagraphColor,
          fontSize: scaleProvider.chatFontSize,
          shadows: glow(textColor.withValues(alpha: 0.9), 15),
        ),
        a: TextStyle(
          color: themeProvider.markdownLinkColor,
          fontSize: scaleProvider.chatFontSize,
          decoration: TextDecoration.underline,
          shadows: glow(Colors.blueAccent, 8),
        ),
        code: codeStyle,
        h1: TextStyle(
          color: themeProvider.markdownStructureColor,
          fontSize: scaleProvider.chatFontSize + 8,
          fontWeight: FontWeight.bold,
          shadows: glow(textColor, 10),
        ),
        h2: TextStyle(
          color: themeProvider.markdownStructureColor,
          fontSize: scaleProvider.chatFontSize + 6,
          fontWeight: FontWeight.bold,
          shadows: glow(textColor, 10),
        ),
        h3: TextStyle(
          color: themeProvider.markdownStructureColor,
          fontSize: scaleProvider.chatFontSize + 4,
          fontWeight: FontWeight.bold,
          shadows: glow(textColor, 10),
        ),
        // Each blooms in its own colour, so a user-tinted bold glows to
        // match rather than halo-ing in the paragraph colour.
        em: TextStyle(
          color: themeProvider.markdownItalicColor,
          fontStyle: FontStyle.italic,
          shadows: glow(themeProvider.markdownItalicColor, 12),
        ),
        strong: TextStyle(
          color: themeProvider.markdownBoldColor,
          fontWeight: FontWeight.bold,
          shadows: glow(themeProvider.markdownBoldColor, 12),
        ),
        del: TextStyle(
          color: themeProvider.markdownStructureColor,
          shadows: glow(themeProvider.markdownStructureColor, 10),
        ),
        listBullet: TextStyle(
          color: themeProvider.markdownStructureColor,
          shadows: glow(themeProvider.markdownStructureColor, 10),
        ),
        blockquote: TextStyle(
          color: themeProvider.markdownBlockquoteColor,
          fontStyle: FontStyle.italic,
          shadows: glow(themeProvider.markdownBlockquoteColor, 10),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: themeProvider.markdownBlockquoteColor.withValues(
                alpha: 0.5,
              ),
              width: 4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom inline syntax for highlighting search terms in markdown.
class _SearchHitSyntax extends md.InlineSyntax {
  _SearchHitSyntax(String query, {required bool isCurrentMatch})
    : super(RegExp.escape(query), caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('search-hit', match.group(0)!));
    return true;
  }
}

/// Custom builder for rendering highlighted search hits.
class _SearchHitBuilder extends MarkdownElementBuilder {
  final ThemeProvider themeProvider;
  final ScaleProvider scaleProvider;
  final bool isCurrentMatch;

  _SearchHitBuilder({
    required this.themeProvider,
    required this.scaleProvider,
    required this.isCurrentMatch,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final Color highlightColor = isCurrentMatch
        ? themeProvider.bloomGlowColor.withValues(alpha: 0.35)
        : themeProvider.bloomGlowColor.withValues(alpha: 0.18);
    final Color textColor = isCurrentMatch
        ? themeProvider.bloomGlowColor
        : themeProvider.textColor;

    return Text(
      element.textContent,
      style: TextStyle(
        backgroundColor: highlightColor,
        color: textColor,
        fontWeight: isCurrentMatch ? FontWeight.bold : FontWeight.normal,
        fontSize: scaleProvider.chatFontSize,
        shadows: isCurrentMatch
            ? [
                Shadow(
                  color: themeProvider.bloomGlowColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final TextStyle textStyle;
  final ThemeProvider themeProvider;

  CodeElementBuilder(this.context, this.textStyle, this.themeProvider);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      } else {
        language = lg;
      }
    }

    final bool isBlock =
        language.isNotEmpty || element.textContent.contains('\n');

    if (!isBlock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: themeProvider.containerFillColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: themeProvider.borderColor),
        ),
        child: Text(
          element.textContent,
          style: textStyle.copyWith(fontSize: (textStyle.fontSize ?? 14) * 0.9),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.containerFillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: themeProvider.dividerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (language.isNotEmpty)
                  Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      color: themeProvider.subtitleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: element.textContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy,
                        color: themeProvider.subtitleColor,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Copy Code",
                        style: TextStyle(
                          color: themeProvider.subtitleColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              element.textContent.trimRight(),
              style: textStyle.copyWith(backgroundColor: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

class InlineTypingDots extends StatefulWidget {
  final double iconScale;

  const InlineTypingDots({super.key, required this.iconScale});

  @override
  State<InlineTypingDots> createState() => _InlineTypingDotsState();
}

class _InlineTypingDotsState extends State<InlineTypingDots>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double dotSize = 8 * widget.iconScale;
        final double dotSpacing = 4 * widget.iconScale;
        final double bounceHeight = 4 * widget.iconScale;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double delay = index * 0.2;
            final double t = ((_controller.value - delay) % 1.0).clamp(
              0.0,
              1.0,
            );
            final double bounce = (t < 0.5) ? (t * 2) : (2 - t * 2);
            final double offset = -bounceHeight * bounce;

            return Padding(
              padding: EdgeInsets.only(right: index < 2 ? dotSpacing : 0),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: themeProvider.textColor.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
