import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repository.dart';

class TaxonomyController extends ChangeNotifier {
  TaxonomyController(this._repository);

  final TaxonomyRepository _repository;

  bool _isLoading = true;
  String? _errorMessage;
  List<Taxon> _taxa = const <Taxon>[];
  List<Observation> _observations = const <Observation>[];
  String _searchQuery = '';
  TaxonRank? _selectedRank;
  bool _seenOnly = false;
  int? _focusedRootId;
  final Set<int> _selectedTaxonIds = <int>{};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  TaxonRank? get selectedRank => _selectedRank;
  bool get seenOnly => _seenOnly;
  int? get focusedRootId => _focusedRootId;
  Set<int> get selectedTaxonIds => Set<int>.unmodifiable(_selectedTaxonIds);
  List<Taxon> get taxa => _sortedTaxa(_taxa);
  List<Observation> get observations => _observations;

  int get totalSeenTaxaCount => observationCounts.length;

  Map<int, int> get observationCounts {
    final Map<int, int> counts = <int, int>{};
    for (final Observation observation in _observations) {
      counts.update(
        observation.taxonId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  Map<int, Observation> get latestObservationByTaxon {
    final Map<int, Observation> latest = <int, Observation>{};
    for (final Observation observation in _observations) {
      final Observation? current = latest[observation.taxonId];
      if (current == null || observation.seenAt.isAfter(current.seenAt)) {
        latest[observation.taxonId] = observation;
      }
    }
    return latest;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reloadFromStorage();
    } catch (error) {
      _errorMessage = '$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadFromStorage() async {
    _taxa = _sortedTaxa(await _repository.fetchTaxa());
    _observations = await _repository.fetchObservations();
    _selectedTaxonIds.removeWhere(
      (int id) => _taxa.every((Taxon taxon) => taxon.id != id),
    );
  }

  void setSearchQuery(String value) {
    _searchQuery = value.trim();
    notifyListeners();
  }

  void setSelectedRank(TaxonRank? rank) {
    _selectedRank = rank;
    notifyListeners();
  }

  void setSeenOnly(bool value) {
    _seenOnly = value;
    notifyListeners();
  }

  void setFocusedRoot(int? taxonId) {
    _focusedRootId = taxonId;
    notifyListeners();
  }

  void toggleSelected(int taxonId) {
    if (_selectedTaxonIds.contains(taxonId)) {
      _selectedTaxonIds.remove(taxonId);
    } else {
      _selectedTaxonIds.add(taxonId);
    }
    notifyListeners();
  }

  Future<void> saveTaxon({int? id, required TaxonDraft draft}) async {
    await _repository.saveTaxon(id: id, draft: draft);
    await _reloadFromStorage();
    notifyListeners();
  }

  Future<void> addObservation(ObservationDraft draft) async {
    await _repository.addObservation(draft);
    await _reloadFromStorage();
    notifyListeners();
  }

  List<Taxon> get filteredTaxa {
    final Map<int, Taxon> taxonById = <int, Taxon>{
      for (final Taxon taxon in _taxa) taxon.id: taxon,
    };
    final Set<int>? focusedSubtree = _focusedRootId == null
        ? null
        : _collectDescendants(_focusedRootId!, taxonById: taxonById);
    final Map<int, int> counts = observationCounts;

    return _taxa
        .where((Taxon taxon) {
          if (_selectedRank != null && taxon.rank != _selectedRank) {
            return false;
          }
          if (_seenOnly && !counts.containsKey(taxon.id)) {
            return false;
          }
          if (focusedSubtree != null && !focusedSubtree.contains(taxon.id)) {
            return false;
          }
          if (_searchQuery.isEmpty) {
            return true;
          }
          final String haystack = <String>[
            taxon.scientificName,
            taxon.commonName ?? '',
            taxon.rank.label,
          ].join(' ').toLowerCase();
          return haystack.contains(_searchQuery.toLowerCase());
        })
        .toList(growable: false);
  }

  List<Taxon> parentOptionsFor({int? editingTaxonId}) {
    final Set<int> excludedIds = <int>{};
    if (editingTaxonId != null) {
      final Map<int, Taxon> taxonById = <int, Taxon>{
        for (final Taxon taxon in _taxa) taxon.id: taxon,
      };
      excludedIds.add(editingTaxonId);
      excludedIds.addAll(
        _collectDescendants(editingTaxonId, taxonById: taxonById)
          ..remove(editingTaxonId),
      );
    }

    return _taxa
        .where((Taxon taxon) => !excludedIds.contains(taxon.id))
        .toList(growable: false);
  }

  String lineageFor(Taxon taxon) {
    final Map<int, Taxon> taxonById = <int, Taxon>{
      for (final Taxon item in _taxa) item.id: item,
    };
    final List<String> lineage = <String>[taxon.scientificName];
    int? parentId = taxon.parentId;
    while (parentId != null) {
      final Taxon? parent = taxonById[parentId];
      if (parent == null) {
        break;
      }
      lineage.add(parent.scientificName);
      parentId = parent.parentId;
    }
    return lineage.reversed.join(' > ');
  }

  List<TaxonNode> get selectedTree =>
      buildSelectedTree(taxa: _taxa, selectedIds: _selectedTaxonIds);

  int observationCountFor(int taxonId) => observationCounts[taxonId] ?? 0;

  Observation? latestObservationFor(int taxonId) =>
      latestObservationByTaxon[taxonId];

  Set<int> _collectDescendants(
    int rootId, {
    required Map<int, Taxon> taxonById,
  }) {
    final Set<int> descendants = <int>{rootId};
    bool changed = true;

    while (changed) {
      changed = false;
      for (final Taxon taxon in taxonById.values) {
        if (taxon.parentId != null &&
            descendants.contains(taxon.parentId) &&
            descendants.add(taxon.id)) {
          changed = true;
        }
      }
    }

    return descendants;
  }

  List<Taxon> _sortedTaxa(List<Taxon> taxa) {
    final List<Taxon> sorted = List<Taxon>.of(taxa);
    sorted.sort((Taxon a, Taxon b) {
      final int byRank = a.rank.index.compareTo(b.rank.index);
      if (byRank != 0) {
        return byRank;
      }
      return a.scientificName.compareTo(b.scientificName);
    });
    return sorted;
  }
}
