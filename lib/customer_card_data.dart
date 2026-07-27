// Small data model for one customer card.
// Dashboard uses it to render customers, and ProductSelectionPage uses it to
// show the customer chosen before selecting products.
class CustomerCardData {
  const CustomerCardData({
    required this.id,
    required this.name,
    required this.code,
    required this.telephone,
    required this.address,
  });

  final String id;
  final String name;
  final String code;
  final String telephone;
  final String address;

  CustomerCardData copyWith({
    String? id,
    String? name,
    String? code,
    String? telephone,
    String? address,
  }) {
    return CustomerCardData(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      telephone: telephone ?? this.telephone,
      address: address ?? this.address,
    );
  }
}
