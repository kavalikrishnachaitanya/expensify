import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A custom HTTP client that injects Google Sign-In auth headers.
class GoogleDriveService {
  late final GoogleSignIn _googleSignIn;

  GoogleDriveService() {
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb
          ? dotenv.env['WEB_CLIENT_ID']
          : dotenv.env['IOS_CLIENT_ID'],
      scopes: [drive.DriveApi.driveAppdataScope],
    );
  }

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  static const String _backupFileName = 'expenditure_backup.json';

  GoogleSignInAccount? get currentUser => _currentUser;

  /// Sign in silently if previously authenticated.
  Future<bool> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _initDriveApi();
        return true;
      }
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
    return false;
  }

  /// Interactive sign-in.
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _initDriveApi();
        return true;
      }
    } catch (e) {
      debugPrint('Sign-in failed: $e');
    }
    return false;
  }

  /// Sign out.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  /// Initialize the Drive API with authenticated client.
  Future<void> _initDriveApi() async {
    if (_currentUser == null) return;
    
    final client = await _googleSignIn.authenticatedClient();
    if (client != null) {
      _driveApi = drive.DriveApi(client);
    }
  }

  /// Fetch the remote backup file metadata (ID).
  Future<String?> _getBackupFileId() async {
    if (_driveApi == null) return null;

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }
    } catch (e) {
      debugPrint('Error getting backup file ID: $e');
    }
    return null;
  }

  /// Upload the JSON string to the appDataFolder.
  Future<bool> uploadData(String jsonString) async {
    if (_driveApi == null) return false;

    try {
      final fileId = await _getBackupFileId();
      final content = utf8.encode(jsonString);
      final media = drive.Media(Stream.value(content), content.length);

      final driveFile = drive.File()..name = _backupFileName;

      if (fileId != null) {
        // Update existing file
        await _driveApi!.files.update(
          driveFile,
          fileId,
          uploadMedia: media,
        );
      } else {
        // Create new file
        driveFile.parents = ['appDataFolder'];
        await _driveApi!.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return false;
    }
  }

  /// Download the JSON string from the appDataFolder.
  Future<String?> downloadData() async {
    if (_driveApi == null) return null;

    try {
      final fileId = await _getBackupFileId();
      if (fileId == null) return null;

      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await response.stream.expand((e) => e).toList();
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('Download failed: $e');
      return null;
    }
  }
}
