import 'package:flutter/material.dart';

import '../models/reports_model.dart';

class ReportCardWidget extends StatelessWidget {
  final ReportsModel model;
  final VoidCallback onTap;

  const ReportCardWidget({
    super.key,
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Light and dark use the same recipe: tint the theme surface with the
    // report colour, then write the label in the normal text colour.
    final cardColor = Color.alphaBlend(
      model.foregroundColor.withValues(alpha: 0.18),
      theme.colorScheme.surface,
    );
    final labelColor = theme.colorScheme.onSurface;

    return Material(
      color: cardColor,
      elevation: 0,
      // shadowColor: model.foregroundColor.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: model.foregroundColor.withValues(alpha: 0.14),
        highlightColor: model.foregroundColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: model.foregroundColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(),
              const Spacer(),
              Text(
                model.label,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (model.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  model.description,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: labelColor.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

   Widget _buildTopRow() {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: model.foregroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(model.iconData, color: Colors.white, size: 26),
        ),
        const Spacer(),
        Container(
          height: 26,
          width: 26,
          decoration: BoxDecoration(
            color: model.foregroundColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward,
            color: model.foregroundColor,
            size: 16,
          ),
        ),
      ],
    );
  }
}
