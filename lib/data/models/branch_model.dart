class BranchModel {
  const BranchModel({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
