import 'package:flutter/material.dart';

import 'customer_card_data.dart';
import 'product_card_data.dart';

// PaymentCollectionPage is opened after products are selected.
// It shows the selected products as the order summary and lets the delivery
// user enter the amount collected from the customer.
class PaymentCollectionPage extends StatefulWidget {
  const PaymentCollectionPage({
    super.key,
    required this.customer,
    required this.selectedProducts,
  });

  final CustomerCardData customer;
  final List<ProductCardData> selectedProducts;

  @override
  State<PaymentCollectionPage> createState() => _PaymentCollectionPageState();
}

class _PaymentCollectionPageState extends State<PaymentCollectionPage> {
  final _paymentAmountController = TextEditingController();

  double get _orderTotal {
    return widget.selectedProducts.fold<double>(
      0,
      (total, product) => total + (product.unitPrice * product.quantity),
    );
  }

  double get _paymentAmount {
    return double.tryParse(_paymentAmountController.text.trim()) ?? 0;
  }

  double get _remainingBalance {
    final remaining = _orderTotal - _paymentAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _canCompleteDelivery {
    return widget.selectedProducts.isNotEmpty && _paymentAmount >= _orderTotal;
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    super.dispose();
  }

  void _completeDelivery() {
    // Placeholder until the backend complete-delivery/status endpoint is known.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Delivery completed for ${widget.customer.name}'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _PaymentHeader(customerName: widget.customer.name),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrderSummaryCard(
                          products: widget.selectedProducts,
                          orderTotal: _orderTotal,
                        ),
                        const SizedBox(height: 30),
                        _PaymentAmountCard(
                          controller: _paymentAmountController,
                          remainingBalance: _remainingBalance,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
                _CompleteDeliveryBar(
                  isEnabled: _canCompleteDelivery,
                  onComplete: _completeDelivery,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Collect Payment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF003469),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF243348),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.products, required this.orderTotal});

  final List<ProductCardData> products;
  final double orderTotal;

  @override
  Widget build(BuildContext context) {
    return _PaymentPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 16, 22, 12),
            child: Text(
              'ORDER SUMMARY',
              style: TextStyle(
                color: Color(0xFF003469),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD8DCE3)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              children: [
                for (var index = 0; index < products.length; index++) ...[
                  _OrderSummaryLine(product: products[index]),
                  if (index != products.length - 1) const SizedBox(height: 22),
                ],
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFC7CDD7)),
                const SizedBox(height: 22),
                _BalanceLine(amount: orderTotal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryLine extends StatelessWidget {
  const _OrderSummaryLine({required this.product});

  final ProductCardData product;

  @override
  Widget build(BuildContext context) {
    final lineTotal = product.unitPrice * product.quantity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF020711),
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${product.quantity} x ${product.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF243348),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            lineTotal.toStringAsFixed(2),
            style: const TextStyle(
              color: Color(0xFF020711),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentAmountCard extends StatelessWidget {
  const _PaymentAmountCard({
    required this.controller,
    required this.remainingBalance,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double remainingBalance;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _PaymentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Payment Amount',
            style: TextStyle(
              color: Color(0xFF003469),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style: const TextStyle(
              color: Color(0xFF637184),
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 22,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF8E96A3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF003469),
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFD8DCE3),
                style: BorderStyle.solid,
              ),
            ),
            child: _BalanceLine(amount: remainingBalance),
          ),
        ],
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.payments_outlined, color: Color(0xFF995100), size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Remaining Balance',
            style: TextStyle(
              color: Color(0xFF243348),
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Color(0xFF995100),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD2D7E0)),
      ),
      child: child,
    );
  }
}

class _CompleteDeliveryBar extends StatelessWidget {
  const _CompleteDeliveryBar({
    required this.isEnabled,
    required this.onComplete,
  });

  final bool isEnabled;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        border: Border(top: BorderSide(color: Color(0xFFE1E4EA))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: FilledButton(
            onPressed: isEnabled ? onComplete : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF06376F),
              disabledBackgroundColor: const Color(0xFFE0E0E2),
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xFF9B9EA3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 28),
                SizedBox(width: 12),
                Text(
                  'Complete Delivery',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
