import 'package:flutter/material.dart';

/// A platform-agnostic Google Sign-In button.
/// 
/// On mobile, this renders a custom button with "Continue with Google".
/// On web (via conditional import), it renders the official Google SDK button.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // This is the mobile/default implementation: Custom UI
    final colorScheme = Theme.of(context).colorScheme;
    
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: SizedBox(
          width: 24,
          height: 24,
          // Use a network image for the logo or local asset if available.
          // Since the original code used network, we stick to it.
          child: Image.network(
            'https://fonts.gstatic.com/s/i/productlogos/googleg/v6/24px.svg',
            errorBuilder: (context, error, stackTrace) => Icon(Icons.public, color: colorScheme.onSurface),
          ),
        ),
        label: Text(
          'Continue with Google',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colorScheme.surface,
        ),
      ),
    );
  }
}
