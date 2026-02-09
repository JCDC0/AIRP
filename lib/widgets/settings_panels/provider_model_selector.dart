import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scale_provider.dart';
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
