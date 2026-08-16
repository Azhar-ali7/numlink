/// A node in the number chain: a value plus the op label that produced it
/// (null for the starting node).
class ChainNode {
  const ChainNode(this.value, [this.opLabel]);

  final int value;
  final String? opLabel;

  Map<String, dynamic> toJson() => {'value': value, 'opLabel': opLabel};

  factory ChainNode.fromJson(Map<String, dynamic> j) =>
      ChainNode(j['value'] as int, j['opLabel'] as String?);
}
