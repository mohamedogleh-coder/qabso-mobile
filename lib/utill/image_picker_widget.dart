import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_picker_card.dart';

/// A reusable multi (or single) image picker: pick from the gallery,
/// preview, and remove — for any screen that needs to collect a bounded
/// number of images (e.g. field photos) before uploading them elsewhere.
///
/// This widget only manages the *local* picking UX, mirroring
/// [AppImagePickerWidget]'s split of responsibilities. It never uploads or
/// deletes anything itself:
///  * [onFilesChanged] reports the current list of locally-picked files
///    (i.e. not yet uploaded) every time picking or removing changes it —
///    callers own turning that into an upload.
///  * [onDeleteNetworkImage], if provided, is awaited when the user removes
///    an already-uploaded image (a URL in [networkImages]); the image is
///    only dropped from the grid once it completes without throwing.
///
/// Set [maxImages] to `1` for a single "avatar-style" picker (replacing the
/// current image on each pick) or higher for a grid of up to [maxImages]
/// images with an "add" tile while under the limit.
class ImagePickerWidget extends StatefulWidget {
  const ImagePickerWidget({
    super.key,
    required this.maxImages,
    this.networkImages,
    this.onDeleteNetworkImage,
    this.onFilesChanged,
  }) : assert(maxImages > 0, 'maxImages must be at least 1');

  /// The most images (network + newly picked, combined) this picker allows.
  final int maxImages;

  /// URLs of images already uploaded for whatever this picker edits, shown
  /// alongside anything newly picked. Pass an updated list (e.g. after a
  /// successful upload) to sync the grid — the widget picks up changes via
  /// [didUpdateWidget].
  final List<String>? networkImages;

  /// Called when the user removes a network image; the widget waits for
  /// this to finish before removing the image from the grid. If omitted,
  /// network images render without a delete button (read-only).
  final Future<void> Function(String url)? onDeleteNetworkImage;

  /// Called with the full set of locally-picked (not-yet-uploaded) files
  /// whenever picking or removing changes it.
  final void Function(List<File> files)? onFilesChanged;

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();

  late List<AppImage> _images = (widget.networkImages ?? const [])
      .map((url) => AppImage(path: url, isNetwork: true))
      .toList();
  bool _isPicking = false;
  String? _errorMessage;

  @override
  void didUpdateWidget(covariant ImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkImages != widget.networkImages) {
      setState(() {
        final localImages = _images.where((img) => !img.isNetwork).toList();
        final netImages = (widget.networkImages ?? const [])
            .map((url) => AppImage(path: url, isNetwork: true))
            .toList();
        _images = [...netImages, ...localImages];
      });
    }
  }

  void _notifyFilesChanged() {
    final localFiles = _images
        .where((img) => !img.isNetwork)
        .map((img) => File(img.path))
        .toList();
    widget.onFilesChanged?.call(localFiles);
  }

  Future<void> _handleDelete(AppImage image) async {
    try {
      if (image.isNetwork) {
        await widget.onDeleteNetworkImage?.call(image.path);
      }
      if (!mounted) return;
      setState(() {
        _images.removeWhere((img) => img.path == image.path);
        _errorMessage = null;
      });
      _notifyFilesChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not remove that image.');
    }
  }

  Future<void> _pick() async {
    if (_isPicking || _images.length >= widget.maxImages) return;

    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      if (widget.maxImages == 1) {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (!mounted || file == null) return;
        setState(() {
          _images = [AppImage(path: file.path, isNetwork: false)];
        });
      } else {
        final remaining = widget.maxImages - _images.length;
        final files = await _picker.pickMultiImage(
          imageQuality: 80,
          limit: remaining,
        );
        if (!mounted || files.isEmpty) return;
        setState(() {
          _images = [
            ..._images,
            ...files.map((f) => AppImage(path: f.path, isNetwork: false)),
          ];
        });
      }
      _notifyFilesChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not open the image picker.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          child: _images.isEmpty ? _buildPlaceholder() : _buildImageContent(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageContent() {
    if (widget.maxImages == 1) {
      final img = _images.first;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 150,
              width: 150,
              child: ImageCardWidget(image: img, onDelete: _handleDelete),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _isPicking ? null : _pick,
              icon: const Icon(Icons.edit),
              label: const Text("Change Photo"),
            ),
          ],
        ),
      );
    }

    final showAddCard = _images.length < widget.maxImages;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: showAddCard ? _images.length + 1 : _images.length,
        itemBuilder: (context, index) {
          if (index < _images.length) {
            return ImageCardWidget(
              image: _images[index],
              onDelete: _handleDelete,
            );
          }
          return _buildAddCard();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      height: 150,
      child: Center(
        child: TextButton.icon(
          onPressed: _isPicking ? null : _pick,
          icon: _isPicking
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo),
          label: Text(widget.maxImages == 1 ? "Add Photo" : "Add Photos"),
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return InkWell(
      onTap: _isPicking ? null : _pick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).highlightColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _isPicking
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add, size: 32),
        ),
      ),
    );
  }
}
