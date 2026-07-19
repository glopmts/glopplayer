import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Cache local (SQLite) das configurações e estatísticas da biblioteca de
/// músicas — equivalente ao que a tela "Local Library" do print mostra:
/// contagem de faixas, pasta configurada, última vez escaneada, flags de
/// scan etc. Também guarda os arquivos já escaneados, usados tanto para
/// detectar duplicatas quanto para permitir scan incremental (só olhar
/// o que mudou desde o último scan).
class LibraryDatabase {
  LibraryDatabase._internal();
  static final LibraryDatabase instance = LibraryDatabase._internal();

  static const _dbName = 'library_cache.db';
  static const _dbVersion = 1;

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
            folder_path TEXT NOT NULL DEFAULT '/storage/emulated/0/Music',
            show_duplicate_indicator INTEGER NOT NULL DEFAULT 1,
            auto_scan_frequency TEXT NOT NULL DEFAULT 'daily',
            track_count INTEGER NOT NULL DEFAULT 0,
            last_scanned_at INTEGER
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

        // Garante que sempre existe exatamente 1 linha de configurações.
        await db.insert('library_settings', {'id': 1});
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
    String? folderPath,
    bool? showDuplicateIndicator,
    String? autoScanFrequency,
  }) async {
    final db = await database;
    final values = <String, Object?>{};
    if (enabled != null) values['enabled'] = enabled ? 1 : 0;
    if (folderPath != null) values['folder_path'] = folderPath;
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

  /// Remove do cache entradas cujo arquivo não existe mais no disco.
  /// Retorna quantas foram removidas ("Cleanup Missing Files" do print).
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

  /// Apaga todo o cache ("Clear Library" do print) — não mexe nos arquivos
  /// reais, só zera o que o app guardou sobre eles.
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
