import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/search_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';

/// The in-chat find bar (ctrl+F), overlaid at the top of the message list.
///
/// Reads match state from [SearchProvider] and pushes query changes back via
/// [SearchProvider.setQuery]. The text controller + focus node are owned by
/// the host screen so the field survives open/close animations and can be
/// focused programmatically.
class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClose;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final search = Provider.of<ChatSearchProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final scale = Provider.of<ScaleProvider>(context);
    final chat = Provider.of<ChatProvider>(context);

    final bool hasMatches = search.hasMatches;
    final String count = search.query.isEmpty
        ? ''
        : '${search.currentMatchNumber}/${search.matchCount}';

    return Material(
      elevation: 8,
      color: theme.inputFillColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: scale.iconScale * 22,
              color: theme.subtitleColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: scale.systemFontSize,
                ),
                cursorColor: theme.textColor,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Find in chat…',
                  hintStyle: TextStyle(
                    color: theme.subtitleColor,
                    fontSize: scale.systemFontSize,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onChanged: (v) => search.setQuery(v, chat.messages),
                onSubmitted: (_) {
                  if (search.hasMatches) search.next();
                  focusNode.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 56,
              child: Text(
                count,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.subtitleColor,
                  fontSize: scale.systemFontSize - 1,
                ),
              ),
            ),
            _NavButton(
              icon: Icons.keyboard_arrow_up,
              tooltip: 'Previous match',
              color: theme.textColor,
              iconScale: scale.iconScale,
              onTap: hasMatches ? search.previous : null,
            ),
            _NavButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: 'Next match',
              color: theme.textColor,
              iconScale: scale.iconScale,
              onTap: hasMatches ? search.next : null,
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: scale.iconScale * 20,
                color: theme.subtitleColor,
              ),
              tooltip: 'Close (Esc)',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final double iconScale;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.iconScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: iconScale * 22, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}
