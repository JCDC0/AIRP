import 'package:flutter/material.dart';
import '../../models/chat_models.dart';

class MessageBubbleActions extends StatelessWidget {
  final ChatMessage msg;
  final Color textColor;
  final double iconScale;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;
  final VoidCallback? onNextVersion;
  final VoidCallback? onPreviousVersion;
  final VoidCallback? onBranch;

  const MessageBubbleActions({
    super.key,
    required this.msg,
    required this.textColor,
    required this.iconScale,
    this.onCopy,
    this.onEdit,
    this.onRegenerate,
    this.onDelete,
    this.onNextVersion,
    this.onPreviousVersion,
    this.onBranch,
  });

  Widget _buildIconBtn(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    Color color,
    double size,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, size: size, color: color.withValues(alpha: 0.5)),
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          hoverColor: color.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActions =
        onRegenerate != null ||
        onCopy != null ||
        onEdit != null ||
        onDelete != null ||
        onNextVersion != null ||
        onPreviousVersion != null ||
        onBranch != null;

    if (!hasActions) return const SizedBox.shrink();

    final hasVersions = !msg.isUser && msg.regenerationVersions.length > 1;
    final totalVersions = hasVersions ? msg.regenerationVersions.length : 0;
    final currentVersionNum = hasVersions ? msg.currentVersionIndex + 1 : 0;

    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 8,
        left: 4,
        right: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRegenerate != null)
            _buildIconBtn(
              Icons.refresh,
              "Regenerate",
              onRegenerate!,
              textColor,
              25 * iconScale,
            ),
          if (onCopy != null)
            _buildIconBtn(
              Icons.copy_rounded,
              "Copy",
              onCopy!,
              textColor,
              25 * iconScale,
            ),
          if (onEdit != null)
            _buildIconBtn(
              Icons.edit_outlined,
              "Edit",
              onEdit!,
              textColor,
              25 * iconScale,
            ),
          if (onDelete != null)
            _buildIconBtn(
              Icons.delete_outline,
              "Delete",
              onDelete!,
              textColor,
              25 * iconScale,
            ),
          // Version navigation buttons
          if (hasVersions && onPreviousVersion != null)
            _buildIconBtn(
              Icons.arrow_back,
              "Previous version",
              onPreviousVersion!,
              textColor,
              25 * iconScale,
            ),
          // Version counter
          if (hasVersions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: textColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  "$currentVersionNum/$totalVersions",
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 12 * iconScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Next version button
          if (hasVersions && onNextVersion != null)
            _buildIconBtn(
              Icons.arrow_forward,
              "Next version",
              onNextVersion!,
              textColor,
              25 * iconScale,
            ),
          // Branch button
          if (onBranch != null)
            _buildIconBtn(
              Icons.call_split,
              "Branch conversation",
              onBranch!,
              textColor,
              25 * iconScale,
            ),
        ],
      ),
    );
  }
}
