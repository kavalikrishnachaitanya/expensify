// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:expenses/splitwise/services/auth_service.dart';

/// A platform-agnostic Google Sign-In button.
/// 
/// On web, this renders the official Google SDK button using `renderButton`.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // Web implementation: Use the official renderButton widget.
    // We access it via the platform instance cast to the web plugin class.
    // Note: If GoogleSignInPlugin is not the name, we might need GoogleSignInWeb.
    // But commonly it is GoogleSignInPlugin in the web package.
    final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
    
    return SizedBox(
      height: 56,
      child: FutureBuilder<void>(
        // Wait for the Google Sign-In plugin to be initialized before rendering the button.
        future: AuthService.googleSignInInitialized,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Once initialized, render the button
            return Center(
              child: plugin.renderButton(),
            );
          } else if (snapshot.hasError) {
             // Fallback or error state?
            // For now, return empty or retry
            return const Center(child: Icon(Icons.error_outline));
          }
           // While initializing, show a loader or empty
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
