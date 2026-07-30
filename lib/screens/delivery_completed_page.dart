import 'package:flutter/material.dart';

import '../customer_card_data.dart';
import 'order_history_page.dart';

// Final confirmation screen shown after the delivery user taps
// "Complete Delivery" on PaymentCollectionPage.
//
// This page is presentation-only. It does not update inventory or save the
// order to the backend. When the backend completion endpoint is added,
// PaymentCollectionPage should call that endpoint first, then pass the backend
// response values into this page.
class DeliveryCompletedPage extends StatelessWidget {
  const DeliveryCompletedPage({
    super.key,
    required this.customer,
    required this.orderTotal,
    required this.amountPaid,
    required this.completedAt,
    required this.accessToken,
    this.orderId = '#LP-9920-X1',
  });

  // Customer that was selected at the start of the delivery flow.
  final CustomerCardData customer;

  // Total value of the selected products: unit price multiplied by quantity.
  final double orderTotal;

  // Amount collected from the customer. An empty payment input is parsed as 0.
  final double amountPaid;

  // Time when the user completed the delivery in the app.
  final DateTime completedAt;

  // JWT from login, forwarded so the order-history page can call the protected
  // backend order list endpoint.
  final String accessToken;

  // Temporary display id until real order ids are returned by the backend.
  final String orderId;

  // Shows normal remaining balance for underpayment. If the driver collected
  // more than the total, this becomes the positive overpaid/change amount.
  double get _remainingBalance {
    if (_hasOverpayment) return amountPaid - orderTotal;
    return orderTotal - amountPaid;
  }

  // Used by the summary table to style overpaid values in blue and prefix them
  // with a plus sign.
  bool get _hasOverpayment {
    return amountPaid > orderTotal;
  }

  @override
  Widget build(BuildContext context) {
    // The page follows the same mobile-first shell as the other screens:
    // cream background, SafeArea, centered max-width content, fixed header, and
    // a scrollable body so the summary/actions fit on smaller devices.
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _CompletedHeader(customerName: customer.name),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 86, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SuccessMark(),
                        const SizedBox(height: 62),
                        const Text(
                          'Delivery Completed!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF003469),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'The order has been successfully delivered off\n'
                          'and confirmed by the customer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF243348),
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            height: 1.42,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _SummaryCard(
                          customerName: customer.name,
                          orderId: orderId,
                          orderTotal: orderTotal,
                          amountPaid: amountPaid,
                          remainingBalance: _remainingBalance,
                          hasOverpayment: _hasOverpayment,
                          completedAt: completedAt,
                        ),
                        const SizedBox(height: 60),
                        _CompletionActions(
                          onStartNewDelivery: () => _startNewDelivery(context),
                          onViewHistory: () => _openOrderHistory(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startNewDelivery(BuildContext context) {
    // PaymentCollectionPage opened this screen with pushReplacement(), so the
    // navigator stack is usually: dashboard -> product selection -> completed.
    // Popping twice returns the user to the dashboard to start another delivery.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    if (navigator.canPop()) navigator.pop();
  }

  void _openOrderHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderHistoryPage(
          accessToken: accessToken,
          dashboardCustomerId: customer.id,
        ),
      ),
    );
  }
}

class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
    // Header mirrors the reference design: no back button, just the customer
    // name centered above a subtle bottom divider.
    return Container(
      height: 74,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        border: Border(bottom: BorderSide(color: Color(0xFFD8DCE3))),
      ),
      child: Text(
        customerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF003469),
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    // The success badge is built with nested circles and a Material check icon
    // so it scales crisply without an image asset.
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: const BoxDecoration(
          color: Color(0xFFFF8708),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF5A3100),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFFFF8708), size: 70),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.customerName,
    required this.orderId,
    required this.orderTotal,
    required this.amountPaid,
    required this.remainingBalance,
    required this.hasOverpayment,
    required this.completedAt,
  });

  final String customerName;
  final String orderId;
  final double orderTotal;
  final double amountPaid;
  final double remainingBalance;
  final bool hasOverpayment;
  final DateTime completedAt;

  @override
  Widget build(BuildContext context) {
    // Summary card is a table-like column: header band, divider, then repeated
    // rows with a left label and right-aligned value.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2D7E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 66,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            color: const Color(0xFFFDFCFB),
            child: const Text(
              'SUMMARY',
              style: TextStyle(
                color: Color(0xFF243348),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD8DCE3)),
          _SummaryRow(label: 'Customer', value: customerName),
          _SummaryRow(label: 'Order ID', value: orderId),
          _SummaryRow(
            label: 'Total Order Amount',
            value: orderTotal.toStringAsFixed(2),
          ),
          _SummaryRow(
            label: 'Amount Paid Today',
            value: amountPaid.toStringAsFixed(2),
          ),
          _SummaryRow(
            label: 'Remaining Balance',
            value: hasOverpayment
                ? '+${remainingBalance.toStringAsFixed(2)}'
                : remainingBalance.toStringAsFixed(2),
            valueColor: hasOverpayment ? const Color(0xFF006FC9) : null,
          ),
          _SummaryRow(label: 'Timestamp', value: _formatTimestamp(completedAt)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    // Manual month formatting keeps the app free from an extra intl dependency.
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$month ${dateTime.day}, ${dateTime.year} - $hour:$minute';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    // Flexible right-side value prevents long customer names or timestamps from
    // overflowing on narrow phones; extra text is ellipsized.
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD8DCE3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF243348),
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF020711),
                fontSize: 20,
                fontWeight: valueColor == null
                    ? FontWeight.w400
                    : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionActions extends StatelessWidget {
  const _CompletionActions({
    required this.onStartNewDelivery,
    required this.onViewHistory,
  });

  final VoidCallback onStartNewDelivery;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    // Bottom actions are part of the scrollable content instead of a fixed
    // bottom bar because the completed screen is mostly a receipt/summary view.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: onStartNewDelivery,
            icon: const Icon(Icons.local_shipping_outlined, size: 26),
            label: const Text(
              'Start New Delivery',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF06376F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 72,
          child: OutlinedButton(
            onPressed: onViewHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF003469),
              side: const BorderSide(color: Color(0xFF06376F), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'View Order History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }
}
