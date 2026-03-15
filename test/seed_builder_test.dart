import 'package:flutter_test/flutter_test.dart';
import 'package:phylogeny_viewer/src/models.dart';
import 'package:phylogeny_viewer/src/seed_builder.dart';

void main() {
  test(
    'TaxonomySeedBuilder reuses shared ancestors across multiple species',
    () {
      final List<SeedTaxonRecord> records = TaxonomySeedBuilder().build(
        const <TaxonomyLineageRow>[
          TaxonomyLineageRow(
            lineageByRank: <TaxonRank, String>{
              TaxonRank.kingdom: 'Plantae',
              TaxonRank.phylum: 'Tracheophyta',
              TaxonRank.classRank: 'Magnoliopsida',
              TaxonRank.order: 'Ericales',
              TaxonRank.family: 'Primulaceae',
              TaxonRank.genus: 'Primula',
              TaxonRank.species: 'Primula veris',
            },
            commonName: 'cowslip',
            notes: null,
          ),
          TaxonomyLineageRow(
            lineageByRank: <TaxonRank, String>{
              TaxonRank.kingdom: 'Plantae',
              TaxonRank.phylum: 'Tracheophyta',
              TaxonRank.classRank: 'Magnoliopsida',
              TaxonRank.order: 'Ericales',
              TaxonRank.family: 'Primulaceae',
              TaxonRank.genus: 'Primula',
              TaxonRank.species: 'Primula vulgaris',
            },
            commonName: 'primrose',
            notes: null,
          ),
        ],
      );

      final Iterable<SeedTaxonRecord> primulaRecords = records.where(
        (SeedTaxonRecord record) =>
            record.rank == TaxonRank.genus &&
            record.scientificName == 'Primula',
      );
      final Iterable<SeedTaxonRecord> speciesRecords = records.where(
        (SeedTaxonRecord record) => record.rank == TaxonRank.species,
      );

      expect(primulaRecords, hasLength(1));
      expect(speciesRecords, hasLength(2));
      expect(
        speciesRecords.every(
          (SeedTaxonRecord record) =>
              record.parentId == primulaRecords.single.id,
        ),
        isTrue,
      );
    },
  );
}
