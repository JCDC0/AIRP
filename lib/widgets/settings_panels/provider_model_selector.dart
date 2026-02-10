import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scale_provider.dart';
import '../model_selector.dart';

/// A wrapper widget that provides model selection and list refreshing.
///
/// This widget uses a [ModelSelector] if a list of models is available,
/// otherwise it falls back to a [TextField] for manual entry. It also
/// includes a refresh button to trigger model fetching.
class ProviderModelSelector extends StatelessWidget {
  /// The list of available model IDs.
  final List<String> modelsList;

  /// The currently selected model ID.
  final String selectedModel;

  /// Callback triggered when a new model is selected.
  final Function(String) onSelected;

  /// Placeholder text when no model is selected.
  final String placeholder;

  /// Whether the model list is currently being fetched.
  final bool isLoading;

  /// Callback triggered when the refresh button is pressed.
  final VoidCallback? onRefresh;

  /// The color of the refresh button.
  final Color refreshButtonColor;

  /// Optional controller for manual model entry.
  final TextEditingController? controller;

  const ProviderModelSelector({
    super.key,
    required this.modelsList,
    required this.selectedModel,
    required this.onSelected,
    required this.placeholder,
    required this.isLoading,
    this.onRefresh,
    this.refreshButtonColor = Colors.blueAccent,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modelsList.isNotEmpty)
          ModelSelector(
            modelsList: modelsList,
            selectedModel: selectedModel,
            onSelected: onSelected,
            placeholder: placeholder,
          )
        else
          TextField(
            controller:
                controller ?? TextEditingController(text: selectedModel),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(fontSize: scaleProvider.systemFontSize),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize),
            onChanged: (val) => onSelected(val.trim()),
          ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync, size: 16),
            label: Text(
              isLoading ? "Fetching..." : "Refresh Model List",
              style: TextStyle(fontSize: scaleProvider.systemFontSize),
            ),
            onPressed: isLoading ? null : onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: refreshButtonColor,
            ),
          ),
        ),
      ],
    );
  }
}
