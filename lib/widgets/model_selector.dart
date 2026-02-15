import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/scale_provider.dart';
import '../models/chat_models.dart';
import '../utils/constants.dart';

/// A widget that allows users to select an AI model from a list.
///
/// This widget displays the currently selected model and opens a searchabled
/// dialog for choosing a different model. It supports bookmarking models
/// for quick access.
class ModelSelector extends StatelessWidget {
  /// The list of available model info objects.
  final List<ModelInfo> modelsList;

  /// The currently selected model ID.
  final String selectedModel;

  /// Callback triggered when a new model is selected.
  final Function(String) onSelected;

  /// Placeholder text when no model is selected.
  final String placeholder;

  /// Whether to use a more compact UI layout.
  final bool isCompact;

  const ModelSelector({
    super.key,
    required this.modelsList,
    required this.selectedModel,
    required this.onSelected,
    required this.placeholder,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final selectedModelInfo = modelsList.firstWhere(
      (m) => m.id == selectedModel,
      orElse: () => ModelInfo(id: selectedModel, name: cleanModelName(selectedModel)),
    );

    return GestureDetector(
      onTap: () {
        if (modelsList.isNotEmpty) {
          _showModelPickerDialog(context, themeProvider);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isCompact ? 6 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeProvider.enableBloom
                ? themeProvider.appThemeColor.withOpacity(0.5)
                : Colors.white12,
          ),
          boxShadow: themeProvider.enableBloom
              ? [
                  BoxShadow(
                    color: themeProvider.appThemeColor.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedModelInfo.name.isNotEmpty 
                    ? selectedModelInfo.name 
                    : placeholder,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Provider.of<ScaleProvider>(context).systemFontSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  /// Displays a dialog for searching and selecting models.
  void _showModelPickerDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        String sortMode = "Alphabetical"; // "Alphabetical" or "Cost"

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final chatProvider = Provider.of<ChatProvider>(context);
            final bookmarkedModels = chatProvider.bookmarkedModels;

            final filteredModels = modelsList.where((m) {
              final name = m.name.toLowerCase();
              final id = m.id.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || id.contains(query);
            }).toList();

            filteredModels.sort((a, b) {
              final bool aBookmarked = bookmarkedModels.contains(a.id);
              final bool bBookmarked = bookmarkedModels.contains(b.id);
              if (aBookmarked && !bBookmarked) return -1;
              if (!aBookmarked && bBookmarked) return 1;

              if (sortMode == "Cost" && a.pricing.isNotEmpty && b.pricing.isNotEmpty) {
                try {
                  final aCost = double.tryParse(a.pricing.split(' / ').first) ?? 0.0;
                  final bCost = double.tryParse(b.pricing.split(' / ').first) ?? 0.0;
                  return aCost.compareTo(bCost);
                } catch (_) {}
              }

              return a.name.compareTo(b.name);
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select Model (${filteredModels.length})",
                      style: TextStyle(
                        color: themeProvider.appThemeColor,
                        fontSize: scaleProvider.systemFontSize,
                      ),
                    ),
                  ),
                  if (chatProvider.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () async {
                        await chatProvider.refreshCurrentModels();
                        setDialogState(() {});
                      },
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort, color: Colors.white70),
                    onSelected: (val) {
                      setDialogState(() {
                        sortMode = val;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: "Alphabetical", child: Text("Sort by Name")),
                      const PopupMenuItem(value: "Cost", child: Text("Sort by Cost")),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
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
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: scaleProvider.systemFontSize,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filteredModels.isEmpty
                          ? Center(
                              child: Text(
                                "No models found",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: scaleProvider.systemFontSize,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredModels.length,
                              itemBuilder: (context, index) {
                                final model = filteredModels[index];
                                final isSelected = model.id == selectedModel;
                                final isBookmarked = bookmarkedModels.contains(
                                  model.id,
                                );
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? themeProvider.appThemeColor
                                              .withOpacity(0.15)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? themeProvider.appThemeColor
                                                .withOpacity(0.5)
                                          : Colors.white10,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        onSelected(model.id);
                                        Navigator.pop(context);
                                      },
                                      onLongPress: () => _showModelDetails(context, model, themeProvider),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    model.name,
                                                    style: TextStyle(
                                                      color: isSelected ? themeProvider.appThemeColor : Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: scaleProvider.systemFontSize,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    model.id,
                                                    style: TextStyle(
                                                      fontSize: scaleProvider.systemFontSize - 4,
                                                      color: Colors.grey,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (model.contextLength.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        "Max Context: ${_formatNumber(model.contextLength)}",
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.blueAccent,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  if (model.pricing.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        _formatPricing(model.pricing),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.greenAccent,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () => _showModelDetails(context, model, themeProvider),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4.0),
                                                    child: Icon(Icons.info_outline, color: Colors.white54, size: 28),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                InkWell(
                                                  onTap: () async {
                                                    await chatProvider.toggleModelBookmark(
                                                      model.id,
                                                    );
                                                    setDialogState(() {});
                                                  },
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(4.0),
                                                    child: Icon(
                                                      isBookmarked
                                                          ? Icons.bookmark
                                                          : Icons.bookmark_border,
                                                      color: isBookmarked
                                                          ? Colors.amber
                                                          : Colors.white30,
                                                      size: 28,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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
                  child: Text(
                    "Close",
                    style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showModelDetails(BuildContext context, ModelInfo model, ThemeProvider themeProvider) {
    final scaleProvider = Provider.of<ScaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          model.name,
          style: TextStyle(color: themeProvider.appThemeColor, fontSize: scaleProvider.systemFontSize),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow("ID:", model.id, scaleProvider),
              if (model.contextLength.isNotEmpty)
                _detailRow("Max Context:", _formatNumber(model.contextLength), scaleProvider),
              if (model.pricing.isNotEmpty)
                _detailRow("", _formatPricing(model.pricing), scaleProvider),
              const Divider(color: Colors.white24),
              Text(
                model.description.isNotEmpty ? model.description : "No description available.",
                style: TextStyle(color: Colors.white70, fontSize: scaleProvider.systemFontSize - 2),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ScaleProvider scale) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text("$label ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: scale.systemFontSize - 2)),
          Expanded(child: Text(value, style: TextStyle(color: Colors.white, fontSize: scale.systemFontSize - 2))),
        ],
      ),
    );
  }

  String _formatNumber(String s) {
    int? n = int.tryParse(s);
    if (n == null) return s;
    String str = n.toString();
    String res = "";
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      res = str[i] + res;
      count++;
      if (count % 3 == 0 && i != 0) {
        res = ",$res";
      }
    }
    return res;
  }

  String _formatPricing(String p) {
    try {
      final parts = p.split(' / ');
      if (parts.length != 2) return p;
      double input = double.tryParse(parts[0]) ?? 0;
      double output = double.tryParse(parts[1]) ?? 0;
      
      // Convert per token to per 1M tokens
      double inputM = input * 1000000;
      double outputM = output * 1000000;
      
      return "Input: \$${inputM.toStringAsFixed(2)}/M\nOutput: \$${outputM.toStringAsFixed(2)}/M";
    } catch (e) {
      return p;
    }
  }
}
