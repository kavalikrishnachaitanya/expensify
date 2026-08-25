import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:expenses/splitwise/utils/helpers.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;
  final bool enableViewerOnTap;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.radius = 20,
    this.enableViewerOnTap = true,
    this.onTap,
  });

  void _showFullScreenPhotoViewer(
    BuildContext context,
    ImageProvider imageProvider,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.contain,
                    height: MediaQuery.of(dialogCtx).size.height * 0.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pinch or double tap to zoom',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? imageProvider;
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      final url = photoUrl!.trim();
      try {
        if (url.startsWith('http://') || url.startsWith('https://')) {
          imageProvider = NetworkImage(url);
        } else if (url.startsWith('assets/')) {
          imageProvider = AssetImage(url);
        } else if (url.startsWith('data:image') || url.length > 100) {
          final base64Clean = url.contains(',') ? url.split(',').last : url;
          final sanitized = base64Clean.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(sanitized);
          imageProvider = MemoryImage(bytes);
        } else if (url.startsWith('/')) {
          final file = File(url);
          if (file.existsSync()) {
            imageProvider = FileImage(file);
          }
        }
      } catch (e) {
        debugPrint('UserAvatar: Error parsing image avatar string: $e');
      }
    }

    final avatarWidget = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              Helpers.getInitials(displayName),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    if (enableViewerOnTap && imageProvider != null) {
      return GestureDetector(
        onTap: () => _showFullScreenPhotoViewer(context, imageProvider!),
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
