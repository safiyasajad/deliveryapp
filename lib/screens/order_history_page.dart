import 'package:flutter/material.dart';

// Order history screen shown from the completed-delivery receipt flow.
//
// This page currently uses sample delivered orders because no backend order
// history endpoint is wired into the app yet. When that API is available, the
// `_orders` list should be replaced with fetched response data and the filter
// chips/search input can be sent to the backend as query parameters.
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All Time';
  String _searchText = '';

  static final List<_OrderHistoryData> _orders = [
    _OrderHistoryData(
      orderId: '#LP-9920-X1',
      customerName: 'Sarah Jenkins',
      dateTime: DateTime(2023, 10, 24, 14, 15),
      total: 374.50,
    ),
    _OrderHistoryData(
      orderId: '#LP-9915-K4',
      customerName: 'Michael Chen',
      dateTime: DateTime(2023, 10, 24, 11, 42),
      total: 1250.00,
    ),
    _OrderHistoryData(
      orderId: '#LP-9882-B2',
      customerName: 'Elena Rodriguez',
      dateTime: DateTime(2023, 10, 23, 17, 08),
      total: 89.20,
    ),
    _OrderHistoryData(
      orderId: '#LP-9870-W3',
      customerName: 'David Wilson',
      dateTime: DateTime(2023, 10, 23, 13, 22),
      total: 215.15,
    ),
  ];

  List<_OrderHistoryData> get _filteredOrders {
    final query = _searchText.trim().toLowerCase();

    return _orders.where((order) {
      final matchesSearch =
          query.isEmpty ||
          order.orderId.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      final now = DateTime.now();
      return switch (_selectedFilter) {
        'This Month' =>
          order.dateTime.year == now.year && order.dateTime.month == now.month,
        'Last 7 Days' => now.difference(order.dateTime).inDays <= 7,
        _ => true,
      };
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const _OrderHistoryHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HistorySearchField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchText = value);
                          },
                        ),
                        const SizedBox(height: 24),
                        _HistoryFilterBar(
                          selectedFilter: _selectedFilter,
                          onSelected: (filter) {
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                        const SizedBox(height: 34),
                        if (filteredOrders.isEmpty)
                          const _EmptyHistoryMessage()
                        else
                          for (
                            var index = 0;
                            index < filteredOrders.length;
                            index++
                          ) ...[
                            _OrderHistoryCard(order: filteredOrders[index]),
                            if (index != filteredOrders.length - 1)
                              const SizedBox(height: 20),
                          ],
                      ],
                    ),
                  ),
                ),
                const _OrderHistoryBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderHistoryData {
  const _OrderHistoryData({
    required this.orderId,
    required this.customerName,
    required this.dateTime,
    required this.total,
    this.status = 'DELIVERED',
  });

  final String orderId;
  final String customerName;
  final DateTime dateTime;
  final double total;
  final String status;
}

class _OrderHistoryHeader extends StatelessWidget {
  const _OrderHistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 30),
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
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Order History',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF003469),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Profile is not available yet.'),
                  ),
                );
            },
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Color(0xFF003469),
              size: 30,
            ),
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  const _HistorySearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        color: Color(0xFF243348),
        fontSize: 20,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: 'Search by Order ID or Customer',
        hintStyle: const TextStyle(
          color: Color(0xFF687386),
          fontSize: 20,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF687386),
          size: 30,
        ),
        filled: true,
        fillColor: const Color(0xFFF6F4F4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD2D7E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF003469), width: 1.4),
        ),
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final String selectedFilter;
  final ValueChanged<String> onSelected;

  static const filters = ['All Time', 'This Month', 'Last 7 Days', 'Custom'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _HistoryFilterChip(
              label: filter,
              isSelected: selectedFilter == filter,
              onTap: () => onSelected(filter),
            ),
            if (filter != filters.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF003469) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF003469)
                  : const Color(0xFFD2D7E0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF3D4554),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order});

  final _OrderHistoryData order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2D7E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.orderId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF003469),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            order.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF243348),
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OrderMetaBlock(
                  label: 'DATE & TIME',
                  value: _formatOrderDateTime(order.dateTime),
                  alignment: CrossAxisAlignment.start,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(width: 18),
              _OrderMetaBlock(
                label: 'TOTAL',
                value: _formatMoney(order.total),
                alignment: CrossAxisAlignment.end,
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text('Receipt for ${order.orderId}')),
                  );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF003469),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Receipt',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (match) => '${match[1]},',
        );
  }

  String _formatOrderDateTime(DateTime dateTime) {
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
    final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month ${dateTime.day}, ${dateTime.year} - $hour12:$minute $period';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFD9FBE6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Color(0xFF007A3D),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _OrderMetaBlock extends StatelessWidget {
  const _OrderMetaBlock({
    required this.label,
    required this.value,
    required this.alignment,
    required this.textAlign,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: const TextStyle(
            color: Color(0xFF243348),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(
            color: Color(0xFF003469),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _EmptyHistoryMessage extends StatelessWidget {
  const _EmptyHistoryMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2D7E0)),
      ),
      child: const Text(
        'No orders found.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF243348),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OrderHistoryBottomNav extends StatelessWidget {
  const _OrderHistoryBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        border: Border(top: BorderSide(color: Color(0xFFE1E4EA))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: Icons.local_shipping_outlined,
              label: 'Deliveries',
              onTap: () => Navigator.of(context).pop(),
            ),
            const _BottomNavItem(
              icon: Icons.history,
              label: 'History',
              isSelected: true,
            ),
            _BottomNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Profile is not available yet.'),
                    ),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 92,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD7E4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF003469), size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF020711),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
