import 'package:flutter_test/flutter_test.dart';
import 'package:phylogeny_viewer/src/models.dart';

void main() {
  test('buildSelectedTree keeps selected taxa and shared ancestors', () {
    const Taxon kingdom = Taxon(
      id: 1,
      scientificName: 'Animalia',
      commonName: null,
      rank: TaxonRank.kingdom,
      parentId: null,
      notes: null,
    );
    const Taxon genus = Taxon(
      id: 2,
      scientificName: 'Panthera',
      commonName: null,
      rank: TaxonRank.genus,
      parentId: 1,
      notes: null,
    );
    const Taxon lion = Taxon(
      id: 3,
      scientificName: 'Panthera leo',
      commonName: 'lion',
      rank: TaxonRank.species,
      parentId: 2,
      notes: null,
    );
    const Taxon leopard = Taxon(
      id: 4,
      scientificName: 'Panthera pardus',
      commonName: 'leopard',
      rank: TaxonRank.species,
      parentId: 2,
      notes: null,
    );

    final List<TaxonNode> tree = buildSelectedTree(
      taxa: const <Taxon>[kingdom, genus, lion, leopard],
      selectedIds: const <int>{3, 4},
    );

    expect(tree, hasLength(1));
    expect(tree.single.taxon.id, 1);
    expect(tree.single.children.single.taxon.id, 2);
    expect(tree.single.children.single.children, hasLength(2));
    expect(
      tree.single.children.single.children.every(
        (TaxonNode node) => node.isSelected,
      ),
      isTrue,
    );
  });
}
