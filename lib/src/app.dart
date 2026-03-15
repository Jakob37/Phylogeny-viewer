import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:intl/intl.dart';

import 'controller.dart';
import 'models.dart';
import 'repository.dart';

class TaxonomyApp extends StatefulWidget {
  const TaxonomyApp({super.key});

  @override
  State<TaxonomyApp> createState() => _TaxonomyAppState();
}

class _TaxonomyAppState extends State<TaxonomyApp> {
  late final TaxonomyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TaxonomyController(TaxonomyRepository());
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Phylogeny Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E4F),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F0E7),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return TaxonomyHomePage(controller: _controller);
        },
      ),
    );
  }
}

class TaxonomyHomePage extends StatefulWidget {
  const TaxonomyHomePage({super.key, required this.controller});

  final TaxonomyController controller;

  @override
  State<TaxonomyHomePage> createState() => _TaxonomyHomePageState();
}

class _TaxonomyHomePageState extends State<TaxonomyHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  TaxonomyController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (controller.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phylogeny Viewer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(controller.errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: controller.initialize,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phylogeny Viewer'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Taxa'),
            Tab(text: 'Tree'),
            Tab(text: 'Graph'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaxonEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Taxon'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          TaxaTab(
            controller: controller,
            onEditTaxon: (Taxon taxon) =>
                _showTaxonEditor(context, taxon: taxon),
            onAddObservation: (Taxon taxon) =>
                _showObservationEditor(context, taxon),
          ),
          TreeTab(controller: controller),
          GraphTab(controller: controller),
        ],
      ),
    );
  }

  Future<void> _showTaxonEditor(BuildContext context, {Taxon? taxon}) async {
    final TaxonDraft? draft = await showDialog<TaxonDraft>(
      context: context,
      builder: (BuildContext context) {
        return TaxonDialog(
          existingTaxon: taxon,
          parentOptions: controller.parentOptionsFor(editingTaxonId: taxon?.id),
        );
      },
    );

    if (draft == null) {
      return;
    }

    await controller.saveTaxon(id: taxon?.id, draft: draft);
  }

  Future<void> _showObservationEditor(BuildContext context, Taxon taxon) async {
    final ObservationDraft? draft = await showDialog<ObservationDraft>(
      context: context,
      builder: (BuildContext context) => ObservationDialog(taxon: taxon),
    );
    if (draft == null) {
      return;
    }

    await controller.addObservation(draft);
    if (mounted) {
      _tabController.animateTo(1);
    }
  }
}

class TaxaTab extends StatefulWidget {
  const TaxaTab({
    super.key,
    required this.controller,
    required this.onEditTaxon,
    required this.onAddObservation,
  });

  final TaxonomyController controller;
  final ValueChanged<Taxon> onEditTaxon;
  final ValueChanged<Taxon> onAddObservation;

  @override
  State<TaxaTab> createState() => _TaxaTabState();
}

class _TaxaTabState extends State<TaxaTab> {
  late final TextEditingController _searchController;

