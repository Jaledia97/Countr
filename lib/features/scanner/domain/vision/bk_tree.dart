import 'dhash.dart';

class BkNode {
  final List<String> ids;
  final int hash;
  final Map<int, BkNode> children = {};

  BkNode(String id, this.hash) : ids = [id];
}

class BkTree {
  BkNode? root;

  void add(String id, int hash) {
    if (root == null) {
      root = BkNode(id, hash);
      return;
    }

    BkNode current = root!;
    while (true) {
      int distance = DHash.hammingDistance(current.hash, hash);
      if (distance == 0) {
        current.ids.add(id);
        return; 
      }

      if (current.children.containsKey(distance)) {
        current = current.children[distance]!;
      } else {
        current.children[distance] = BkNode(id, hash);
        break;
      }
    }
  }

  /// Returns a list of (id, distance) for all nodes within the given threshold.
  List<MapEntry<String, int>> search(int hash, {int threshold = 10}) {
    List<MapEntry<String, int>> results = [];
    if (root == null) return results;

    List<BkNode> queue = [root!];
    
    while (queue.isNotEmpty) {
      BkNode current = queue.removeLast();
      int distance = DHash.hammingDistance(current.hash, hash);

      if (distance <= threshold) {
        for (final id in current.ids) {
          results.add(MapEntry(id, distance));
        }
      }

      int minDistance = distance - threshold;
      int maxDistance = distance + threshold;

      for (var entry in current.children.entries) {
        if (entry.key >= minDistance && entry.key <= maxDistance) {
          queue.add(entry.value);
        }
      }
    }

    results.sort((a, b) => a.value.compareTo(b.value));
    return results;
  }
}
