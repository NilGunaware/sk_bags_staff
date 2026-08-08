class KarigarModel {
  const KarigarModel({
    required this.id,
    required this.name,
    required this.mobileNo,
    required this.address,
    required this.shopName,
  });

  final String id;
  final String name;
  final String mobileNo;
  final String address;
  final String shopName;

  factory KarigarModel.fromJson(Map<String, dynamic> json) {
    return KarigarModel(
      id: (json['id'] ?? json['karigar_id'] ?? '').toString(),
      name: (json['name'] ?? json['karigar_name'] ?? '').toString(),
      mobileNo: (json['mobile_no'] ?? json['mobile'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      shopName: (json['shop_name'] ?? json['shop'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile_no': mobileNo,
      'address': address,
      'shop_name': shopName,
    };
  }
}
