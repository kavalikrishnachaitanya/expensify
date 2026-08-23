import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expenses/splitwise/services/auth_service.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/services/firestore_service.dart';

/// Provider for authentication state
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        try {
          _userModel = await _firestoreService.getUser(user.uid);
          if (_userModel == null) {
            final newUser = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName ?? (user.email != null && user.email!.contains('@') ? user.email!.split('@')[0] : 'User'),
              photoUrl: user.photoURL ?? 'assets/images/boy.png',
              createdAt: DateTime.now(),
            );
            await _firestoreService.createUser(newUser);
            _userModel = newUser;
          }
        } catch (e) {
          debugPrint('Error fetching/creating user model: $e');
        }
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// Sign in with email
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      await _authService.signInWithEmail(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Sign up with email
  Future<bool> signUpWithEmail(
    String email,
    String password,
    String displayName, {
    String? gender,
    String? photoUrl,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _authService.signUpWithEmail(
        email,
        password,
        displayName,
        gender: gender,
        photoUrl: photoUrl,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _authService.signInWithGoogle();
      _setLoading(false);
      return result != null;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Complete Google Sign-In profile with avatar selection
  Future<bool> completeGoogleSignUp(String photoUrl, {String? gender}) async {
    _setLoading(true);
    _error = null;

    try {
      if (_user == null) {
        throw Exception('No user is currently signed in');
      }

      await _authService.createUserDocument(
        _user!,
        _user!.displayName ?? 'User',
        photoUrl: photoUrl,
        gender: gender,
      );

      // Reload user model
      _userModel = await _firestoreService.getUser(_user!.uid);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile(String displayName, String? photoUrl) async {
    _setLoading(true);
    _error = null;

    try {
      if (_user == null) throw Exception('No user signed in');

      // Update Firebase Auth user
      await _user!.updateDisplayName(displayName);
      if (photoUrl != null) await _user!.updatePhotoURL(photoUrl);

      // Update Firestore user
      final data = <String, dynamic>{
        'displayName': displayName,
      };
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }

      await _firestoreService.updateUser(_user!.uid, data);

      // Reload user
      await _user!.reload();
      _user = _authService.currentUser;
      _userModel = await _firestoreService.getUser(_user!.uid);

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Delete account checking for dues
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _error = null;

    try {
      if (_user == null) throw Exception('No user signed in');

      final canDelete = await _firestoreService.checkIfUserCanBeDeleted(_user!.uid);
      if (!canDelete) {
        throw Exception(
            'Cannot delete account. Please settle all outstanding balances in your groups first.');
      }

      await _firestoreService.deleteUserData(_user!.uid);
      await _authService.deleteAccount();

      // Clear local state
      _user = null;
      _userModel = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
