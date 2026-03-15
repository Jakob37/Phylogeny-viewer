enum TaxonRank { kingdom, phylum, classRank, order, family, genus, species }

extension TaxonRankX on TaxonRank {
  String get dbValue => switch (this) {
    TaxonRank.kingdom => 'kingdom',
    TaxonRank.phylum => 'phylum',
    TaxonRank.classRank => 'class',
    TaxonRank.order => 'order',
    TaxonRank.family => 'family',
    TaxonRank.genus => 'genus',
    TaxonRank.species => 'species',
  };

  String get label => switch (this) {
    TaxonRank.kingdom => 'Kingdom',
    TaxonRank.phylum => 'Phylum',
    TaxonRank.classRank => 'Class',
    TaxonRank.order => 'Order',
    TaxonRank.family => 'Family',
    TaxonRank.genus => 'Genus',
    TaxonRank.species => 'Species',
  };

  static TaxonRank fromDb(String value) {
    return TaxonRank.values.firstWhere(
      (TaxonRank rank) => rank.dbValue == value,
      orElse: () => TaxonRank.species,
    );
  }
}

class Taxon {
  const Taxon({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.rank,
    required this.parentId,
    required this.notes,
  });

  factory Taxon.fromMap(Map<String, Object?> map) {
    return Taxon(
      id: map['id']! as int,
      scientificName: map['scientific_name']! as String,
      commonName: map['common_name'] as String?,
      rank: TaxonRankX.fromDb(map['rank']! as String),
      parentId: map['parent_id'] as int?,
      notes: map['notes'] as String?,
    );
  }

  final int id;
  final String scientificName;
  final String? commonName;
  final TaxonRank rank;
  final int? parentId;
  final String? notes;

  String get displayName {
    if (commonName != null && commonName!.trim().isNotEmpty) {
      return '$scientificName (${commonName!.trim()})';
    }
    return scientificName;
  }
}

class TaxonDraft {
  const TaxonDraft({
    required this.scientificName,
    required this.commonName,
    required this.rank,
    required this.parentId,
    required this.notes,
  });

  final String scientificName;
  final String? commonName;
  final TaxonRank rank;
  final int? parentId;
  final String? notes;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'scientific_name': scientificName,
      'common_name': commonName,
      'rank': rank.dbValue,
      'parent_id': parentId,
      'notes': notes,
    };
  }
}

class Observation {
  const Observation({
    required this.id,
    required this.taxonId,
    required this.seenAt,
    required this.locationNote,
    required this.notes,
  });

  factory Observation.fromMap(Map<String, Object?> map) {
    return Observation(
      id: map['id']! as int,
      taxonId: map['taxon_id']! as int,
      seenAt: DateTime.parse(map['seen_at']! as String),
      locationNote: map['location_note'] as String?,
      notes: map['notes'] as String?,
    );
  }

  final int id;
  final int taxonId;
  final DateTime seenAt;
  final String? locationNote;
  final String? notes;
}

class ObservationDraft {
  const ObservationDraft({
    required this.taxonId,
    required this.seenAt,
    required this.locationNote,
    required this.notes,
  });

  final int taxonId;
  final DateTime seenAt;
  final String? locationNote;
  final String? notes;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'taxon_id': taxonId,
      'seen_at': seenAt.toIso8601String(),
      'location_note': locationNote,
      'notes': notes,
    };
  }
}

class TaxonNode {
  const TaxonNode({
    required this.taxon,
    required this.isSelected,
    required this.children,
  });

  final Taxon taxon;
  final bool isSelected;
  final List<TaxonNode> children;
}

List<TaxonNode> buildSelectedTree({
  required List<Taxon> taxa,
  required Set<int> selectedIds,
}) {
  if (selectedIds.isEmpty) {
    return const <TaxonNode>[];
  }

  final Map<int, Taxon> taxonById = <int, Taxon>{
    for (final Taxon taxon in taxa) taxon.id: taxon,
  };

  final Set<int> includedIds = <int>{};
  for (final int id in selectedIds) {
    int? currentId = id;
    while (currentId != null && includedIds.add(currentId)) {
      currentId = taxonById[currentId]?.parentId;
    }
  }

  final Map<int?, List<Taxon>> childrenByParent = <int?, List<Taxon>>{};
  for (final int id in includedIds) {
    final Taxon taxon = taxonById[id]!;
    childrenByParent.putIfAbsent(taxon.parentId, () => <Taxon>[]).add(taxon);
  }

  List<TaxonNode> buildNodes(int? parentId) {
    final List<Taxon> children = childrenByParent[parentId] ?? <Taxon>[];
    children.sort((Taxon a, Taxon b) {
      final int byRank = a.rank.index.compareTo(b.rank.index);
      if (byRank != 0) {
        return byRank;
      }
      return a.scientificName.compareTo(b.scientificName);
    });

    return children
        .map(
          (Taxon taxon) => TaxonNode(
            taxon: taxon,
            isSelected: selectedIds.contains(taxon.id),
            children: buildNodes(taxon.id),
          ),
        )
        .toList(growable: false);
  }

  final List<Taxon> roots = includedIds
      .map((int id) => taxonById[id]!)
      .where((Taxon taxon) => !includedIds.contains(taxon.parentId))
      .toList(growable: false);
  roots.sort(
    (Taxon a, Taxon b) => a.scientificName.compareTo(b.scientificName),
  );

  return roots
      .map(
        (Taxon root) => TaxonNode(
          taxon: root,
          isSelected: selectedIds.contains(root.id),
          children: buildNodes(root.id),
        ),
      )
      .toList(growable: false);
}
