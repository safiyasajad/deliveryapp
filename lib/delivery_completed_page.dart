import 'package:flutter/material.dart';

import 'customer_card_data.dart';

class DeliveryCompletedPage extends StatelessWidget {
  const DeliveryCompletedPage({
    super.key,
    required this.customer,
    required this.orderTotal,
    required this.amountPaid,
    required this.completedAt,
    this.orderId = '#LP-9920-X1',
  });

  final CustomerCardData customer;
  final double orderTotal;
  final double amountPaid;
  final DateTime completedAt;
  final String orderId;

  double get _remainingBalance {
    if (_hasOverpayment) return amountPaid - orderTotal;
    return orderTotal - amountPaid;
  }

  bool get _hasOverpayment {
    return amountPaid > orderTotal;
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
                          onViewHistory: () => _showHistoryPlaceholder(context),
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
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    if (navigator.canPop()) navigator.pop();
  }

  void _showHistoryPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Order history is not available yet.')),
      );
  }
}

class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
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
