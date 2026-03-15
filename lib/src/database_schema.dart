const int taxonomyDatabaseVersion = 1;
const String bundledSeedDatabaseAssetPath =
    'assets/seed/phylogeny_viewer_seed.db';

const List<String> taxonomySchemaStatements = <String>[
  '''
  CREATE TABLE taxa (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scientific_name TEXT NOT NULL,
    common_name TEXT,
    rank TEXT NOT NULL,
    parent_id INTEGER REFERENCES taxa(id),
    notes TEXT
  );
  ''',
  '''
  CREATE TABLE observations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    taxon_id INTEGER NOT NULL REFERENCES taxa(id) ON DELETE CASCADE,
    seen_at TEXT NOT NULL,
    location_note TEXT,
    notes TEXT
  );
  ''',
  'CREATE INDEX idx_taxa_parent_id ON taxa(parent_id);',
  'CREATE INDEX idx_observations_taxon_id ON observations(taxon_id);',
];
