import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../customer_card_data.dart';
import '../product_card_data.dart';
import 'delivery_completed_page.dart';

// PaymentCollectionPage is opened after ProductSelectionPage.
//
// Responsibilities:
// - Show the selected product rows as an order summary.
// - Calculate the total, paid amount, and remaining balance in the frontend.
// - Allow completing delivery even when the paid amount is 0 or less than the
//   total, because partial/unpaid deliveries are allowed.
// - Navigate to DeliveryCompletedPage with the locally calculated summary.
//
// Important backend note:
// This page currently does not deduct product inventory. Once the backend has a
// delivery-completion endpoint, _completeDelivery() should call it. The product
// list will then show reduced stock naturally because ProductSelectionPage
// fetches availableQuantity from the backend.
class PaymentCollectionPage extends StatefulWidget {
  const PaymentCollectionPage({
    super.key,
    required this.customer,
    required this.selectedProducts,
    required this.accessToken,
  });

  final CustomerCardData customer;
  final List<ProductCardData> selectedProducts;
  final String accessToken;

  @override
  State<PaymentCollectionPage> createState() => _PaymentCollectionPageState();
}

class _PaymentCollectionPageState extends State<PaymentCollectionPage> {
  final _paymentAmountController = TextEditingController();

  // Prevents accidental double taps from opening two completed screens or
  // later calling a backend completion endpoint twice.
  bool _hasCompletedDelivery = false;

  double get _orderTotal {
    // Total is calculated from selected products only. Each row contributes
    // unit price multiplied by the quantity chosen on ProductSelectionPage.
    return widget.selectedProducts.fold<double>(
      0,
      (total, product) => total + (product.unitPrice * product.quantity),
    );
  }

  double get _paymentAmount {
    // Empty or invalid input is treated as 0. This matches the requested
    // behavior: leaving Payment Amount blank should still allow completion.
    return double.tryParse(_paymentAmountController.text.trim()) ?? 0;
  }

  double get _remainingBalance {
    // The payment page shows only unpaid balance. If the user overpays, the
    // displayed balance is clamped to 0 here; DeliveryCompletedPage shows the
    // overpaid amount as a positive blue value in the final summary.
    final remaining = _orderTotal - _paymentAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _canCompleteDelivery {
    // Completion is allowed for any payment amount, including blank/0.
    // The only requirement is that there is an order to complete.
    return widget.selectedProducts.isNotEmpty;
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    super.dispose();
  }

  void _completeDelivery() {
    if (_hasCompletedDelivery) return;
    _hasCompletedDelivery = true;

    // Placeholder until the backend complete-delivery/status endpoint is known.
    // For now, open the completed screen with the local order summary values.
    // Do not modify product quantities here; stock should be updated by the
    // backend and reflected when products are fetched again.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => DeliveryCompletedPage(
          customer: widget.customer,
          orderTotal: _orderTotal,
          amountPaid: _paymentAmount,
          completedAt: DateTime.now(),
          accessToken: widget.accessToken,
        ),
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
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
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
