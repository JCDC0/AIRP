import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class ModelSelector extends StatelessWidget {
  final List<String> modelsList;
  final String selectedModel;
  final Function(String) onSelected;
  final String placeholder;

  const ModelSelector({
    super.key,
    required this.modelsList,
    required this.selectedModel,
    required this.onSelected,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        if (modelsList.isNotEmpty) {
          _showModelPickerDialog(context, themeProvider);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: themeProvider.enableBloom ? themeProvider.appThemeColor.withOpacity(0.5) : Colors.white12),
          boxShadow: themeProvider.enableBloom ? [BoxShadow(color: themeProvider.appThemeColor.withOpacity(0.1), blurRadius: 8)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                modelsList.contains(selectedModel) ? cleanModelName(selectedModel) : (selectedModel.isNotEmpty ? cleanModelName(selectedModel) : placeholder),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showModelPickerDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final chatProvider = Provider.of<ChatProvider>(context);
            final bookmarkedModels = chatProvider.bookmarkedModels;

            // Filter and Sort
            final filteredModels = modelsList.where((m) {
              final name = cleanModelName(m).toLowerCase();
              final id = m.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || id.contains(query);
            }).toList();

            filteredModels.sort((a, b) {
              // 1. Bookmarks first
              final bool aBookmarked = bookmarkedModels.contains(a);
              final bool bBookmarked = bookmarkedModels.contains(b);
              if (aBookmarked && !bBookmarked) return -1;
              if (!aBookmarked && bBookmarked) return 1;

              // 2. Constants (Starred) second
              final bool aInConstants = kModelDisplayNames.containsKey(a);
              final bool bInConstants = kModelDisplayNames.containsKey(b);
              if (aInConstants && !bInConstants) return -1;
              if (!aInConstants && bInConstants) return 1;

              // 3. Alphabetical
              return cleanModelName(a).compareTo(cleanModelName(b));
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text("Select Model", style: TextStyle(color: themeProvider.appThemeColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search models...",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredModels.isEmpty
                          ? const Center(child: Text("No models found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: filteredModels.length,
                              itemBuilder: (context, index) {
                                final modelId = filteredModels[index];
                                final isSelected = modelId == selectedModel;
                                final isBookmarked = bookmarkedModels.contains(modelId);
                                final isFeatured = kModelDisplayNames.containsKey(modelId);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? themeProvider.appThemeColor.withOpacity(0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: themeProvider.appThemeColor.withOpacity(0.5)) : null,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    title: Text(
                                      cleanModelName(modelId),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isBookmarked ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(modelId, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    leading: isBookmarked
                                        ? const Icon(Icons.bookmark, color: Colors.amber, size: 20)
                                        : (isFeatured ? const Icon(Icons.star, color: Colors.yellowAccent, size: 16) : const Icon(Icons.circle_outlined, color: Colors.grey, size: 12)),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                        color: isBookmarked ? Colors.amber : Colors.grey,
                                      ),
                                      onPressed: () async {
                                        await chatProvider.toggleModelBookmark(modelId);
                                        // No need to setDialogState manually as Provider will trigger rebuild? 
                                        // Actually, AlertDialog is in a separate route, so it might not rebuild automatically unless we use Consumer or setDialogState.
                                        // But we are using Provider.of<ChatProvider>(context) inside StatefulBuilder's builder?
                                        // No, we are using it inside the builder, but `setDialogState` is needed to trigger rebuild of the *dialog content* if we rely on local state.
                                        // But here we rely on provider state.
                                        // `StatefulBuilder` only rebuilds when `setDialogState` is called.
                                        // So we should call `setDialogState(() {})` to force rebuild of the list.
                                        setDialogState(() {});
                                      },
                                    ),
                                    onTap: () {
                                      onSelected(modelId);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Close"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
