import 'package:deliveryapp/completed_order_inventory.dart';
import 'package:deliveryapp/product_card_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CompletedOrderInventory.resetForTesting);

  test('deducts completed order quantity from available stock', () {
    const product = ProductCardData(
      id: 'product-1',
      name: 'product1',
      availableQuantity: 17,
      unitPrice: 23.32,
      quantity: 2,
      isSelected: true,
    );

    CompletedOrderInventory.recordCompletedOrder([product]);

    final adjustedProduct =
        CompletedOrderInventory.applyCompletedOrderDeductions(
          product.copyWith(quantity: 1, isSelected: false),
        );

    expect(adjustedProduct.availableQuantity, 15);
    expect(adjustedProduct.quantity, 1);
    expect(adjustedProduct.isSelected, isFalse);
  });

  test('sets product out of stock when completed quantities exhaust stock', () {
    const product = ProductCardData(
      id: 'product-2',
      name: 'product2',
      availableQuantity: 2,
      unitPrice: 23.32,
      quantity: 2,
      isSelected: true,
    );

    CompletedOrderInventory.recordCompletedOrder([product]);

    final adjustedProduct =
        CompletedOrderInventory.applyCompletedOrderDeductions(
          product.copyWith(quantity: 1, isSelected: false),
        );

    expect(adjustedProduct.availableQuantity, 0);
    expect(adjustedProduct.quantity, 0);
    expect(adjustedProduct.isSelected, isFalse);
  });
}
