import 'models.dart';

const List<TaxonRank> lineageRanks = <TaxonRank>[
  TaxonRank.kingdom,
  TaxonRank.phylum,
  TaxonRank.classRank,
  TaxonRank.order,
  TaxonRank.family,
  TaxonRank.genus,
  TaxonRank.species,
];

const Map<TaxonRank, String> lineageColumnNames = <TaxonRank, String>{
  TaxonRank.kingdom: 'kingdom',
  TaxonRank.phylum: 'phylum',
  TaxonRank.classRank: 'class',
  TaxonRank.order: 'order',
  TaxonRank.family: 'family',
  TaxonRank.genus: 'genus',
  TaxonRank.species: 'species',
};

class TaxonomyLineageRow {
  const TaxonomyLineageRow({
    required this.lineageByRank,
    required this.commonName,
    required this.notes,
  });

  final Map<TaxonRank, String> lineageByRank;
  final String? commonName;
  final String? notes;
}

class SeedTaxonRecord {
  const SeedTaxonRecord({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.rank,
    required this.parentId,
    required this.notes,
  });

  final int id;
  final String scientificName;
  final String? commonName;
  final TaxonRank rank;
  final int? parentId;
  final String? notes;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'scientific_name': scientificName,
      'common_name': commonName,
      'rank': rank.dbValue,
      'parent_id': parentId,
      'notes': notes,
    };
  }
}

class TaxonomySeedBuilder {
  final Map<_TaxonKey, SeedTaxonRecord> _recordsByKey =
      <_TaxonKey, SeedTaxonRecord>{};
  int _nextId = 1;

  List<SeedTaxonRecord> build(Iterable<TaxonomyLineageRow> rows) {
    for (final TaxonomyLineageRow row in rows) {
      _consumeRow(row);
    }

    final List<SeedTaxonRecord> records = _recordsByKey.values.toList();
    records.sort(
      (SeedTaxonRecord a, SeedTaxonRecord b) => a.id.compareTo(b.id),
    );
    return records;
  }

  void _consumeRow(TaxonomyLineageRow row) {
    int? parentId;
    final List<TaxonRank> presentRanks = lineageRanks
        .where((TaxonRank rank) => row.lineageByRank.containsKey(rank))
        .toList(growable: false);

    for (final TaxonRank rank in presentRanks) {
      final String scientificName = row.lineageByRank[rank]!;
      final bool isTerminalRank = rank == presentRanks.last;
      final _TaxonKey key = _TaxonKey(
        scientificName: scientificName,
        rank: rank,
        parentId: parentId,
      );

      final SeedTaxonRecord record = _recordsByKey.putIfAbsent(
        key,
        () => SeedTaxonRecord(
          id: _nextId++,
          scientificName: scientificName,
          commonName: isTerminalRank ? row.commonName : null,
          rank: rank,
          parentId: parentId,
          notes: isTerminalRank ? row.notes : null,
        ),
      );

      parentId = record.id;
    }
  }
}

class _TaxonKey {
  const _TaxonKey({
    required this.scientificName,
    required this.rank,
    required this.parentId,
  });

  final String scientificName;
  final TaxonRank rank;
  final int? parentId;

  @override
  bool operator ==(Object other) {
    return other is _TaxonKey &&
        other.scientificName == scientificName &&
        other.rank == rank &&
        other.parentId == parentId;
  }

  @override
  int get hashCode => Object.hash(scientificName, rank, parentId);
}
