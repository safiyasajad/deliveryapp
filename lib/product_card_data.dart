// Small model for one product row.
// ProductSelectionPage uses it for selectable product cards, and
// PaymentCollectionPage uses the selected rows for the order summary.
class ProductCardData {
  const ProductCardData({
    required this.id,
    required this.name,
    required this.availableQuantity,
    required this.unitPrice,
    required this.quantity,
    required this.isSelected,
  });

  final String id;
  final String name;
  final int availableQuantity;
  final double unitPrice;
  final int quantity;
  final bool isSelected;

  ProductCardData copyWith({
    String? id,
    String? name,
    int? availableQuantity,
    double? unitPrice,
    int? quantity,
    bool? isSelected,
  }) {
    return ProductCardData(
      id: id ?? this.id,
      name: name ?? this.name,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
