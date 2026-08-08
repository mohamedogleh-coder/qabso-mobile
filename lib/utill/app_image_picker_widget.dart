import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A reusable circular image picker: preview + pick/replace/remove, backed
/// by an optional existing network image (e.g. a stored avatar URL).
///
/// This widget only manages the *local* picking UX. It reports the user's
/// choice through [onChanged] and never uploads or persists anything itself
/// — callers decide what to do with the picked [File].
///
/// [onChanged] is only invoked in response to a user action:
///  * a non-null [File] means the user picked a new local image.
///  * `null` means the user explicitly removed the image (local or network).
/// It is never called just because the widget was built with an
/// [initialImageUrl], so "no callback yet" always means "unchanged".
class AppImagePickerWidget extends StatefulWidget {
  const AppImagePickerWidget({
    super.key,
    this.initialImageUrl,
    this.onChanged,
    this.size = 96,
    this.enabled = true,
  });

  final String? initialImageUrl;
  final ValueChanged<File?>? onChanged;
  final double size;
  final bool enabled;

  @override
  State<AppImagePickerWidget> createState() => _AppImagePickerWidgetState();
}

class _AppImagePickerWidgetState extends State<AppImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();

  File? _localFile;
  bool _removed = false;
  bool _isPicking = false;
  String? _errorMessage;

  bool get _hasImage =>
      _localFile != null || (!_removed && widget.initialImageUrl != null);

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _localFile = File(picked.path);
        _removed = false;
      });
      widget.onChanged?.call(_localFile);
    } catch (_) {
      setState(() => _errorMessage = 'Could not open the image picker.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeImage() {
    setState(() {
      _localFile = null;
      _removed = true;
      _errorMessage = null;
    });
    widget.onChanged?.call(null);
  }

  Future<void> _showSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickImage(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: widget.enabled && !_isPicking ? _showSourcePicker : null,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surfaceContainerHighest,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isPicking
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : _hasImage
                    ? (_localFile != null
                          ? Image.file(_localFile!, fit: BoxFit.cover)
                          : Image.network(
                              widget.initialImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.person_outline,
                                    size: widget.size * 0.5,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ))
                    : Icon(
                        Icons.person_outline,
                        size: widget.size * 0.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Material(
                color: colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.enabled && !_isPicking
                      ? _showSourcePicker
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            if (_hasImage)
              Positioned(
                top: -4,
                right: -4,
                child: Material(
                  color: colorScheme.error,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.enabled && !_isPicking ? _removeImage : null,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: colorScheme.onError,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(color: colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
