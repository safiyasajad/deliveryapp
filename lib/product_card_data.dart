// Immutable data model for one product row in the delivery workflow.
//
// ProductSelectionPage creates this object from the backend product list.
// The same object is copied when the user selects an item or changes quantity,
// then the selected rows are passed to PaymentCollectionPage for the order
// summary and total calculation.
class ProductCardData {
  const ProductCardData({
    required this.id,
    required this.name,
    required this.availableQuantity,
    required this.unitPrice,
    required this.quantity,
    required this.isSelected,
  });

  // Backend product id. This should be sent to future order/stock endpoints.
  final String id;

  // Product display name shown on product cards and order summaries.
  final String name;

  // Quantity currently available according to the backend product response.
  // The frontend no longer deducts this locally; it trusts the fetched value.
  final int availableQuantity;

  // Price for one unit of the product.
  final double unitPrice;

  // Quantity selected for the current in-progress order.
  final int quantity;

  // Whether this product is included in the current order.
  final bool isSelected;

  // Creates a modified copy while keeping the model immutable. Product
  // selection and quantity changes use this instead of mutating fields.
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
