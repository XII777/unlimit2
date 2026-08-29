import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/db/app_database.dart';

/// Manages the Drift database lifecycle: creation, configuration, and access.
///
/// Uses a single NativeDatabase connection with WAL journal mode for
/// concurrent read access without the race condition that occurs when
/// multiple executors open the same file.
class DriftDbService {
  DriftDbService._();

  static final DriftDbService instance = DriftDbService._();

  late AppDatabase db;

  /// Initializes the database. Must be called once at app startup.
  Future<void> init() async {
    db = await _createDatabase();
  }

  Future<AppDatabase> _createDatabase() async {
    return AppDatabase.withExecutor(LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'ulimit.sqlite'));

      // Set cache directory for sqlite3 temp files
      final cacheBase = (await getTemporaryDirectory()).path;
      sqlite3.tempDirectory = cacheBase;

      return NativeDatabase(file, setup: _setup);
    }));
  }

  /// Configure SQLite pragmas before opening.
  static void _setup(Database db) {
    // Retry up to 5 seconds on lock, then throw
    db.execute('PRAGMA busy_timeout = 5000;');
    // WAL mode: concurrent readers + single writer, no executor race
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA wal_autocheckpoint = 1000;');
  }
}
