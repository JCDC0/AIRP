import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat_models.dart';
import '../providers/theme_provider.dart';
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


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
      elevation: themeProvider.enableBloom ? 20 : 16,
      shadowColor: themeProvider.enableBloom
          ? themeProvider.appThemeColor.withOpacity(0.3)
          : null,
      color: const Color.fromARGB(255, 0, 0, 0),
      child: SizedBox(
        width: scaleProvider.drawerWidth,
        height: double.infinity,
        child: Stack(
          children: [
            Column(
              children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
              color: Colors.black26,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Conversations List",
                    style: TextStyle(
                      fontSize: scaleProvider.systemFontSize + 8,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.appThemeColor,
                      shadows: themeProvider.enableBloom
                          ? [
                              Shadow(
                                color: themeProvider.appThemeColor,
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
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
                shadows: themeProvider.enableBloom
                    ? [const Shadow(color: Colors.greenAccent, blurRadius: 8)]
                    : [],
              ),
              title: Text(
                "New Conversation",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: scaleProvider.systemFontSize,
                  shadows: themeProvider.enableBloom
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: themeProvider.enableBloom
                      ? Border.all(
                          color: themeProvider.appThemeColor.withOpacity(0.3),
                        )
                      : null,
                  boxShadow: themeProvider.enableBloom
                      ? [
                          BoxShadow(
                            color: themeProvider.appThemeColor.withOpacity(0.1),
                            blurRadius: 6,
                          ),
                        ]
                      : [],
                ),
                child: TextField(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: scaleProvider.systemFontSize,
                  ),
                  decoration: InputDecoration(
                    hintText: "Find conversation...",
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: scaleProvider.systemFontSize - 1,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: themeProvider.appThemeColor,
                      size: 18,
                      shadows: themeProvider.enableBloom
                          ? [
                              Shadow(
                                color: themeProvider.appThemeColor,
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
                                color: themeProvider.appThemeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: scaleProvider.systemFontSize,
                                letterSpacing: 1.2,
                                shadows: themeProvider.enableBloom
                                    ? [
                                        Shadow(
                                          color: themeProvider.appThemeColor,
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white10, height: 1),
                          ...bookmarkedSessions.map(
                            (session) => _buildSessionItem(
                              context,
                              session,
                              themeProvider,
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
                                color: themeProvider.appThemeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: scaleProvider.systemFontSize,
                                letterSpacing: 1.2,
                                shadows: themeProvider.enableBloom
                                    ? [
                                        Shadow(
                                          color: themeProvider.appThemeColor,
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 8),
                          ...recentSessions.map(
                            (session) => _buildSessionItem(
                              context,
                              session,
                              themeProvider,
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
    ChatProvider chatProvider,
    ScaleProvider scaleProvider,
  ) {
    final bool isActive = session.id == chatProvider.currentSessionId;
    final bool isStreaming = chatProvider.streamingSessionIds.contains(session.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive
            ? themeProvider.appThemeColor.withAlpha((0.05 * 255).round())
            : Colors.transparent,
        border: isActive
            ? Border.all(color: themeProvider.appThemeColor, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: (isActive && themeProvider.enableBloom)
            ? [
                BoxShadow(
                  color: themeProvider.appThemeColor.withOpacity(0.2),
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
        splashColor: themeProvider.appThemeColor.withAlpha((0.1 * 255).round()),

        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            chatProvider.bookmarkSession(session.id, !session.isBookmarked);
          },
          child: Icon(
            session.isBookmarked ? Icons.star : Icons.star_border,
            color: session.isBookmarked
                ? Colors.orangeAccent
                : Colors.grey[700],
            shadows: (session.isBookmarked && themeProvider.enableBloom)
                ? [const Shadow(color: Colors.orangeAccent, blurRadius: 8)]
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
                  color: isActive ? themeProvider.appThemeColor : Colors.grey[300],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: scaleProvider.systemFontSize + 1,
                  shadows: (isActive && themeProvider.enableBloom)
                      ? [Shadow(color: themeProvider.appThemeColor, blurRadius: 8)]
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
                    themeProvider.appThemeColor,
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
          chatProvider.loadSession(session);

          if (session.backgroundImage != null) {
            themeProvider.setBackgroundImage(session.backgroundImage!);
          } else {
            themeProvider.setBackgroundImage('assets/default.jpg');
          }

          widget.onClose?.call();
        },

        onLongPress: () {
          HapticFeedback.heavyImpact();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text("Delete?", style: TextStyle(color: Colors.redAccent)),
                ],
              ),
              content: Text(
                "Permanently deletes ${session.title}",
                style: const TextStyle(color: Colors.white70),
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
                  onPressed: () {
                    chatProvider.deleteSession(session.id);
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
  final ScaleProvider scaleProvider;
  final VoidCallback onDismiss;

  const _BackgroundNotificationCard({
    required this.notification,
    required this.themeProvider,
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
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.appThemeColor.withOpacity(0.4),
              width: 1,
            ),
            boxShadow: theme.enableBloom
                ? [
                    BoxShadow(
                      color: theme.appThemeColor.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
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
                    shadows: theme.enableBloom
                        ? [const Shadow(color: Colors.greenAccent, blurRadius: 6)]
                        : [],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notif.sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.appThemeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: scale.systemFontSize,
                        shadows: theme.enableBloom
                            ? [Shadow(color: theme.appThemeColor, blurRadius: 6)]
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
                    child: Icon(
                      Icons.close,
                      color: Colors.grey[600],
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                notif.messagePreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[400],
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