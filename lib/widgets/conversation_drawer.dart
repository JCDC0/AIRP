import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
import '../providers/vfx_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/scale_provider.dart';
import '../utils/constants.dart';

/// A drawer widget that displays and manages the list of saved chat sessions.
///
/// This drawer allows users to search, star, delete, and switch between
/// different chat conversations. Shows loading indicators for sessions with
/// active background streams and notifications for completed responses.
class ConversationDrawer extends StatefulWidget {
  /// Callback triggered when the drawer should be closed.
  final VoidCallback? onClose;

  const ConversationDrawer({super.key, this.onClose});

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer>
    with TickerProviderStateMixin {
  String _searchQuery = '';

  /// Multi-select, for merging several conversations into one chronicle.
  bool _selectMode = false;
  final Set<String> _selected = <String>{};
  bool _merging = false;
  String? _mergeStatus;

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  /// Merges the selected conversations into one new chronicle conversation.
  Future<void> _runMerge(ChatProvider chatProvider) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _merging = true;
      _mergeStatus = null;
    });
    try {
      final err = await chatProvider.mergeSessionsIntoChronicle(
        sessionIds: _selected.toList(),
        mergePrompt:
            prefs.getString(SummarizeDefaults.prefMergePrompt) ??
            SummarizeDefaults.defaultMergePrompt,
        // Used only for a selected conversation that was never compacted.
        fallbackSummaryPrompt:
            prefs.getString(SummarizeDefaults.prefCompressPrompt) ??
            SummarizeDefaults.defaultCompressPrompt,
      );
      if (!mounted) return;
      if (err == null) {
        _exitSelectMode();
        widget.onClose?.call();
      } else {
        setState(() => _mergeStatus = err);
      }
    } catch (e) {
      if (mounted) setState(() => _mergeStatus = "Merge failed: $e");
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  /// The select-mode bar: how many are picked, and the merge action.
  Widget _selectionBar(
    ChatProvider chatProvider,
    ThemeProvider themeProvider,
    ScaleProvider scaleProvider,
  ) {
    if (!_selectMode) return const SizedBox.shrink();
    final enough = _selected.length >= 2;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: themeProvider.containerFillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeProvider.markdownLinkColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selected.isEmpty
                ? "Pick conversations to merge"
                : "${_selected.length} selected",
            style: TextStyle(
              color: themeProvider.textColor,
              fontWeight: FontWeight.bold,
              fontSize: scaleProvider.systemFontSize - 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Their summaries are merged into one chronicle. A conversation "
            "with no summary is summarised first.",
            style: TextStyle(
              color: themeProvider.subtitleColor,
              fontSize: scaleProvider.systemFontSize - 3,
            ),
          ),
          if (_mergeStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              _mergeStatus!,
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: scaleProvider.systemFontSize - 3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('merge_selected_button'),
                  onPressed: (!enough || _merging)
                      ? null
                      : () => _runMerge(chatProvider),
                  icon: _merging
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.merge_type, size: 18),
                  label: Text(_merging ? "Merging…" : "Merge"),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _merging ? null : _exitSelectMode,
                child: const Text("Cancel"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Attach / detach control for the current conversation's chronicle.
  ///
  /// A Column sibling, not a row inside the session ListView: that list is
  /// only built when a search actually matches something, so a control placed
  /// inside it disappears exactly when the conversation list is empty.
  ///
  /// The options are derived from the saved sessions rather than a store of
  /// their own, so every generation of a chronicle is listed under the
  /// conversation that produced it.
  Widget _chronicleSelector(
    BuildContext context,
    ChatProvider chatProvider,
    ThemeProvider themeProvider,
    VfxProvider vfxProvider,
    ScaleProvider scaleProvider,
  ) {
    final chronicles = chatProvider.availableChronicles;
    final attached = chatProvider.currentChronicle;
    if (chronicles.isEmpty && attached == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories,
            size: 18,
            color: attached != null
                ? themeProvider.markdownLinkColor
                : themeProvider.dimTextColor,
            shadows: vfxProvider.enableBloom && attached != null
                ? [Shadow(color: themeProvider.bloomGlowColor, blurRadius: 8)]
                : [],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: themeProvider.textColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeProvider.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('chronicle_dropdown'),
                  isExpanded: true,
                  value: null,
                  hint: Text(
                    attached != null ? "Chronicle attached" : "No chronicle",
                    style: TextStyle(
                      color: attached != null
                          ? themeProvider.textColor
                          : themeProvider.dimTextColor,
                      fontSize: scaleProvider.systemFontSize - 2,
                    ),
                  ),
                  dropdownColor: themeProvider.dropdownColor,
                  items: [
                    for (final c in chronicles)
                      DropdownMenuItem(
                        value: c.sessionId,
                        child: Text(
                          c.sessionTitle.isEmpty ? "Untitled" : c.sessionTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: scaleProvider.systemFontSize - 2,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null) return;
                    final picked = chronicles.firstWhere(
                      (c) => c.sessionId == id,
                    );
                    chatProvider.attachChronicle(picked.chronicle);
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          if (attached != null)
            IconButton(
              icon: const Icon(Icons.link_off, size: 18),
              color: themeProvider.dimTextColor,
              tooltip: "Detach chronicle",
              onPressed: () => _confirmDetachChronicle(context, chatProvider),
            ),
        ],
      ),
    );
  }

  /// The chronicle is undeletable from the chat, so detaching is the opt-out
  /// and is confirmed rather than silent.
  void _confirmDetachChronicle(
    BuildContext context,
    ChatProvider chatProvider,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: themeProvider.dropdownColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Detach chronicle?",
          style: TextStyle(color: themeProvider.textColor),
        ),
        content: Text(
          "This conversation stops carrying its chronicle. Other conversations "
          "that hold a copy keep theirs.",
          style: TextStyle(color: themeProvider.subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              chatProvider.detachChronicle();
              setState(() {});
            },
            child: const Text("Detach"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);

    final filteredSessions = chatProvider.savedSessions.where((session) {
      final titleLower = session.title.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return titleLower.contains(queryLower);
    }).toList();

    final bookmarkedSessions = filteredSessions
        .where((s) => s.isBookmarked)
        .toList();
    final recentSessions = filteredSessions
        .where((s) => !s.isBookmarked)
        .toList();

    return Material(
      elevation: vfxProvider.enableBloom ? 20 : 16,
      shadowColor: vfxProvider.enableBloom
          ? themeProvider.bloomGlowColor.withValues(alpha: 0.3)
          : null,
      color: themeProvider.scaffoldBackgroundColor,
      child: SizedBox(
        width: scaleProvider.drawerWidth,
        height: double.infinity,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                  color: themeProvider.containerFillColor,
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Conversations List",
                              style: TextStyle(
                                fontSize: scaleProvider.systemFontSize + 8,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                                shadows: vfxProvider.enableBloom
                                    ? [
                                        Shadow(
                                          color: themeProvider.bloomGlowColor,
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('select_mode_button'),
                            icon: Icon(
                              _selectMode ? Icons.close : Icons.checklist_rtl,
                              color: _selectMode
                                  ? themeProvider.markdownLinkColor
                                  : themeProvider.dimTextColor,
                              size: scaleProvider.iconScale * 20,
                            ),
                            tooltip: _selectMode
                                ? "Cancel selection"
                                : "Select conversations to merge",
                            onPressed: _merging
                                ? null
                                : () {
                                    if (_selectMode) {
                                      _exitSelectMode();
                                    } else {
                                      setState(() {
                                        _selectMode = true;
                                        _mergeStatus = null;
                                      });
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  dense: true,
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: Colors.greenAccent,
                    shadows: vfxProvider.enableBloom
                        ? [
                            const Shadow(
                              color: Colors.greenAccent,
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  title: Text(
                    "New Conversation",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: scaleProvider.systemFontSize,
                      shadows: vfxProvider.enableBloom
                          ? [const Shadow(color: Colors.green, blurRadius: 8)]
                          : [],
                    ),
                  ),
                  subtitle: Text(
                    "Hold Chat to delete",
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: scaleProvider.systemFontSize - 2,
                    ),
                  ),
                  onTap: () {
                    chatProvider.createNewSession();
                    widget.onClose?.call();
                  },
                ),

                _selectionBar(chatProvider, themeProvider, scaleProvider),

                if (!_selectMode)
                  _chronicleSelector(
                    context,
                    chatProvider,
                    themeProvider,
                    vfxProvider,
                    scaleProvider,
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeProvider.textColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: vfxProvider.enableBloom
                          ? Border.all(
                              color: themeProvider.bloomGlowColor.withValues(
                                alpha: 0.3,
                              ),
                            )
                          : null,
                      boxShadow: vfxProvider.enableBloom
                          ? [
                              BoxShadow(
                                color: themeProvider.bloomGlowColor.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 6,
                              ),
                            ]
                          : [],
                    ),
                    child: TextField(
                      style: TextStyle(
                        color: themeProvider.textColor,
                        fontSize: scaleProvider.systemFontSize,
                      ),
                      decoration: InputDecoration(
                        hintText: "Find conversation...",
                        hintStyle: TextStyle(
                          color: themeProvider.dimTextColor,
                          fontSize: scaleProvider.systemFontSize - 1,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: themeProvider.textColor,
                          size: 18,
                          shadows: vfxProvider.enableBloom
                              ? [
                                  Shadow(
                                    color: themeProvider.bloomGlowColor,
                                    blurRadius: 6,
                                  ),
                                ]
                              : [],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),

                const Divider(color: Colors.grey),

                Expanded(
                  child: filteredSessions.isEmpty
                      ? Center(
                          child: Text(
                            "No chats found",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: scaleProvider.systemFontSize,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          children: [
                            if (bookmarkedSessions.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                child: Text(
                                  "Starred",
                                  style: TextStyle(
                                    color: themeProvider.textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: scaleProvider.systemFontSize,
                                    letterSpacing: 1.2,
                                    shadows: vfxProvider.enableBloom
                                        ? [
                                            Shadow(
                                              color:
                                                  themeProvider.bloomGlowColor,
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                              ),
                              Divider(
                                color: themeProvider.dividerColor,
                                height: 1,
                              ),
                              ...bookmarkedSessions.map(
                                (session) => _buildSessionItem(
                                  context,
                                  session,
                                  themeProvider,
                                  vfxProvider,
                                  chatProvider,
                                  scaleProvider,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            if (recentSessions.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                child: Text(
                                  "Recent",
                                  style: TextStyle(
                                    color: themeProvider.textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: scaleProvider.systemFontSize,
                                    letterSpacing: 1.2,
                                    shadows: vfxProvider.enableBloom
                                        ? [
                                            Shadow(
                                              color:
                                                  themeProvider.bloomGlowColor,
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                              ),
                              Divider(
                                color: themeProvider.dividerColor,
                                height: 1,
                              ),
                              const SizedBox(height: 8),
                              ...recentSessions.map(
                                (session) => _buildSessionItem(
                                  context,
                                  session,
                                  themeProvider,
                                  vfxProvider,
                                  chatProvider,
                                  scaleProvider,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),

            // Notification overlay for completed background responses
            if (chatProvider.pendingNotifications.isNotEmpty)
              Positioned(
                left: 8,
                right: 8,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    chatProvider.pendingNotifications.length,
                    (i) => _BackgroundNotificationCard(
                      notification: chatProvider.pendingNotifications[i],
                      themeProvider: themeProvider,
                      vfxProvider: vfxProvider,
                      scaleProvider: scaleProvider,
                      onDismiss: () {
                        chatProvider.removeNotification(i);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(
    BuildContext context,
    ChatSessionData session,
    ThemeProvider themeProvider,
    VfxProvider vfxProvider,
    ChatProvider chatProvider,
    ScaleProvider scaleProvider,
  ) {
    final bool isActive = session.id == chatProvider.currentSessionId;
    final bool isStreaming = chatProvider.streamingSessionIds.contains(
      session.id,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive
            ? themeProvider.textColor.withAlpha((0.05 * 255).round())
            : Colors.transparent,
        border: isActive
            ? Border.all(color: themeProvider.textColor, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: (isActive && vfxProvider.enableBloom)
            ? [
                BoxShadow(
                  color: themeProvider.bloomGlowColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        splashColor: themeProvider.textColor.withAlpha((0.1 * 255).round()),

        // In select mode the star makes way for a checkbox: bookmarking and
        // selecting would otherwise compete for the same tap target.
        leading: _selectMode
            ? Checkbox(
                value: _selected.contains(session.id),
                onChanged: _merging ? null : (_) => _toggleSelected(session.id),
              )
            : GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  chatProvider.bookmarkSession(
                    session.id,
                    !session.isBookmarked,
                  );
                },
                child: Icon(
                  session.isBookmarked ? Icons.star : Icons.star_border,
                  color: session.isBookmarked
                      ? Colors.orangeAccent
                      : Colors.grey[700],
                  shadows: (session.isBookmarked && vfxProvider.enableBloom)
                      ? [
                          const Shadow(
                            color: Colors.orangeAccent,
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              ),

        title: Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive
                      ? themeProvider.textColor
                      : themeProvider.subtitleColor,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: scaleProvider.systemFontSize + 1,
                  shadows: (isActive && vfxProvider.enableBloom)
                      ? [
                          Shadow(
                            color: themeProvider.bloomGlowColor,
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
            if (isStreaming) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    themeProvider.textColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          cleanModelName(session.modelName),
          style: TextStyle(
            fontSize: scaleProvider.systemFontSize - 2,
            color: Colors.grey[600],
          ),
        ),
        onTap: () {
          if (_selectMode) {
            if (!_merging) _toggleSelected(session.id);
            return;
          }
          // Save outgoing session's background before switching
          chatProvider.autoSaveCurrentSession(
            backgroundImagePath: vfxProvider.backgroundImagePath,
          );
          chatProvider.loadSession(session);

          if (session.backgroundImage != null) {
            vfxProvider.setBackgroundImage(session.backgroundImage!);
          } else {
            vfxProvider.setBackgroundImage(null);
          }

          widget.onClose?.call();
        },

        onLongPress: () {
          // Deleting while picking conversations to merge is almost always a
          // misfire, so the gesture is off in select mode.
          if (_selectMode) return;
          HapticFeedback.heavyImpact();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: themeProvider.dropdownColor,
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text("Delete?", style: TextStyle(color: Colors.redAccent)),
                ],
              ),
              content: Text(
                "Permanently deletes ${session.title}",
                style: TextStyle(color: themeProvider.subtitleColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text("DELETE"),
                  onPressed: () async {
                    await chatProvider.deleteSession(session.id);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Conversation Deleted"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// An auto-dismissing notification card for completed background AI responses.
class _BackgroundNotificationCard extends StatefulWidget {
  final BackgroundNotification notification;
  final ThemeProvider themeProvider;
  final VfxProvider vfxProvider;
  final ScaleProvider scaleProvider;
  final VoidCallback onDismiss;

  const _BackgroundNotificationCard({
    required this.notification,
    required this.themeProvider,
    required this.vfxProvider,
    required this.scaleProvider,
    required this.onDismiss,
  });

  @override
  State<_BackgroundNotificationCard> createState() =>
      _BackgroundNotificationCardState();
}

class _BackgroundNotificationCardState
    extends State<_BackgroundNotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeProvider;
    final vfxProvider = widget.vfxProvider;
    final scale = widget.scaleProvider;
    final notif = widget.notification;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.surfaceDimColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.bloomGlowColor.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: vfxProvider.enableBloom
                ? [
                    BoxShadow(
                      color: theme.bloomGlowColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [BoxShadow(color: theme.containerFillColor, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 16,
                    shadows: vfxProvider.enableBloom
                        ? [
                            const Shadow(
                              color: Colors.greenAccent,
                              blurRadius: 6,
                            ),
                          ]
                        : [],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notif.sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: scale.systemFontSize,
                        shadows: vfxProvider.enableBloom
                            ? [
                                Shadow(
                                  color: theme.bloomGlowColor,
                                  blurRadius: 6,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) {
                        if (mounted) widget.onDismiss();
                      });
                    },
                    child: Icon(Icons.close, color: Colors.grey[600], size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                notif.messagePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.subtitleColor,
                  fontSize: scale.systemFontSize - 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cleanModelName(notif.modelName),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: scale.systemFontSize - 3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
