import 'package:flutter/material.dart';
import '../model_selector.dart';

class ProviderModelSelector extends StatelessWidget {
  final List<String> modelsList;
  final String selectedModel;
  final Function(String) onSelected;
  final String placeholder;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final Color refreshButtonColor;
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
            controller: controller ?? TextEditingController(text: selectedModel),
            decoration: InputDecoration(
              hintText: placeholder,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) => onSelected(val.trim()),
          ),
        
        const SizedBox(height: 8),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync, size: 16),
            label: Text(isLoading ? "Fetching..." : "Refresh Model List"),
            onPressed: isLoading ? null : onRefresh,
            style: OutlinedButton.styleFrom(foregroundColor: refreshButtonColor),
          ),
        ),
      ],
    );
  }
}
