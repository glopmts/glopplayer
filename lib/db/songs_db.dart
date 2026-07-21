import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SongsDb {
  static const String _dbName = 'songs.db';
  static const int _dbVersion = 3; // <- bump de versão
  static const String _artworkTable = 'artwork_cache';

  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_artworkTable (
            art_key TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_artworkTable (
              song_id INTEGER PRIMARY KEY,
              file_path TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          // Schema antigo usava song_id puro (ambíguo entre música/álbum/artista).
          // Mais seguro dropar e recriar do zero — o cache se repopula sozinho.
          await db.execute('DROP TABLE IF EXISTS $_artworkTable');
          await db.execute('''
            CREATE TABLE $_artworkTable (
              art_key TEXT PRIMARY KEY,
              file_path TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  static Future<String?> getArtworkPath(String artKey) async {
    final db = await instance;
    final rows = await db.query(
      _artworkTable,
      where: 'art_key = ?',
      whereArgs: [artKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['file_path'] as String;
  }

  static Future<void> saveArtworkPath(String artKey, String filePath) async {
    final db = await instance;
    await db.insert(
      _artworkTable,
      {
        'art_key': artKey,
        'file_path': filePath,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteArtwork(String artKey) async {
    final db = await instance;
    await db.delete(_artworkTable, where: 'art_key = ?', whereArgs: [artKey]);
  }

  static Future<void> clearAllArtwork() async {
    final db = await instance;
    await db.delete(_artworkTable);
  }
}
