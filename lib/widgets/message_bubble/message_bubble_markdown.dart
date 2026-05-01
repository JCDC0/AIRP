import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';

class MessageBubbleMarkdown extends StatelessWidget {
  final String text;
  final ThemeProvider themeProvider;
  final ScaleProvider scaleProvider;
  final Color textColor;
  final bool useBloom;

  const MessageBubbleMarkdown({
    super.key,
    required this.text,
    required this.themeProvider,
    required this.scaleProvider,
    required this.textColor,
    required this.useBloom,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final codeStyle = TextStyle(
      color: textColor,
      backgroundColor: themeProvider.containerFillColor,
      shadows: useBloom
          ? [Shadow(color: textColor.withValues(alpha: 0.9), blurRadius: 4)]
          : [],
      fontFamily: 'monospace',
      fontSize: scaleProvider.chatFontSize - 2,
    );

    return MarkdownBody(
      data: text,
      builders: {
        'code': CodeElementBuilder(context, codeStyle, themeProvider),
      },
      styleSheet: MarkdownStyleSheet(
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        p: TextStyle(
          color: themeProvider.markdownParagraphColor,
          fontSize: scaleProvider.chatFontSize,
          shadows: useBloom
              ? [
                  Shadow(
                    color: textColor.withValues(alpha: 0.9),
                    blurRadius: 15,
                  ),
                ]
              : [],
        ),
        a: TextStyle(
          color: themeProvider.markdownLinkColor,
          fontSize: scaleProvider.chatFontSize,
          decoration: TextDecoration.underline,
          shadows: useBloom
              ? [
                  const Shadow(
                    color: Colors.blueAccent,
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        code: codeStyle,
        h1: TextStyle(
          color: themeProvider.markdownH1Color,
          fontSize: scaleProvider.chatFontSize + 8,
          fontWeight: FontWeight.bold,
          shadows: useBloom
              ? [Shadow(color: textColor, blurRadius: 10)]
              : [],
        ),
        h2: TextStyle(
          color: themeProvider.markdownH2Color,
          fontSize: scaleProvider.chatFontSize + 6,
          fontWeight: FontWeight.bold,
          shadows: useBloom
              ? [Shadow(color: textColor, blurRadius: 10)]
              : [],
        ),
        h3: TextStyle(
          color: themeProvider.markdownH3Color,
          fontSize: scaleProvider.chatFontSize + 4,
          fontWeight: FontWeight.bold,
          shadows: useBloom
              ? [Shadow(color: textColor, blurRadius: 10)]
              : [],
        ),
        em: TextStyle(
          color: themeProvider.markdownItalicColor,
          fontStyle: FontStyle.italic,
        ),
        strong: TextStyle(
          color: themeProvider.markdownBoldColor,
          fontWeight: FontWeight.bold,
        ),
        del: TextStyle(color: themeProvider.markdownStrikeColor),
        listBullet: TextStyle(color: themeProvider.markdownListColor),
        blockquote: TextStyle(
          color: themeProvider.markdownBlockquoteColor,
          fontStyle: FontStyle.italic,
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
