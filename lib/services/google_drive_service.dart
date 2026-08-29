import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A custom HTTP client that injects Google Sign-In auth headers and provides offline local caching.
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;
  drive.DriveApi? _driveApi;
  static const String _backupFileName = 'expenditure_backup.json';
  static const String _avatarFileName = 'profile_avatar.txt';

  static const String _keyDriveToken = 'google_drive_access_token';
  static const String _keyDriveExpiry = 'google_drive_token_expiry';
  static const String _keyLocalCache = 'cached_expenses_backup';
  static const String _keyAvatarCache = 'cached_profile_avatar';

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isDriveConnected => _driveApi != null;
  
  String? get userDisplayName => _currentUser?.displayName ?? FirebaseAuth.instance.currentUser?.displayName;
  String? get userEmail => _currentUser?.email ?? FirebaseAuth.instance.currentUser?.email;
  String? get userPhotoUrl => _currentUser?.photoUrl ?? FirebaseAuth.instance.currentUser?.photoURL;

  static bool _isInitialized = false;

  static final Map<String, String> _memoryCache = {};

  Future<void> _setSafeString(String key, String value) async {
    _memoryCache[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<String?> _getSafeString(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(key);
      if (val != null) _memoryCache[key] = val;
      return val;
    } catch (_) {
      return _memoryCache[key];
    }
  }

  Future<void> _removeSafeString(String key) async {
    _memoryCache.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Helper to initialize GoogleSignIn singleton safely once
  static Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? dotenv.env['WEB_CLIENT_ID']
            : dotenv.env['IOS_CLIENT_ID'],
      );
      _isInitialized = true;
    } catch (e) {
      _isInitialized = true;
      debugPrint('GoogleSignIn already initialized or notice: $e');
    }
  }

  /// Sync Google account with Firebase Auth
  Future<void> _syncWithFirebaseAuth() async {
    if (_currentUser == null) return;
    try {
      final googleAuth = _currentUser!.authentication;
      final accessToken = _authorization?.accessToken;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('Successfully auto-synced Google user with Firebase Auth!');
    } catch (e) {
      debugPrint('Firebase auto-sync from Expensify login failed: $e');
    }
  }

  /// Sign in silently if previously authenticated.
  Future<bool> signInSilently() async {
    final List<String> scopes = [drive.DriveApi.driveAppdataScope];

    if (!kIsWeb) {
      try {
        await ensureInitialized();
        _currentUser = await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (_currentUser != null) {
          _authorization = await _currentUser!.authorizationClient.authorizeScopes(scopes);
          await _initDriveApi(scopes);
          await _syncWithFirebaseAuth();
          return true;
        }
      } catch (e) {
        debugPrint('Silent sign-in failed: $e');
      }
    }

    if (kIsWeb) {
      try {
        final token = await _getSafeString(_keyDriveToken);
        final expiryStr = await _getSafeString(_keyDriveExpiry);

        if (token != null && expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && expiry.isAfter(DateTime.now().toUtc())) {
            final authClient = auth.authenticatedClient(
              http.Client(),
              auth.AccessCredentials(
                auth.AccessToken('Bearer', token, expiry),
                null,
                scopes,
              ),
            );
            _driveApi = drive.DriveApi(authClient);
            return true;
          }
        }
      } catch (e) {
        debugPrint('Error restoring saved web drive token: $e');
      }

      return _driveApi != null;
    }

    return false;
  }

  String? lastError;

  /// Interactive sign-in.
  Future<bool> signIn() async {
    lastError = null;
    final List<String> scopes = [drive.DriveApi.driveAppdataScope];

    // 1. On Web: Use FirebaseAuth.signInWithPopup with drive scope
    if (kIsWeb) {
      try {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope(drive.DriveApi.driveAppdataScope);
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);

        if (userCredential.user != null || FirebaseAuth.instance.currentUser != null) {
          final OAuthCredential? oAuthCred = userCredential.credential as OAuthCredential?;
          final accessToken = oAuthCred?.accessToken;
          
          if (accessToken != null && accessToken.isNotEmpty) {
            final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));

            final authClient = auth.authenticatedClient(
              http.Client(),
              auth.AccessCredentials(
                auth.AccessToken('Bearer', accessToken, expiry),
                null,
                scopes,
              ),
            );
            _driveApi = drive.DriveApi(authClient);

            await _setSafeString(_keyDriveToken, accessToken);
            await _setSafeString(_keyDriveExpiry, expiry.toIso8601String());
          }
          return _driveApi != null;
        }
      } catch (fbErr) {
        debugPrint('Firebase popup sign-in notice: $fbErr');
        if (_driveApi != null) {
          return true;
        }
        lastError = fbErr.toString();
      }

      return _driveApi != null;
    }

    // 2. On Mobile/Desktop: Try GoogleSignIn authenticate
    try {
      await ensureInitialized();
      _currentUser = await GoogleSignIn.instance.authenticate();
      if (_currentUser != null) {
        try {
          _authorization = await _currentUser!.authorizationClient.authorizeScopes(scopes);
        } catch (authErr) {
          debugPrint('Drive scope auth error: $authErr');
        }
        await _initDriveApi(scopes);
        await _syncWithFirebaseAuth();
        return true;
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('GoogleSignIn.authenticate error: $e');
    }

    lastError ??= 'Sign in was canceled or could not be completed.';
    return false;
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _removeSafeString(_keyDriveToken);
    await _removeSafeString(_keyDriveExpiry);
    await _removeSafeString(_keyLocalCache);
    await _removeSafeString(_keyAvatarCache);
    _currentUser = null;
    _authorization = null;
    _driveApi = null;
  }

  /// Initialize the Drive API with authenticated client.
  Future<void> _initDriveApi(List<String> scopes) async {
    if (_authorization == null) return;
    
    final client = _authorization!.authClient(scopes: scopes);
    _driveApi = drive.DriveApi(client);
  }

  /// Fetch the remote file metadata (ID) by filename.
  Future<String?> _getFileId(String fileName) async {
    if (_driveApi == null) return null;

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '$fileName'",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }
    } catch (e) {
      debugPrint('Error getting file ID for $fileName: $e');
    }
    return null;
  }

  /// Cache expenses JSON locally in persistent storage.
  Future<void> cacheData(String jsonString) async {
    await _setSafeString(_keyLocalCache, jsonString);
  }

  /// Get locally cached expenses JSON.
  Future<String?> getCachedData() async {
    return _getSafeString(_keyLocalCache);
  }

  /// Upload the JSON string to the appDataFolder and cache locally.
  Future<bool> uploadData(String jsonString) async {
    await cacheData(jsonString);
    if (_driveApi == null) {
      await signInSilently();
    }
    if (_driveApi == null) {
      debugPrint('Google Drive API not connected, data cached locally.');
      return false;
    }

    try {
      final fileId = await _getFileId(_backupFileName);
      final content = utf8.encode(jsonString);
      final media = drive.Media(Stream.value(content), content.length);

      final driveFile = drive.File()..name = _backupFileName;

      if (fileId != null) {
        await _driveApi!.files.update(
          driveFile,
          fileId,
          uploadMedia: media,
        );
      } else {
        driveFile.parents = ['appDataFolder'];
        await _driveApi!.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      debugPrint('✓ Successfully uploaded latest backup to Google Drive appDataFolder!');
      return true;
    } catch (e) {
      debugPrint('Upload to Google Drive failed: $e. Retrying with token refresh...');
      try {
        final refreshed = await signInSilently();
        if (refreshed && _driveApi != null) {
          final fileId = await _getFileId(_backupFileName);
          final content = utf8.encode(jsonString);
          final media = drive.Media(Stream.value(content), content.length);
          final driveFile = drive.File()..name = _backupFileName;
          if (fileId != null) {
            await _driveApi!.files.update(driveFile, fileId, uploadMedia: media);
          } else {
            driveFile.parents = ['appDataFolder'];
            await _driveApi!.files.create(driveFile, uploadMedia: media);
          }
          debugPrint('✓ Upload to Google Drive succeeded on retry!');
          return true;
        }
      } catch (retryErr) {
        debugPrint('Retry upload failed: $retryErr');
      }
      return false;
    }
  }

  /// Download the JSON string from the appDataFolder (or local cache).
  Future<String?> downloadData() async {
    if (_driveApi == null) {
      await signInSilently();
    }
    if (_driveApi == null) {
      debugPrint('Google Drive API not connected in downloadData, loading cached data.');
      return getCachedData();
    }

    try {
      final fileId = await _getFileId(_backupFileName);
      if (fileId == null) {
        debugPrint('No remote backup file found in Google Drive appDataFolder, loading cache.');
        return getCachedData();
      }

      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.expand((e) => e).toList();
      final decoded = utf8.decode(bytes);
      if (decoded.isNotEmpty) {
        await cacheData(decoded);
        debugPrint('✓ Successfully downloaded fresh backup from Google Drive!');
        return decoded;
      }
      return getCachedData();
    } catch (e) {
      debugPrint('Download from Google Drive failed: $e. Retrying with token refresh...');
      try {
        final refreshed = await signInSilently();
        if (refreshed && _driveApi != null) {
          final fileId = await _getFileId(_backupFileName);
          if (fileId != null) {
            final response = await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            ) as drive.Media;
            final bytes = await response.stream.expand((e) => e).toList();
            final decoded = utf8.decode(bytes);
            if (decoded.isNotEmpty) {
              await cacheData(decoded);
              debugPrint('✓ Download from Google Drive succeeded on retry!');
              return decoded;
            }
          }
        }
      } catch (retryErr) {
        debugPrint('Retry download failed: $retryErr');
      }
      return getCachedData();
    }
  }

  /// Backup profile avatar string/base64 to appDataFolder on Google Drive and local cache
  Future<bool> uploadAvatarData(String avatarStr) async {
    await _setSafeString(_keyAvatarCache, avatarStr);

    if (_driveApi == null) return false;
    try {
      final fileId = await _getFileId(_avatarFileName);
      final content = utf8.encode(avatarStr);
      final media = drive.Media(Stream.value(content), content.length);

      final driveFile = drive.File()..name = _avatarFileName;

      if (fileId != null) {
        await _driveApi!.files.update(driveFile, fileId, uploadMedia: media);
      } else {
        driveFile.parents = ['appDataFolder'];
        await _driveApi!.files.create(driveFile, uploadMedia: media);
      }
      return true;
    } catch (e) {
      debugPrint('Avatar upload to Drive failed: $e');
      return false;
    }
  }

  /// Download cached profile avatar from Google Drive or local cache
  Future<String?> downloadAvatarData() async {
    if (_driveApi == null) {
      return _getSafeString(_keyAvatarCache);
    }
    try {
      final fileId = await _getFileId(_avatarFileName);
      if (fileId == null) {
        return _getSafeString(_keyAvatarCache);
      }

      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.expand((e) => e).toList();
      final decoded = utf8.decode(bytes);
      if (decoded.isNotEmpty) {
        await _setSafeString(_keyAvatarCache, decoded);
      }
      return decoded;
    } catch (e) {
      debugPrint('Avatar download from Drive failed: $e');
      return _getSafeString(_keyAvatarCache);
    }
  }

  /// Delete ALL backup data & files from appDataFolder in Google Drive and local cache
  Future<bool> deleteAllData() async {
    await _removeSafeString(_keyLocalCache);
    await _removeSafeString(_keyAvatarCache);

    if (_driveApi == null) return true;

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        for (var file in files) {
          if (file.id != null) {
            await _driveApi!.files.delete(file.id!);
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing Drive backup data: $e');
      return false;
    }
  }
}
