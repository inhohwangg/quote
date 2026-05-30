import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/note.dart';

// ---------------------------------------------------------------------------
// Minimal authenticated HTTP client that injects Google OAuth headers.
// Avoids the extension_google_sign_in_as_googleapis_auth dependency.
// ---------------------------------------------------------------------------
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Backs up / restores all Hive notes to the user's Google Drive
/// **appDataFolder** (hidden from the user's Drive UI, app-scoped only).
///
/// Setup checklist (done once per Firebase/GCP project):
///   1. Enable "Google Drive API" in Google Cloud Console.
///   2. Add SHA-1 fingerprint of your signing key to the OAuth credential.
///   3. Download google-services.json → android/app/
///   4. Replace placeholder package name in google-services.json if needed.
class DriveBackupService {
  static const _backupFileName = 'notes_backup_v1.json';

  final _signIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  // ---------- Auth ----------

  Future<GoogleSignInAccount?> signIn() => _signIn.signIn();

  Future<void> signOut() => _signIn.signOut();

  GoogleSignInAccount? get currentUser => _signIn.currentUser;

  /// Returns an authenticated DriveApi, or null if not signed in.
  Future<drive.DriveApi?> _api() async {
    final account =
        _signIn.currentUser ?? await _signIn.signInSilently();
    if (account == null) return null;
    final headers = await account.authHeaders;
    return drive.DriveApi(_AuthClient(headers));
  }

  // ---------- Backup ----------

  /// Serialises [notes] to JSON and uploads to appDataFolder.
  /// Replaces any existing backup file.
  Future<void> backup(List<Note> notes) async {
    final api = await _api();
    if (api == null) throw Exception('Google 로그인이 필요합니다.');

    final payload = jsonEncode(
      notes
          .map((n) => {
                'id': n.id,
                'title': n.title,
                'content': n.content,
                'createdAt': n.createdAt.toIso8601String(),
                'updatedAt': n.updatedAt.toIso8601String(),
                'drawingJson': n.drawingJson,
              })
          .toList(),
    );

    final bytes = utf8.encode(payload);

    // Delete previous backup to avoid duplicates.
    final oldId = await _findFileId(api);
    if (oldId != null) {
      await api.files.delete(oldId);
    }

    // Stream upload — avoids loading the entire file into a byte buffer.
    final media = drive.Media(
      Stream.fromIterable([bytes]),
      bytes.length,
      contentType: 'application/json',
    );

    await api.files.create(
      drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'],
      uploadMedia: media,
    );
  }

  // ---------- Restore ----------

  /// Downloads the backup file and returns a list of deserialised notes.
  /// Throws [Exception] if not signed in or no backup exists.
  Future<List<Note>> restore() async {
    final api = await _api();
    if (api == null) throw Exception('Google 로그인이 필요합니다.');

    final fileId = await _findFileId(api);
    if (fileId == null) throw Exception('백업 파일이 없습니다.');

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    // Collect streamed chunks without excessive memory allocations.
    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }

    final raw = jsonDecode(utf8.decode(chunks)) as List<dynamic>;

    return raw
        .map((item) => Note(
              id: item['id'] as String,
              title: item['title'] as String,
              content: item['content'] as String,
              createdAt: DateTime.parse(item['createdAt'] as String),
              updatedAt: DateTime.parse(item['updatedAt'] as String),
              drawingJson: item['drawingJson'] as String? ?? '[]',
            ))
        .toList();
  }

  // ---------- Helpers ----------

  Future<String?> _findFileId(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName' and trashed = false",
      $fields: 'files(id)',
      pageSize: 1,
    );
    return list.files?.isNotEmpty == true ? list.files!.first.id : null;
  }
}
