import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import '../utils/constants.dart';

class ConversationDrawer extends StatefulWidget {
  final List<ChatSessionData> savedSessions;
  final String? currentSessionId;
  final int tokenCount;
  final int tokenLimitWarning;
  final VoidCallback onNewSession;
  final Function(ChatSessionData) onLoadSession;
  final Function(String) onDeleteSession;

  const ConversationDrawer({
    super.key,
    required this.savedSessions,
    required this.currentSessionId,
    required this.tokenCount,
    this.tokenLimitWarning = 190000,
    required this.onNewSession,
    required this.onLoadSession,
    required this.onDeleteSession,
  });

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tokenColor = widget.tokenCount > widget.tokenLimitWarning ? Colors.redAccent : Colors.greenAccent;
    
    final filteredSessions = widget.savedSessions.where((session) {
      final titleLower = session.title.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return titleLower.contains(queryLower);
    }).toList();

    return Drawer(
      width: 280,
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            color: Colors.black26,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Conversations List", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.token, color: tokenColor, size: 16),
                    const SizedBox(width: 8),
                    Text("${widget.tokenCount} / 1M \n Limit: ~190k", style: TextStyle(color: tokenColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            title: const Text("New Conversation", style: TextStyle(color: Colors.green)),
            subtitle: const Text("Hold Chat to delete", style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
            onTap: () {
              widget.onNewSession();
              Navigator.pop(context);
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: "Find conversation...",
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.cyanAccent, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            ? const Center(child: Text("No chats found", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
              itemCount: filteredSessions.length,
              itemBuilder: (context, index) {
                final session = filteredSessions[index];
                final bool isActive = session.id == widget.currentSessionId;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.cyanAccent.withAlpha((0.05 * 255).round()) : Colors.transparent,
                    border: isActive ? Border.all(color: Colors.cyanAccent, width: 1.5) : null, 
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    splashColor: Colors.red.withAlpha((0.95 * 255).round()),
                    leading: Icon(
                      isActive ? Icons.check_circle : Icons.history, 
                      color: isActive ? Colors.cyanAccent : Colors.grey[600]
                    ),
                    title: Text(
                      session.title, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(
                        color: isActive ? Colors.cyanAccent : Colors.grey[300], 
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal
                      )
                    ),
                    subtitle: Text(
                      cleanModelName(session.modelName), 
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])
                    ),
                    onTap: () {
                      widget.onLoadSession(session);
                      Navigator.pop(context);
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
                          content: Text("Permanently deletes ${session.title}", style: const TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              icon: const Icon(Icons.delete_forever, color: Colors.white),
                              label: const Text("DELETE"),
                              onPressed: () {
                                widget.onDeleteSession(session.id);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Conversation Deleted"), backgroundColor: Colors.redAccent)
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
