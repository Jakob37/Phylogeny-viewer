import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:phylogeny_viewer/src/database_schema.dart';
import 'package:phylogeny_viewer/src/models.dart';
import 'package:phylogeny_viewer/src/seed_builder.dart';

Future<void> main(List<String> args) async {
  final _BuildSeedOptions options = _BuildSeedOptions.parse(args);
  final List<TaxonomyLineageRow> rows = _readCsv(options.inputPath);
  final List<SeedTaxonRecord> records = TaxonomySeedBuilder().build(rows);

  final File outputFile = File(options.outputPath);
  outputFile.parent.createSync(recursive: true);
  if (outputFile.existsSync()) {
    outputFile.deleteSync();
  }

  final File tempSqlFile = File(
    p.join(
      Directory.systemTemp.path,
      'phylogeny_viewer_seed_${DateTime.now().microsecondsSinceEpoch}.sql',
    ),
  );

  try {
    tempSqlFile.writeAsStringSync(_buildSql(records));

    final ProcessResult result = await Process.run('sqlite3', <String>[
      outputFile.path,
      '.read ${tempSqlFile.path}',
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        'sqlite3',
        <String>[outputFile.path, '.read ${tempSqlFile.path}'],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  } finally {
    if (tempSqlFile.existsSync()) {
      tempSqlFile.deleteSync();
    }
  }

  stdout.writeln(
    'Built ${p.relative(outputFile.path)} with ${records.length} taxa from ${rows.length} lineage rows.',
  );
}

String _buildSql(List<SeedTaxonRecord> records) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('PRAGMA foreign_keys = ON;');

  for (final String statement in taxonomySchemaStatements) {
    buffer.writeln(statement.trim());
  }

  buffer.writeln('BEGIN TRANSACTION;');
  for (final SeedTaxonRecord record in records) {
    buffer.writeln('''
INSERT INTO taxa (id, scientific_name, common_name, rank, parent_id, notes)
VALUES (
  ${record.id},
  ${_sqlLiteral(record.scientificName)},
  ${_sqlLiteral(record.commonName)},
  ${_sqlLiteral(record.rank.dbValue)},
  ${record.parentId ?? 'NULL'},
  ${_sqlLiteral(record.notes)}
);
''');
  }
  buffer
    ..writeln('PRAGMA user_version = $taxonomyDatabaseVersion;')
    ..writeln('COMMIT;');
  return buffer.toString();
}

List<TaxonomyLineageRow> _readCsv(String inputPath) {
  final File inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    throw ArgumentError('Input file not found: ${inputFile.path}');
  }

  final String rawCsv = inputFile.readAsStringSync();
  final List<String> lines = const LineSplitter()
      .convert(rawCsv)
      .where((String line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    throw ArgumentError('Input CSV is empty: ${inputFile.path}');
  }

  final List<String> headers = _splitCsvLine(
    lines.first,
  ).map((String value) => value.trim().toLowerCase()).toList(growable: false);

  final List<TaxonomyLineageRow> rows = <TaxonomyLineageRow>[];
  for (final String rawLine in lines.skip(1)) {
    final List<String> rawRow = _splitCsvLine(rawLine);

    final Map<String, String> rowByHeader = <String, String>{};
    for (int index = 0; index < headers.length; index++) {
      rowByHeader[headers[index]] = index < rawRow.length
          ? rawRow[index].trim()
          : '';
    }

    final Map<TaxonRank, String> lineageByRank = <TaxonRank, String>{};
    for (final TaxonRank rank in lineageRanks) {
      final String columnName = lineageColumnNames[rank]!;
      final String value = (rowByHeader[columnName] ?? '').trim();
      if (value.isNotEmpty) {
        lineageByRank[rank] = value;
      }
    }

    if (lineageByRank.isEmpty) {
      continue;
    }

    rows.add(
      TaxonomyLineageRow(
        lineageByRank: lineageByRank,
        commonName: _nullableTrimmed(rowByHeader['common_name']),
        notes: _nullableTrimmed(rowByHeader['notes']),
      ),
    );
  }

  return rows;
}

String? _nullableTrimmed(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _sqlLiteral(String? value) {
  if (value == null) {
    return 'NULL';
  }
  final String escaped = value.replaceAll("'", "''");
  return "'$escaped'";
}

List<String> _splitCsvLine(String line) {
  final List<String> fields = <String>[];
  final StringBuffer current = StringBuffer();
  bool inQuotes = false;

  for (int index = 0; index < line.length; index++) {
    final String char = line[index];
    if (char == '"') {
      if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
        current.write('"');
        index++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char == ',' && !inQuotes) {
      fields.add(current.toString());
      current.clear();
      continue;
    }

    current.write(char);
  }

  fields.add(current.toString());
  return fields;
}

class _BuildSeedOptions {
  const _BuildSeedOptions({required this.inputPath, required this.outputPath});

  final String inputPath;
  final String outputPath;

  static _BuildSeedOptions parse(List<String> args) {
    String inputPath = 'assets/seed/taxa_seed.csv';
    String outputPath = bundledSeedDatabaseAssetPath;

    for (int index = 0; index < args.length; index++) {
      final String arg = args[index];
      if (arg == '--input' && index + 1 < args.length) {
        inputPath = args[++index];
      } else if (arg == '--output' && index + 1 < args.length) {
        outputPath = args[++index];
      } else if (arg == '--help') {
        stdout.writeln(
          'Usage: dart run tool/build_seed_db.dart '
          '[--input assets/seed/taxa_seed.csv] '
          '[--output assets/seed/phylogeny_viewer_seed.db]',
        );
        exit(0);
      }
    }

    return _BuildSeedOptions(inputPath: inputPath, outputPath: outputPath);
  }
}
