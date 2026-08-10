import 'dart:io';

import 'package:flutter/material.dart';

/// A single image managed by [ImagePickerWidget] — either already uploaded
/// (`isNetwork: true`, [path] is a URL) or picked locally and not yet
/// uploaded (`isNetwork: false`, [path] is a local file path).
class AppImage {
  const AppImage({required this.path, required this.isNetwork});

  final String path;
  final bool isNetwork;
}

/// A square thumbnail for one [AppImage], with an optional delete button
/// and its own inline removing spinner. Used by [ImagePickerWidget]; also
/// safe to reuse anywhere else a single picked/uploaded image needs the
/// same preview treatment.
class ImageCardWidget extends StatefulWidget {
  const ImageCardWidget({super.key, required this.image, this.onDelete});

  final AppImage image;
  final Future<void> Function(AppImage image)? onDelete;

  @override
  State<ImageCardWidget> createState() => _ImageCardWidgetState();
}

class _ImageCardWidgetState extends State<ImageCardWidget> {
  bool isRemoving = false;

  Future<void> _handleDelete() async {
    if (widget.onDelete == null || isRemoving) return;

    setState(() => isRemoving = true);

    try {
      await widget.onDelete!(widget.image);
    } finally {
      if (mounted) setState(() => isRemoving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.image.isNetwork
                ? Image.network(
                    widget.image.path,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : Image.file(File(widget.image.path), fit: BoxFit.cover),
          ),
        ),

        if (isRemoving)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),

        if (!isRemoving && widget.onDelete != null)
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: _handleDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
