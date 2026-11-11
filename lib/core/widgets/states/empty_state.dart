import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/theme/app_spacing.dart';
import 'package:flutter_agentify/core/theme/app_typography.dart';

/// An empty state with an icon or illustration, a title, an optional
/// description and up to two actions.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Widget? illustration;
  final double iconSize;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
    this.iconSize = AppSpacing.iconIllustration,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final defaultIconColor = iconColor ?? colorScheme.primary;
    final description = this.description;
    final actionLabel = this.actionLabel;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space8),
        // Keeps the full-width action button phone-sized on wide windows.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration or Icon
              if (illustration != null)
                illustration!
              else
                Container(
                  width: iconSize + 48,
                  height: iconSize + 48,
                  decoration: BoxDecoration(
                    color: defaultIconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, size: iconSize, color: defaultIconColor),
                  ),
                ),

              const SizedBox(height: AppSpacing.space6),

              // Title
              Text(
                title,
                style: AppTypography.headlineSmall(colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),

              // Description
              if (description != null) ...[
                const SizedBox(height: AppSpacing.space2),
                Text(
                  description,
                  style: AppTypography.bodyMedium(colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
              ],

              // Actions
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.space6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ),
              ],

              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: AppSpacing.space3),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
