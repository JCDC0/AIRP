import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/vfx_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/scale_provider.dart';
import '../../models/chat_models.dart';
import 'orbit_animations.dart';

class ChatActionBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onShowAttachmentMenu;
  final VoidCallback onScrollToTop;
  final VoidCallback onScrollToBottom;
  final void Function(String) onShowStatusPopup;
  final AnimationController orbitController;
  final List<OrbitLine> iconOrbitLines;

  const ChatActionBar({
    super.key,
    required this.isLoading,
    required this.onShowAttachmentMenu,
    required this.onScrollToTop,
    required this.onScrollToBottom,
    required this.onShowStatusPopup,
    required this.orbitController,
    required this.iconOrbitLines,
  });

  /// Builds a circular button with consistent styling.
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    Color backgroundColor = Colors.transparent,
    String? tooltip,
    bool isActive = false,
    required ThemeProvider themeProvider,
    required VfxProvider vfxProvider,
    required ScaleProvider scaleProvider,
  }) {
    final bool useBloom = vfxProvider.enableBloom;
    final double iconScale = scaleProvider.iconScale;
    final double containerSize = 40 * iconScale;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: backgroundColor != Colors.transparent
              ? backgroundColor
              : themeProvider.inputFillColor,
          shape: BoxShape.circle,
          boxShadow: isActive && useBloom && color != null
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8 * iconScale,
                    spreadRadius: 1 * iconScale,
                  ),
                ]
              : [],
          border: isActive
              ? Border.all(
                  color: color ?? themeProvider.textColor,
                  width: 0.5 * iconScale,
                )
              : Border.all(
                  color: themeProvider.textColor,
                  width: 0.5 * iconScale,
                ),
        ),
        child: IconButton(
          icon: Icon(icon),
          color: color ?? themeProvider.textColor,
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: 20 * iconScale,
          constraints: BoxConstraints(
            minWidth: containerSize,
            minHeight: containerSize,
            maxWidth: containerSize,
            maxHeight: containerSize,
          ),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  /// Builds a toggle button for AI features with animated border when active & loading.
  Widget _buildFeatureSwitch({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onToggle,
    required ThemeProvider themeProvider,
    required VfxProvider vfxProvider,
    required ScaleProvider scaleProvider,
  }) {
    final bool useBloom = vfxProvider.enableBloom;
    final double iconScale = scaleProvider.iconScale;
    final double containerSize = 40 * iconScale;
    final Color iconColor = isActive
        ? activeColor
        : (Colors.grey[400] ?? Colors.grey);

    Widget buttonContent = Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: themeProvider.inputFillColor,
        shape: BoxShape.circle,
        boxShadow: isActive && useBloom
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.6),
                  blurRadius: 8 * iconScale,
                  spreadRadius: 1 * iconScale,
                ),
              ]
            : [],
        border: isActive
            ? Border.all(color: activeColor, width: 0.5 * iconScale)
            : null,
      ),
      child: IconButton(
        icon: Icon(icon),
        color: iconColor,
        onPressed: isLoading ? null : onToggle,
        iconSize: 20 * iconScale,
        constraints: BoxConstraints(
          minWidth: containerSize,
          minHeight: containerSize,
          maxWidth: containerSize,
          maxHeight: containerSize,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      ),
    );

    // Wrap with arc animation if active AND loading AND loading animation enabled
    if (isActive && isLoading && vfxProvider.enableLoadingAnimation) {
      buttonContent = AnimatedBuilder(
        animation: orbitController,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: IconArcPainter(
              progress: orbitController.value,
              lines: iconOrbitLines,
              color: activeColor,
              strokeWidth: 2.5 * iconScale,
              enableBloom: useBloom,
              bloomColor: themeProvider.bloomGlowColor,
            ),
            child: child,
          );
        },
        child: buttonContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: buttonContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final vfxProvider = Provider.of<VfxProvider>(context);
    final scaleProvider = Provider.of<ScaleProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircularButton(
            icon: Icons.attach_file,
            color: themeProvider.textColor,
            tooltip: "Add Attachment",
            onPressed: isLoading ? null : onShowAttachmentMenu,
            themeProvider: themeProvider,
            vfxProvider: vfxProvider,
            scaleProvider: scaleProvider,
          ),
          if (chatProvider.currentProvider == AiProvider.openRouter)
            _buildFeatureSwitch(
              icon: Icons.data_usage,
              isActive: settingsProvider.enableUsage,
              activeColor: Colors.tealAccent,
              onToggle: () async {
                settingsProvider.setEnableUsage(!settingsProvider.enableUsage);
                await settingsProvider.saveSettings(showConfirmation: false);
                onShowStatusPopup(
                  settingsProvider.enableUsage
                      ? "Usage Stats ON"
                      : "Usage Stats OFF",
                );
              },
              themeProvider: themeProvider,
              vfxProvider: vfxProvider,
              scaleProvider: scaleProvider,
            ),
          Tooltip(
            message: 'Web search',
            child: _buildFeatureSwitch(
              icon: Icons.public,
              isActive: settingsProvider.enableGrounding,
              activeColor: Colors.blueAccent,
              onToggle: () async {
                final turningOn = !settingsProvider.enableGrounding;
                if (turningOn) {
                  final reason = chatProvider.webSearchUnsupportedReason();
                  if (reason != null) {
                    onShowStatusPopup(reason);
                    return;
                  }
                }
                settingsProvider.setEnableGrounding(turningOn);
                await settingsProvider.saveSettings(showConfirmation: false);
                onShowStatusPopup(
                  settingsProvider.enableGrounding
                      ? 'Web Search ON'
                      : 'Web Search OFF',
                );
              },
              themeProvider: themeProvider,
              vfxProvider: vfxProvider,
              scaleProvider: scaleProvider,
            ),
          ),
          Builder(
            builder: (context) {
              Color? reasoningColor;
              bool isActive = settingsProvider.reasoningEffort != 'none';

              if (settingsProvider.reasoningEffort == 'low') {
                reasoningColor = Colors.grey[600];
              } else if (settingsProvider.reasoningEffort == 'medium') {
                reasoningColor = Colors.grey[400];
              } else if (settingsProvider.reasoningEffort == 'high') {
                reasoningColor = themeProvider.textColor;
              }

              final Color iconColor = isActive
                  ? (reasoningColor ?? Colors.grey[400]!)
                  : (Colors.grey[400] ?? Colors.grey);
              final double iconScale = scaleProvider.iconScale;
              final double containerSize = 40 * iconScale;

              Widget buttonContent = Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                  color: themeProvider.inputFillColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive &&
                          vfxProvider.enableBloom &&
                          reasoningColor != null
                      ? [
                          BoxShadow(
                            color: reasoningColor.withValues(alpha: 0.6),
                            blurRadius: 8 * iconScale,
                            spreadRadius: 1 * iconScale,
                          ),
                        ]
                      : [],
                  border: isActive
                      ? Border.all(
                          color: reasoningColor ?? themeProvider.textColor,
                          width: 0.5 * iconScale,
                        )
                      : null,
                ),
                child: IconButton(
                  icon: const Icon(Icons.psychology),
                  color: iconColor,
                  tooltip: "Reasoning Effort: ${settingsProvider.reasoningEffort}",
                  onPressed: isLoading
                      ? null
                      : () async {
                          String nextState;
                          String statusMsg;
                          switch (settingsProvider.reasoningEffort) {
                            case 'none':
                              nextState = 'low';
                              statusMsg = "Reasoning: LOW";
                              break;
                            case 'low':
                              nextState = 'medium';
                              statusMsg = "Reasoning: MEDIUM";
                              break;
                            case 'medium':
                              nextState = 'high';
                              statusMsg = "Reasoning: HIGH";
                              break;
                            case 'high':
                              nextState = 'none';
                              statusMsg = "Reasoning: OFF";
                              break;
                            default:
                              nextState = 'low';
                              statusMsg = "Reasoning: LOW";
                          }
                          settingsProvider.setReasoningEffort(nextState);
                          await settingsProvider.saveSettings(
                            showConfirmation: false,
                          );
                          onShowStatusPopup(statusMsg);
                        },
                  iconSize: 20 * iconScale,
                  constraints: BoxConstraints(
                    minWidth: containerSize,
                    minHeight: containerSize,
                    maxWidth: containerSize,
                    maxHeight: containerSize,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ),
              );

              if (isActive && isLoading && vfxProvider.enableLoadingAnimation) {
                buttonContent = AnimatedBuilder(
                  animation: orbitController,
                  builder: (context, child) {
                    return CustomPaint(
                      foregroundPainter: IconArcPainter(
                        progress: orbitController.value,
                        lines: iconOrbitLines,
                        color: reasoningColor ?? themeProvider.textColor,
                        strokeWidth: 2.5 * iconScale,
                        enableBloom: vfxProvider.enableBloom,
                        bloomColor: themeProvider.bloomGlowColor,
                      ),
                      child: child,
                    );
                  },
                  child: buttonContent,
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: containerSize,
                  height: containerSize,
                  child: buttonContent,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[800]),
          const SizedBox(width: 12),
          _buildCircularButton(
            icon: Icons.vertical_align_top,
            tooltip: "Scroll to Top",
            onPressed: onScrollToTop,
            themeProvider: themeProvider,
            vfxProvider: vfxProvider,
            scaleProvider: scaleProvider,
          ),
          _buildCircularButton(
            icon: Icons.vertical_align_bottom,
            tooltip: "Scroll to Bottom",
            onPressed: onScrollToBottom,
            themeProvider: themeProvider,
            vfxProvider: vfxProvider,
            scaleProvider: scaleProvider,
          ),
        ],
      ),
    );
  }
}
