import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../model_selector.dart';

/// A wrapper widget that provides model selection and list refreshing.
///
/// This widget uses a [ModelSelector] if a list of models is available,
/// otherwise it falls back to a [TextField] for manual entry. It also
/// includes a refresh button to trigger model fetching.
class ProviderModelSelector extends StatefulWidget {
  /// The list of available model info objects.
  final List<ModelInfo> modelsList;

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
  State<ProviderModelSelector> createState() => _ProviderModelSelectorState();
}

class _ProviderModelSelectorState extends State<ProviderModelSelector> {
  late TextEditingController _internalController;

  @override
  void initState() {
    super.initState();
    _internalController =
        widget.controller ?? TextEditingController(text: widget.selectedModel);
  }

  @override
  void didUpdateWidget(ProviderModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If external controller is provided, we don't manage text sync here
    if (widget.controller == null) {
      if (oldWidget.selectedModel != widget.selectedModel &&
          _internalController.text != widget.selectedModel) {
        _internalController.text = widget.selectedModel;
      }
    } else if (widget.controller != oldWidget.controller) {
      // Switched to a different external controller
      _internalController = widget.controller!;
    }
  }

  @override
  void dispose() {
    // Only dispose if we created it
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.modelsList.isNotEmpty && !chatProvider.enableManualModelInput)
          ModelSelector(
            modelsList: widget.modelsList,
            selectedModel: widget.selectedModel,
            onSelected: widget.onSelected,
            placeholder: widget.placeholder,
          )
        else
          TextField(
            controller: _internalController,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(fontSize: scaleProvider.systemFontSize),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            style: TextStyle(fontSize: scaleProvider.systemFontSize),
            onChanged: (val) {
               // Update parent state but don't force a cursor reset
               widget.onSelected(val);
            },
          ),


        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync, size: 16),
            label: Text(
              widget.isLoading ? "Fetching..." : "Refresh Model List",
              style: TextStyle(fontSize: scaleProvider.systemFontSize),
            ),
            onPressed: widget.isLoading ? null : widget.onRefresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.refreshButtonColor,
            ),
          ),
        ),
      ],
    );
  }
}
