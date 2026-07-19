import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SongsDb {
  static const String _dbName = 'songs.db';
  static const int _dbVersion = 2;
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
            song_id INTEGER PRIMARY KEY,
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
      },
    );
  }

  static Future<String?> getArtworkPath(int songId) async {
    final db = await instance;
    final rows = await db.query(
      _artworkTable,
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['file_path'] as String;
  }

  static Future<void> saveArtworkPath(int songId, String filePath) async {
    final db = await instance;
    await db.insert(
      _artworkTable,
      {
        'song_id': songId,
        'file_path': filePath,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteArtwork(int songId) async {
    final db = await instance;
    await db.delete(_artworkTable, where: 'song_id = ?', whereArgs: [songId]);
  }

  static Future<void> clearAllArtwork() async {
    final db = await instance;
    await db.delete(_artworkTable);
  }
}
