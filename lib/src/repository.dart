import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_schema.dart';
import 'models.dart';

class TaxonomyRepository {
  Database? _database;

  Future<Database> _openDatabase() async {
    if (_database != null) {
      return _database!;
    }

    if (kIsWeb) {
      throw UnsupportedError(
        'This MVP uses SQLite and is currently set up for Android, iOS, macOS, Linux, and Windows.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        break;
    }

    final directory = await getApplicationSupportDirectory();
    final String dbPath = p.join(directory.path, 'phylogeny_viewer.db');
    await _ensureDatabasePresent(dbPath);

    _database = await openDatabase(
      dbPath,
      version: taxonomyDatabaseVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (Database db, int version) async {
        for (final String statement in taxonomySchemaStatements) {
          await db.execute(statement);
        }
      },
    );

    return _database!;
  }

  Future<void> _ensureDatabasePresent(String dbPath) async {
    final File file = File(dbPath);
    if (await file.exists()) {
      return;
    }

    await file.parent.create(recursive: true);

    try {
      final ByteData bundledDatabase = await rootBundle.load(
        bundledSeedDatabaseAssetPath,
      );
      final List<int> bytes = bundledDatabase.buffer.asUint8List(
        bundledDatabase.offsetInBytes,
        bundledDatabase.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
    } on FlutterError {
      final Database fallback = await openDatabase(
        dbPath,
        version: taxonomyDatabaseVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (Database db, int version) async {
          for (final String statement in taxonomySchemaStatements) {
            await db.execute(statement);
          }
        },
      );
      await fallback.close();
    }
  }

  Future<List<Taxon>> fetchTaxa() async {
    final Database db = await _openDatabase();
    final List<Map<String, Object?>> rows = await db.query('taxa');
    return rows.map(Taxon.fromMap).toList(growable: false);
  }

  Future<List<Observation>> fetchObservations() async {
    final Database db = await _openDatabase();
    final List<Map<String, Object?>> rows = await db.query(
      'observations',
      orderBy: 'seen_at DESC',
    );
    return rows.map(Observation.fromMap).toList(growable: false);
  }

  Future<void> saveTaxon({int? id, required TaxonDraft draft}) async {
    final Database db = await _openDatabase();
    if (id == null) {
      await db.insert('taxa', draft.toMap());
      return;
    }

    await db.update(
      'taxa',
      draft.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> addObservation(ObservationDraft draft) async {
    final Database db = await _openDatabase();
    await db.insert('observations', draft.toMap());
  }
}
