import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'customer_card_data.dart';
import 'payment_collection_page.dart';
import 'product_card_data.dart';

// ProductSelectionPage opens after the delivery user chooses a customer.
//
// Responsibilities:
// - Show the selected customer name/address at the top.
// - Fetch product stock and prices from the backend product endpoint.
// - Let the delivery user choose one or more products.
// - Clamp each chosen quantity between 1 and the backend available quantity.
// - Pass only selected products to PaymentCollectionPage.
//
// Inventory rule:
// The frontend does not deduct stock locally after an order is completed.
// Product availability is always based on availableQuantity returned by the
// backend, so once the backend deducts inventory, this page will show the new
// value after the next fetch.
class ProductSelectionPage extends StatefulWidget {
  const ProductSelectionPage({
    super.key,
    required this.customer,
    required this.accessToken,
  });

  // Customer chosen on the dashboard.
  // The page uses the name and address in the header area.
  final CustomerCardData customer;

  // JWT returned by login.
  // The product endpoint is called with Authorization: Bearer <token>.
  final String accessToken;

  @override
  State<ProductSelectionPage> createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  // Temporary delay so the product loading state can be seen while developing.
  // Remove this before production.
  static const Duration _debugProductLoadingDelay = Duration(seconds: 2);

  // Product list fetched from the backend.
  List<ProductCardData> _products = const [];

  // API state for the product list.
  bool _isLoadingProducts = false;
  String? _productErrorMessage;

  @override
  void initState() {
    super.initState();

    // Fetch products as soon as the product selection screen opens.
    _fetchProducts();
  }

  int get _selectedItemCount {
    // Counts selected product rows, not the total quantity.
    return _products.where((product) => product.isSelected).length;
  }

  double get _subtotal {
    // Subtotal is calculated only for selected products.
    // Each product contributes unit price * chosen quantity.
    return _products
        .where((product) => product.isSelected)
        .fold<double>(
          0,
          (total, product) => total + (product.unitPrice * product.quantity),
        );
  }

  Future<void> _fetchProducts() async {
    // Fetch fresh product data from the backend. This is the single source of
    // truth for available quantities, prices, and out-of-stock status.
    final apiBaseUrl = dotenv.env['API_BASE_URL'];

    if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
      setState(() {
        _productErrorMessage = 'API base URL is missing from .env.';
      });
      return;
    }

    setState(() {
      _isLoadingProducts = true;
      _productErrorMessage = null;
    });

    try {
      await Future.delayed(_debugProductLoadingDelay);

      if (widget.accessToken.isEmpty) {
        throw Exception(
          'Login token missing. Please log out and log in again.',
        );
      }

      // Product data is requested from the product-management endpoint:
      // /product/product-management?offset=1&limit=15&search=&sortBy=displayOrder&order=ASC
      final uri = Uri.parse(apiBaseUrl).replace(
        path: '/product/product-management',
        queryParameters: const {
          'offset': '1',
          'limit': '15',
          'search': '',
          'sortBy': 'displayOrder',
          'order': 'ASC',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Product request failed with status ${response.statusCode}.',
        );
      }

      final responseBody = _decodeResponseBody(response.body);
      final products = _parseProducts(responseBody);

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _products = const [];
        _isLoadingProducts = false;
        _productErrorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    // Converts JSON into a map. If the API returns a list directly, wrap it in
    // { data: [...] } so the same parsing code can handle it.
    if (body.isEmpty) return const {};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'data': decoded};

