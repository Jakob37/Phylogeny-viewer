# Phylogeny Viewer

Small Flutter app for storing taxa locally, selecting organisms you have seen,
and viewing how selected taxa relate to each other.

## Seed Taxonomy Workflow

The app is designed to start from a bundled SQLite taxonomy database so you can
search for organisms offline immediately.

### Source CSV

Prepare a lineage CSV with these columns:

```text
kingdom,phylum,class,order,family,genus,species,common_name,notes
```

Only the lineage columns are required. The included
`assets/seed/taxa_seed.csv` is a starter example focused on spring flowers.

### Build the bundled SQLite seed

```bash
dart run tool/build_seed_db.dart
```

Optional custom paths:

```bash
dart run tool/build_seed_db.dart --input path/to/taxa.csv --output assets/seed/phylogeny_viewer_seed.db
```

The script creates a SQLite database at `assets/seed/phylogeny_viewer_seed.db`.

### App startup behavior

On first launch, the app copies the bundled seed database into the platform app
support directory. After that, the user works against the local copy, so
observations and edits remain persistent.

If you replace the bundled seed and want to test it from a clean state, delete
the installed app data or reinstall the app.
