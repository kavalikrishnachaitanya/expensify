import 'package:flutter/material.dart';
import 'package:expenses/splitwise/utils/helpers.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    ImageProvider? imageProvider;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      if (photoUrl!.startsWith('http')) {
        imageProvider = NetworkImage(photoUrl!);
      } else if (photoUrl!.startsWith('assets')) {
        imageProvider = AssetImage(photoUrl!);
      }
    }

    return CircleAvatar(
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
  }
}
