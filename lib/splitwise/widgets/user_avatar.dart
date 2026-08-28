import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    this.enableViewerOnTap = false,
    this.onTap,
  });

  static const List<Color> _avatarColors = [
    Color(0xFF6C5CE7), // Vibrant Purple
    Color(0xFF00CEC9), // Fresh Teal
    Color(0xFF0984E3), // Sky Blue
    Color(0xFFE17055), // Warm Coral
    Color(0xFF00B894), // Emerald Green
    Color(0xFFE84393), // Rose Pink
    Color(0xFFFD9644), // Amber Orange
    Color(0xFF2E86DE), // Royal Blue
    Color(0xFF10AC84), // Jungle Mint
    Color(0xFF5F27CD), // Deep Indigo
  ];

  Color _getColorForName(String name) {
    if (name.trim().isEmpty) return _avatarColors[0];
    final cleanName = name.trim().toLowerCase();
    final hash = cleanName.codeUnits.fold(0, (prev, elem) => prev + elem);
    return _avatarColors[hash % _avatarColors.length];
  }

  Widget _buildInitials(Color bgColor, String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.85,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getColorForName(displayName);
    final initials = Helpers.getInitials(displayName);

    Widget content;
    final url = photoUrl?.trim();

    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image') || url.length > 200) {
        // Base64 uploaded custom image
        try {
          final base64Clean = url.contains(',') ? url.split(',').last : url;
          final sanitized = base64Clean.replaceAll(RegExp(r'\s+'), '');
          final Uint8List bytes = base64Decode(sanitized);
          content = ClipOval(
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _buildInitials(bgColor, initials),
            ),
          );
        } catch (_) {
          content = _buildInitials(bgColor, initials);
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        // Network URL image with errorBuilder to prevent 429 crashes
        content = ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildInitials(bgColor, initials),
          ),
        );
      } else if (url.startsWith('assets/')) {
        // Asset image
        content = ClipOval(
          child: Image.asset(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildInitials(bgColor, initials),
          ),
        );
      } else if (!kIsWeb && url.startsWith('/')) {
        // Local file image
        try {
          final file = File(url);
          if (file.existsSync()) {
            content = ClipOval(
              child: Image.file(
                file,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => _buildInitials(bgColor, initials),
              ),
            );
          } else {
            content = _buildInitials(bgColor, initials);
          }
        } catch (_) {
          content = _buildInitials(bgColor, initials);
        }
      } else {
        content = _buildInitials(bgColor, initials);
      }
    } else {
      content = _buildInitials(bgColor, initials);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