  TaxonomyController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: controller.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Taxon> filteredTaxa = controller.filteredTaxa;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: controller.setSearchQuery,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search by scientific name, common name, or rank',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  DropdownButtonHideUnderline(
                    child: DropdownButton<TaxonRank?>(
                      value: controller.selectedRank,
                      hint: const Text('All ranks'),
                      items: <DropdownMenuItem<TaxonRank?>>[
                        const DropdownMenuItem<TaxonRank?>(
                          value: null,
                          child: Text('All ranks'),
                        ),
                        ...TaxonRank.values.map(
                          (TaxonRank rank) => DropdownMenuItem<TaxonRank?>(
                            value: rank,
                            child: Text(rank.label),
                          ),
                        ),
                      ],
                      onChanged: controller.setSelectedRank,
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: controller.focusedRootId,
                      hint: const Text('All branches'),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All branches'),
                        ),
                        ...controller.taxa.map(
                          (Taxon taxon) => DropdownMenuItem<int?>(
                            value: taxon.id,
                            child: Text(taxon.scientificName),
                          ),
                        ),
                      ],
                      onChanged: controller.setFocusedRoot,
                    ),
                  ),
                  FilterChip(
                    selected: controller.seenOnly,
                    label: const Text('Seen only'),
                    onSelected: controller.setSeenOnly,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredTaxa.isEmpty
              ? Center(
                  child: Text(
                    'No taxa match the current filters.',
                    style: theme.textTheme.titleMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: filteredTaxa.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Taxon taxon = filteredTaxa[index];
                    final int observationCount = controller.observationCountFor(
                      taxon.id,
                    );
                    final Observation? latestObservation = controller
                        .latestObservationFor(taxon.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Checkbox(
                                  value: controller.selectedTaxonIds.contains(
                                    taxon.id,
                                  ),
                                  onChanged: (_) =>
                                      controller.toggleSelected(taxon.id),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        taxon.scientificName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      if (taxon.commonName != null &&
                                          taxon.commonName!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            taxon.commonName!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Add sighting',
                                  onPressed: () =>
                                      widget.onAddObservation(taxon),
                                  icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit taxon',
                                  onPressed: () => widget.onEditTaxon(taxon),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              observationCount == 0
                                  ? taxon.rank.label
                                  : latestObservation == null
                                  ? '${taxon.rank.label} • Seen $observationCount time${observationCount == 1 ? '' : 's'}'
                                  : '${taxon.rank.label} • Seen $observationCount time${observationCount == 1 ? '' : 's'} • ${DateFormat.yMMMd().format(latestObservation.seenAt.toLocal())}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class TreeTab extends StatelessWidget {
  const TreeTab({super.key, required this.controller});

  final TaxonomyController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TaxonNode> roots = controller.selectedTree;

    if (roots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select one or more taxa from the list to build the minimal connecting tree.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: roots
          .map(
            (TaxonNode node) =>
                TreeNodeCard(node: node, controller: controller, depth: 0),
          )
          .toList(growable: false),
    );
  }
}

class GraphTab extends StatefulWidget {
  const GraphTab({super.key, required this.controller});

  final TaxonomyController controller;

  @override
  State<GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<GraphTab> {
  final GraphViewController _graphController = GraphViewController();
  late final BuchheimWalkerConfiguration _configuration;

  TaxonomyController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _configuration = BuchheimWalkerConfiguration()
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT
      ..siblingSeparation = 28
      ..levelSeparation = 96
      ..subtreeSeparation = 96;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TaxonNode> roots = controller.selectedTree;

    if (roots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select one or more taxa to render a graphical hierarchy view.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final _GraphBuildResult graphResult = _buildGraph(roots);

    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: IconButton(
              tooltip: 'Recenter',
              onPressed: _graphController.zoomToFit,
              icon: const Icon(Icons.center_focus_strong),
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: GraphView.builder(
                graph: graphResult.graph,
                algorithm: BuchheimWalkerAlgorithm(
                  _configuration,
                  TreeEdgeRenderer(_configuration),
                ),
                controller: _graphController,
                animated: true,
                autoZoomToFit: true,
                builder: (Node node) {
                  final TaxonNode taxonNode =
                      graphResult.taxonNodesById[node.key!.value as int]!;
                  return GraphTaxonNodeCard(
                    node: taxonNode,
                    observationCount: controller.observationCountFor(
                      taxonNode.taxon.id,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  _GraphBuildResult _buildGraph(List<TaxonNode> roots) {
    final Graph graph = Graph()..isTree = true;
    final Map<int, Node> graphNodesById = <int, Node>{};
    final Map<int, TaxonNode> taxonNodesById = <int, TaxonNode>{};

    void addTaxonNode(TaxonNode current) {
      taxonNodesById[current.taxon.id] = current;
      final bool isNewCurrentNode = !graphNodesById.containsKey(
        current.taxon.id,
      );
      final Node currentGraphNode = graphNodesById.putIfAbsent(
        current.taxon.id,
        () => Node.Id(current.taxon.id),
      );
      if (isNewCurrentNode) {
        graph.addNode(currentGraphNode);
      }

      for (final TaxonNode child in current.children) {
        taxonNodesById[child.taxon.id] = child;
        final bool isNewChildNode = !graphNodesById.containsKey(child.taxon.id);
        final Node childGraphNode = graphNodesById.putIfAbsent(
          child.taxon.id,
          () => Node.Id(child.taxon.id),
        );
        if (isNewChildNode) {
          graph.addNode(childGraphNode);
        }
        graph.addEdge(currentGraphNode, childGraphNode);
        addTaxonNode(child);
      }
    }

    for (final TaxonNode root in roots) {
      addTaxonNode(root);
    }

    return _GraphBuildResult(graph, taxonNodesById);
  }
}

class TreeNodeCard extends StatelessWidget {
  const TreeNodeCard({
    super.key,
    required this.node,
    required this.controller,
    required this.depth,
  });

  final TaxonNode node;
  final TaxonomyController controller;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int observationCount = controller.observationCountFor(node.taxon.id);

    return Padding(
      padding: EdgeInsets.only(left: depth * 20, bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: node.isSelected ? const Color(0xFFE2F0EA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: node.isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: node.isSelected ? 4 : 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          node.taxon.scientificName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (node.taxon.commonName != null &&
                            node.taxon.commonName!.isNotEmpty)
                          Text(
                            node.taxon.commonName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Chip(label: Text(node.taxon.rank.label)),
                ],
              ),
              const SizedBox(height: 8),
              if (!node.isSelected)
                Text('Ancestor context', style: theme.textTheme.bodySmall),
              if (observationCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Seen $observationCount time${observationCount == 1 ? '' : 's'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (node.children.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                ...node.children.map(
                  (TaxonNode child) => TreeNodeCard(
                    node: child,
                    controller: controller,
                    depth: depth + 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GraphTaxonNodeCard extends StatelessWidget {
  const GraphTaxonNodeCard({
    super.key,
    required this.node,
    required this.observationCount,
  });

  final TaxonNode node;
  final int observationCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color borderColor = node.isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final Color backgroundColor = node.isSelected
        ? const Color(0xFFE2F0EA)
        : const Color(0xFFF8F6F1);

    return Container(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: node.isSelected ? 2 : 1),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            node.taxon.scientificName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (node.taxon.commonName != null &&
              node.taxon.commonName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                node.taxon.commonName!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(node.taxon.rank.label),
              ),
              if (observationCount > 0)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text('$observationCount seen'),
                ),
            ],
          ),
          if (!node.isSelected) ...<Widget>[
            const SizedBox(height: 8),
            Text('Ancestor context', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class TaxonDialog extends StatefulWidget {
  const TaxonDialog({
    super.key,
    required this.parentOptions,
    this.existingTaxon,
  });

  final Taxon? existingTaxon;
  final List<Taxon> parentOptions;

  @override
  State<TaxonDialog> createState() => _TaxonDialogState();
}

class _TaxonDialogState extends State<TaxonDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _scientificNameController;
  late final TextEditingController _commonNameController;
  late final TextEditingController _notesController;
  late TaxonRank _selectedRank;
  int? _selectedParentId;

  @override
  void initState() {
    super.initState();
    _scientificNameController = TextEditingController(
      text: widget.existingTaxon?.scientificName ?? '',
    );
    _commonNameController = TextEditingController(
      text: widget.existingTaxon?.commonName ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existingTaxon?.notes ?? '',
    );
    _selectedRank = widget.existingTaxon?.rank ?? TaxonRank.species;
    _selectedParentId = widget.existingTaxon?.parentId;
  }

  @override
  void dispose() {
    _scientificNameController.dispose();
    _commonNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingTaxon == null ? 'Add taxon' : 'Edit taxon'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _scientificNameController,
                  decoration: const InputDecoration(
                    labelText: 'Scientific name',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Scientific name is required.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _commonNameController,
                  decoration: const InputDecoration(labelText: 'Common name'),
                ),
                DropdownButtonFormField<TaxonRank>(
                  initialValue: _selectedRank,
                  items: TaxonRank.values
                      .map(
                        (TaxonRank rank) => DropdownMenuItem<TaxonRank>(
                          value: rank,
                          child: Text(rank.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (TaxonRank? value) {
                    if (value != null) {
                      setState(() {
                        _selectedRank = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Rank'),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedParentId,
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No parent'),
                    ),
                    ...widget.parentOptions.map(
                      (Taxon taxon) => DropdownMenuItem<int?>(
                        value: taxon.id,
                        child: Text(taxon.displayName),
                      ),
                    ),
                  ],
                  onChanged: (int? value) {
                    setState(() {
                      _selectedParentId = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Parent taxon'),
                ),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.of(context).pop(
              TaxonDraft(
                scientificName: _scientificNameController.text.trim(),
                commonName: _nullableTrimmed(_commonNameController.text),
                rank: _selectedRank,
                parentId: _selectedParentId,
                notes: _nullableTrimmed(_notesController.text),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class ObservationDialog extends StatefulWidget {
  const ObservationDialog({super.key, required this.taxon});

  final Taxon taxon;

  @override
  State<ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends State<ObservationDialog> {
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add sighting for ${widget.taxon.scientificName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Seen on ${DateFormat.yMMMMd().format(_selectedDate)}',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      initialDate: _selectedDate,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Change'),
                ),
              ],
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location note'),
            ),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              ObservationDraft(
                taxonId: widget.taxon.id,
                seenAt: _selectedDate,
                locationNote: _nullableTrimmed(_locationController.text),
                notes: _nullableTrimmed(_notesController.text),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String? _nullableTrimmed(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _GraphBuildResult {
  const _GraphBuildResult(this.graph, this.taxonNodesById);

  final Graph graph;
  final Map<int, TaxonNode> taxonNodesById;
}
