import 'product_card_data.dart';

class CompletedOrderInventory {
  CompletedOrderInventory._();

  static final Map<String, int> _deductedQuantities = {};

  static void recordCompletedOrder(List<ProductCardData> products) {
    for (final product in products) {
      if (product.quantity <= 0) continue;

      final key = _productKey(product);
      _deductedQuantities.update(
        key,
        (quantity) => quantity + product.quantity,
        ifAbsent: () => product.quantity,
      );
    }
  }

  static void resetForTesting() {
    _deductedQuantities.clear();
  }

  static ProductCardData applyCompletedOrderDeductions(
    ProductCardData product,
  ) {
    final deductedQuantity = _deductedQuantities[_productKey(product)] ?? 0;
    final adjustedAvailableQuantity =
        product.availableQuantity - deductedQuantity;
    final availableQuantity = adjustedAvailableQuantity < 0
        ? 0
        : adjustedAvailableQuantity;

    return product.copyWith(
      availableQuantity: availableQuantity,
      quantity: availableQuantity > 0 ? 1 : 0,
      isSelected: false,
    );
  }

  static String _productKey(ProductCardData product) {
    if (product.id.isNotEmpty && product.id != 'No ID') return product.id;
    return product.name;
  }
}
