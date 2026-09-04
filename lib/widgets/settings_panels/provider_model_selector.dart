import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
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

  /// Whether to offer a button that clears the selection back to Auto.
  ///
  /// Only meaningful where a blank id is a valid instruction to the provider,
  /// which today is Local: llama.cpp and LM Studio serve whatever they were
  /// launched with regardless of the `model` field.
  final bool allowClear;

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
    this.allowClear = false,
  });

  @override
  State<ProviderModelSelector> createState() => _ProviderModelSelectorState();
}

class _ProviderModelSelectorState extends State<ProviderModelSelector> {
  late TextEditingController _internalController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _internalController =
        widget.controller ?? TextEditingController(text: widget.selectedModel);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(ProviderModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If external controller is provided, we don't manage text sync here
    if (widget.controller == null) {
      if (oldWidget.selectedModel != widget.selectedModel &&
          _internalController.text != widget.selectedModel) {
        // Only override the text field if the user is NOT actively typing.
        // This prevents cursor reset/overwrite bugs on rapid typing.
        if (!_focusNode.hasFocus) {
          _internalController.text = widget.selectedModel;
        }
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
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaleProvider = Provider.of<ScaleProvider>(context);

    final bool hasModels = widget.modelsList.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: hasModels
              ? ModelSelector(
                  modelsList: widget.modelsList,
                  selectedModel: widget.selectedModel,
                  onSelected: widget.onSelected,
                  placeholder: widget.placeholder,
                )
              : TextField(
                  controller: _internalController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(
                      fontSize: scaleProvider.systemFontSize,
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: scaleProvider.systemFontSize),
                  onChanged: (val) {
                    // Update parent state but don't force a cursor reset
                    widget.onSelected(val);
                  },
                ),
        ),
        if (widget.allowClear && hasModels && widget.selectedModel.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.backspace_outlined, size: 18),
            tooltip: 'Clear (let the server choose)',
            onPressed: () {
              _internalController.clear();
              widget.onSelected('');
            },
          ),
        if (widget.onRefresh != null)
          IconButton(
            icon: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.cloud_sync,
                    size: 18,
                    color: widget.refreshButtonColor,
                  ),
            tooltip: hasModels ? 'Refresh model list' : 'Load model list',
            onPressed: widget.isLoading ? null : widget.onRefresh,
          ),
      ],
    );
  }
}
