import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/utils/constants.dart';

/// Service for handling authentication
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Static future to ensure GoogleSignIn is initialized exactly once.
  static final Future<void> googleSignInInitialized = GoogleSignIn.instance.initialize();

  AuthService() {
    if (kIsWeb) {
      // On web, usages of the Google Sign-In button (renderButton) rely on this stream
      // to notify the app of successful sign-ins.
      final googleSignIn = GoogleSignIn.instance;
      googleSignIn.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _signInWithGoogleAccount(event.user).catchError((e) {
            debugPrint('Error signing in with Google on web: $e');
            return null;
          });
        }
      });
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign up with email and password
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String displayName, {
    String? gender,
    String? photoUrl,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name and photo URL if provided
      await credential.user?.updateDisplayName(displayName);
      if (photoUrl != null) {
        await credential.user?.updatePhotoURL(photoUrl);
      }

      // Create user document in Firestore
      if (credential.user != null) {
        await createUserDocument(
          credential.user!,
          displayName,
          gender: gender,
          photoUrl: photoUrl,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // If FirebaseAuth is ALREADY signed in (e.g. via GoogleDriveService), reuse active session!
      if (_auth.currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
        if (!userDoc.exists) {
          await createUserDocument(
            _auth.currentUser!,
            _auth.currentUser!.displayName ?? 'User',
            photoUrl: _auth.currentUser!.photoURL,
          );
        }
        return null;
      }

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      try {
        await googleSignInInitialized;
      } catch (e) {
        debugPrint('GoogleSignIn initialization failed or already initialized: $e');
      }

      final googleUser = await googleSignIn.authenticate();
      return _signInWithGoogleAccount(googleUser);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  /// Authenticate with Firebase using a Google account
  Future<UserCredential?> _signInWithGoogleAccount(GoogleSignInAccount googleUser) async {
    try {
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: null,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to sign in with Google Account: ${e.toString()}');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Create user document in Firestore
  Future<void> createUserDocument(
    User user,
    String displayName, {
    String? gender,
    String? photoUrl,
  }) async {
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: displayName,
      gender: gender,
      photoUrl: photoUrl ?? user.photoURL,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .set(userModel.toMap());
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return e.message ?? 'An error occurred during authentication.';
    }
  }

  /// Delete the current user account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
