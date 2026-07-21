import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Cache local (SQLite) das configurações e estatísticas da biblioteca de
/// músicas, incluindo as pastas selecionadas pelo usuário (até 3) e os
/// arquivos já escaneados, usados tanto para detectar duplicatas quanto
/// para permitir scan incremental.
class LibraryDatabase {
  LibraryDatabase._internal();
  static final LibraryDatabase instance = LibraryDatabase._internal();

  static const _dbName = 'library_cache.db';
  static const _dbVersion = 2;
  static const maxFolders = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE library_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            enabled INTEGER NOT NULL DEFAULT 1,
            show_duplicate_indicator INTEGER NOT NULL DEFAULT 1,
            auto_scan_frequency TEXT NOT NULL DEFAULT 'daily',
            track_count INTEGER NOT NULL DEFAULT 0,
            last_scanned_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE library_folders (
            path TEXT PRIMARY KEY,
            added_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE scanned_files (
            path TEXT PRIMARY KEY,
            file_hash TEXT,
            size INTEGER,
            modified_at INTEGER,
            added_at INTEGER NOT NULL
          )
        ''');

        await db.insert('library_settings', {'id': 1});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 tinha um único "folder_path" texto na tabela de settings.
          // v2 migra para uma tabela de N pastas (até maxFolders).
          await db.execute('''
            CREATE TABLE IF NOT EXISTS library_folders (
              path TEXT PRIMARY KEY,
              added_at INTEGER NOT NULL
            )
          ''');

          try {
            final rows = await db.query('library_settings', where: 'id = 1');
            if (rows.isNotEmpty) {
              final oldPath = rows.first['folder_path'] as String?;
              if (oldPath != null && oldPath.isNotEmpty) {
                await db.insert(
                  'library_folders',
                  {
                    'path': oldPath,
                    'added_at': DateTime.now().millisecondsSinceEpoch,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }
            }
          } catch (_) {
            // coluna folder_path pode não existir dependendo do estado do
            // banco durante o desenvolvimento — segue sem migrar dado antigo
          }
        }
      },
    );
  }

  // ---------------------------------------------------------------------
  // Configurações
  // ---------------------------------------------------------------------

  Future<Map<String, Object?>> getSettings() async {
    final db = await database;
    final rows = await db.query('library_settings', where: 'id = 1');
    return rows.first;
  }

  Future<void> updateSettings({
    bool? enabled,
    bool? showDuplicateIndicator,
    String? autoScanFrequency,
  }) async {
    final db = await database;
    final values = <String, Object?>{};
    if (enabled != null) values['enabled'] = enabled ? 1 : 0;
    if (showDuplicateIndicator != null) {
      values['show_duplicate_indicator'] = showDuplicateIndicator ? 1 : 0;
    }
    if (autoScanFrequency != null) {
      values['auto_scan_frequency'] = autoScanFrequency;
    }
    if (values.isEmpty) return;

    await db.update('library_settings', values, where: 'id = 1');
  }

  Future<void> updateStatsAfterScan({required int trackCount}) async {
    final db = await database;
    await db.update(
      'library_settings',
      {
        'track_count': trackCount,
        'last_scanned_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = 1',
    );
  }

  // ---------------------------------------------------------------------
  // Pastas da biblioteca (até maxFolders)
  // ---------------------------------------------------------------------

  Future<List<String>> getFolders() async {
    final db = await database;
    final rows = await db.query('library_folders', orderBy: 'added_at ASC');
    return rows.map((r) => r['path'] as String).toList();
  }

  /// Retorna false se já atingiu o limite de [maxFolders] ou se a pasta
  /// já estava na lista — o controller decide o que fazer com isso.
  Future<bool> addFolder(String path) async {
    final db = await database;
    final current = await getFolders();
    if (current.contains(path)) return false;
    if (current.length >= maxFolders) return false;

    await db.insert(
      'library_folders',
      {'path': path, 'added_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return true;
  }

  Future<void> removeFolder(String path) async {
    final db = await database;
    await db.delete('library_folders', where: 'path = ?', whereArgs: [path]);
  }

  // ---------------------------------------------------------------------
  // Arquivos escaneados (cache incremental / detecção de duplicata)
  // ---------------------------------------------------------------------

  Future<Set<String>> getScannedPaths() async {
    final db = await database;
    final rows = await db.query('scanned_files', columns: ['path']);
    return rows.map((r) => r['path'] as String).toSet();
  }

  Future<void> upsertScannedFile({
    required String path,
    String? fileHash,
    int? size,
    int? modifiedAt,
  }) async {
    final db = await database;
    await db.insert(
      'scanned_files',
      {
        'path': path,
        'file_hash': fileHash,
        'size': size,
        'modified_at': modifiedAt,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> removeMissingPaths(Set<String> stillExistingPaths) async {
    final db = await database;
    final cached = await getScannedPaths();
    final missing = cached.difference(stillExistingPaths);
    if (missing.isEmpty) return 0;

    final batch = db.batch();
    for (final path in missing) {
      batch.delete('scanned_files', where: 'path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
    return missing.length;
  }

  Future<void> clearLibrary() async {
    final db = await database;
    await db.delete('scanned_files');
    await db.update(
      'library_settings',
      {'track_count': 0, 'last_scanned_at': null},
      where: 'id = 1',
    );
  }
}