    return const {};
  }

  List<ProductCardData> _parseProducts(Map<String, dynamic> responseBody) {
    // Product APIs often wrap the list in different keys. This checks common
    // response shapes such as data, products, items, rows, and result.products.
    final rawProducts = _firstListFromPaths(responseBody, const [
      ['data'],
      ['products'],
      ['product'],
      ['items'],
      ['rows'],
      ['result'],
      ['result', 'products'],
      ['result', 'items'],
      ['result', 'rows'],
      ['data', 'products'],
      ['data', 'items'],
      ['data', 'rows'],
      ['data', 'result'],
    ]);

    return rawProducts
        .whereType<Map<String, dynamic>>()
        .map(_productFromJson)
        .where((product) => product.name.isNotEmpty)
        .toList();
  }

  ProductCardData _productFromJson(Map<String, dynamic> json) {
    // Maps one backend product object into the product card fields.
    // The keys are flexible because the exact product response field names may
    // differ from the names used in the request description.
    final id = _firstStringFromKeys(json, const [
      'id',
      '_id',
      'productId',
      'product_id',
      'itemId',
      'item_id',
      'sku',
      'code',
    ]);

    final name = _firstStringFromKeys(json, const [
      'name',
      'productName',
      'product_name',
      'itemName',
      'item_name',
      'title',
      'description',
    ]);

    // Keep the backend stock value unchanged. No frontend order-completion
    // deductions are applied here.
    final availableQuantity = _firstIntFromKeys(json, const [
      'availableQuantity',
      'available_quantity',
      'availableQty',
      'available_qty',
      'quantity',
      'qty',
      'stock',
      'availableStock',
      'available_stock',
    ]);

    final unitPrice = _firstDoubleFromKeys(json, const [
      'unitPrice',
      'unit_price',
      'price',
      'sellingPrice',
      'selling_price',
      'rate',
    ]);

    return ProductCardData(
      id: id.isEmpty ? 'No ID' : id,
      name: name,
      availableQuantity: availableQuantity,
      unitPrice: unitPrice,
      quantity: availableQuantity > 0 ? 1 : 0,
      isSelected: false,
    );
  }

  List<dynamic> _firstListFromPaths(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    // Reads the first list found at any requested JSON path.
    for (final path in paths) {
      final value = _valueAtPath(source, path);
      if (value is List) return value;

      if (value is Map<String, dynamic>) {
        final nestedList = _firstListFromKeys(value, const [
          'products',
          'product',
          'items',
          'rows',
          'data',
          'result',
        ]);
        if (nestedList.isNotEmpty) return nestedList;
      }
    }

    return const [];
  }

  List<dynamic> _firstListFromKeys(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    // Reads the first list from a flat map.
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
    }

    return const [];
  }

  String _firstStringFromKeys(Map<String, dynamic> source, List<String> keys) {
    // Reads the first non-empty string or number from a flat map.
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }

    return '';
  }

  int _firstIntFromKeys(Map<String, dynamic> source, List<String> keys) {
    // Reads the first integer-like value from a flat map.
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }

    return 0;
  }

  double _firstDoubleFromKeys(Map<String, dynamic> source, List<String> keys) {
    // Reads the first decimal-like value from a flat map.
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }

    return 0;
  }

  Object? _valueAtPath(Map<String, dynamic> source, List<String> path) {
    // Safely reads nested JSON values.
    Object? current = source;

    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }

    return current;
  }

  void _toggleProduct(ProductCardData selectedProduct) {
    if (selectedProduct.availableQuantity == 0) return;

    // Updates only the tapped product while preserving the other rows.
    setState(() {
      _products = _products.map((product) {
        if (product != selectedProduct) return product;

        return product.copyWith(isSelected: !product.isSelected);
      }).toList();
    });
  }

  void _changeQuantity(ProductCardData selectedProduct, int change) {
    // Quantity cannot go below 1 for available products, and it cannot go above
    // availableQuantity because the backend says that is all that is available.
    setState(() {
      _products = _products.map((product) {
        if (product != selectedProduct) return product;

        final nextQuantity = (product.quantity + change)
            .clamp(
              product.availableQuantity > 0 ? 1 : 0,
              product.availableQuantity,
            )
            .toInt();

        return product.copyWith(quantity: nextQuantity);
      }).toList();
    });
  }

  Future<void> _submitOrder() async {
    final selectedProducts = _products
        .where((product) => product.isSelected)
        .toList();

    if (selectedProducts.isEmpty) return;

    // Submit Order opens the payment collection step. Only selected products
    // are passed forward, so PaymentCollectionPage receives an exact snapshot
    // of the order lines and quantities chosen by the driver.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentCollectionPage(
          customer: widget.customer,
          selectedProducts: selectedProducts,
        ),
      ),
    );

    // If the user returns here after payment/completion, fetch products again.
    // Any real stock deduction should already have happened on the backend,
    // so this refresh picks up the backend's latest availableQuantity values.
    if (mounted) _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItemCount = _selectedItemCount;
    final subtotal = _subtotal;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const _ProductHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 38, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SelectedCustomerSummary(customer: widget.customer),
                        const SizedBox(height: 28),
                        _ProductListPanel(
                          products: _products,
                          isLoading: _isLoadingProducts,
                          errorMessage: _productErrorMessage,
                          onRetry: _fetchProducts,
                          onToggle: _toggleProduct,
                          onQuantityChanged: _changeQuantity,
                        ),
                      ],
                    ),
                  ),
                ),
                _ProductBottomBar(
                  selectedItemCount: selectedItemCount,
                  subtotal: subtotal,
                  isEnabled: selectedItemCount > 0,
                  onSubmit: _submitOrder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader();

  @override
  Widget build(BuildContext context) {
    // Fixed header with a back button and page title.
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        border: Border(bottom: BorderSide(color: Color(0xFFD8DCE3))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF003469),
              size: 30,
            ),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Select Products',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF003469),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCustomerSummary extends StatelessWidget {
  const _SelectedCustomerSummary({required this.customer});

  final CustomerCardData customer;

  @override
  Widget build(BuildContext context) {
    // Shows the customer that was selected on the dashboard.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          customer.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF020711),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          customer.address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF243348),
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ProductListPanel extends StatelessWidget {
  const _ProductListPanel({
    required this.products,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onToggle,
    required this.onQuantityChanged,
  });

  final List<ProductCardData> products;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<ProductCardData> onToggle;
  final void Function(ProductCardData product, int change) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ProductSkeletonList();
    }

    if (errorMessage != null) {
      return _ProductPanelShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFF26364D),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return const _ProductPanelShell(
        child: Text(
          'No products found.',
          style: TextStyle(
            color: Color(0xFF26364D),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < products.length; index++) ...[
          _ProductCard(
            product: products[index],
            onToggle: () => onToggle(products[index]),
            onDecrease: () => onQuantityChanged(products[index], -1),
            onIncrease: () => onQuantityChanged(products[index], 1),
          ),
          if (index != products.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onToggle,
    required this.onDecrease,
    required this.onIncrease,
  });

  final ProductCardData product;
  final VoidCallback onToggle;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.availableQuantity == 0;
    final canDecrease = !isOutOfStock && product.quantity > 1;
    final canIncrease =
        !isOutOfStock && product.quantity < product.availableQuantity;

    return _ProductPanelShell(
      backgroundColor: isOutOfStock ? const Color(0xFFE4E4E4) : Colors.white,
      borderColor: isOutOfStock
          ? const Color(0xFFE4E4E4)
          : const Color(0xFFD2D7E0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductCheckbox(
                isSelected: product.isSelected,
                isEnabled: !isOutOfStock,
                onTap: onToggle,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOutOfStock
                        ? const Color(0xFF969A9D)
                        : const Color(0xFF003469),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            isOutOfStock
                ? 'Out of stock'
                : 'Available: ${product.availableQuantity}',
            style: TextStyle(
              color: isOutOfStock
                  ? const Color(0xFF969A9D)
                  : const Color(0xFF243348),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _ReadOnlyValueField(
                  label: 'Unit Price',
                  value: product.unitPrice.toStringAsFixed(2),
                  isDisabled: isOutOfStock,
                ),
              ),
              const SizedBox(width: 20),
              _QuantityStepper(
                quantity: product.quantity,
                canDecrease: canDecrease,
                canIncrease: canIncrease,
                isDisabled: isOutOfStock,
                onDecrease: onDecrease,
                onIncrease: onIncrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCheckbox extends StatelessWidget {
  const _ProductCheckbox({
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06376F)
              : (isEnabled ? Colors.white : const Color(0xFFE4E4E4)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isEnabled
                ? (isSelected
                      ? const Color(0xFF06376F)
                      : const Color(0xFF9AA3B2))
                : const Color(0xFFB9B9B9),
            width: 1.2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

class _ReadOnlyValueField extends StatelessWidget {
  const _ReadOnlyValueField({
    required this.label,
    required this.value,
    required this.isDisabled,
  });

  final String label;
  final String value;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDisabled
                ? const Color(0xFF969A9D)
                : const Color(0xFF243348),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDisabled ? const Color(0xFFDCDCDC) : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isDisabled
                  ? const Color(0xFFC9C9C9)
                  : const Color(0xFFD2D7E0),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: isDisabled
                  ? const Color(0xFF969A9D)
                  : const Color(0xFF020711),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.isDisabled,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final bool isDisabled;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 194,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Quantity',
            style: TextStyle(
              color: isDisabled
                  ? const Color(0xFF969A9D)
                  : const Color(0xFF243348),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDisabled ? const Color(0xFFDCDCDC) : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDisabled
                    ? const Color(0xFFC9C9C9)
                    : const Color(0xFFD2D7E0),
              ),
            ),
            child: Row(
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  isEnabled: canDecrease,
                  onTap: onDecrease,
                ),
                Container(
                  width: 1,
                  color: isDisabled
                      ? const Color(0xFFC9C9C9)
                      : const Color(0xFFD2D7E0),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      quantity.toString(),
                      style: TextStyle(
                        color: isDisabled
                            ? const Color(0xFF969A9D)
                            : const Color(0xFF020711),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: isDisabled
                      ? const Color(0xFFC9C9C9)
                      : const Color(0xFFD2D7E0),
                ),
                _StepperButton(
                  icon: Icons.add,
                  isEnabled: canIncrease,
                  onTap: onIncrease,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 52,
      child: IconButton(
        onPressed: isEnabled ? onTap : null,
        icon: Icon(icon, size: 26),
        color: const Color(0xFF020711),
        disabledColor: const Color(0xFFB3BBC8),
        tooltip: icon == Icons.add ? 'Increase quantity' : 'Decrease quantity',
      ),
    );
  }
}

class _ProductPanelShell extends StatelessWidget {
  const _ProductPanelShell({
    required this.child,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFD2D7E0),
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _ProductSkeletonList extends StatefulWidget {
  const _ProductSkeletonList();

  @override
  State<_ProductSkeletonList> createState() => _ProductSkeletonListState();
}

class _ProductSkeletonListState extends State<_ProductSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Column(
            children: const [
              _ProductSkeletonCard(),
              SizedBox(height: 20),
              _ProductSkeletonCard(),
              SizedBox(height: 20),
              _ProductSkeletonCard(),
            ],
          ),
        );
      },
    );
  }
}

class _ProductSkeletonCard extends StatelessWidget {
  const _ProductSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return _ProductPanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Row(
            children: [
              _ProductSkeletonBox(width: 30, height: 30, radius: 6),
              SizedBox(width: 16),
              Expanded(child: _ProductSkeletonBox(height: 26, radius: 6)),
            ],
          ),
          SizedBox(height: 22),
          _ProductSkeletonBox(height: 16, radius: 6),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ProductSkeletonBox(height: 52, radius: 5)),
              SizedBox(width: 20),
              _ProductSkeletonBox(width: 194, height: 52, radius: 5),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductSkeletonBox extends StatelessWidget {
  const _ProductSkeletonBox({
    required this.height,
    required this.radius,
    this.width,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD2D7E0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ProductBottomBar extends StatelessWidget {
  const _ProductBottomBar({
    required this.selectedItemCount,
    required this.subtotal,
    required this.isEnabled,
    required this.onSubmit,
  });

  final int selectedItemCount;
  final double subtotal;
  final bool isEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 18, 32, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        border: Border(top: BorderSide(color: Color(0xFFE1E4EA))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$selectedItemCount items selected',
                    style: const TextStyle(
                      color: Color(0xFF243348),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Subtotal: \$${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF003469),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              width: double.infinity,
              child: FilledButton(
                onPressed: isEnabled ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF06376F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Submit Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward, size: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
