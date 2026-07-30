import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'view_recipt_page.dart';

// Order history screen shown from the completed-delivery receipt flow.
//
// This page fetches order rows from:
// /orders/list?offset=1&limit=15&search=&sortBy=orderNumber&order=desc
//
// The endpoint is expected to return the order-management table data. Parsing
// is intentionally flexible because backend response wrappers and field names
// can vary between environments.
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({
    super.key,
    required this.accessToken,
    this.dashboardCustomerId = '',
  });

  // JWT from login. The order list endpoint is called with
  // Authorization: Bearer <token>, matching the customer/product screens.
  final String accessToken;

  // Customer selected on the delivery dashboard. This is only used as a
  // fallback id when an order row does not include its own customer id, so the
  // receipt page can fetch the customer's saved address.
  final String dashboardCustomerId;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  static const int _orderPageSize = 15;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<_OrderHistoryData> _orders = const [];
  bool _isLoadingOrders = false;
  String? _orderErrorMessage;

  String _selectedFilter = 'All Time';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  List<_OrderHistoryData> get _filteredOrders {
    return _orders.where((order) {
      final now = DateTime.now();
      return switch (_selectedFilter) {
        'This Month' =>
          order.dateTime.year == now.year && order.dateTime.month == now.month,
        'Last 7 Days' => now.difference(order.dateTime).inDays <= 7,
        _ => true,
      };
    }).toList();
  }

  Future<void> _fetchOrders() async {
    final apiBaseUrl = dotenv.env['API_BASE_URL'];

    if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
      setState(() {
        _orderErrorMessage = 'API base URL is missing from .env.';
      });
      return;
    }

    setState(() {
      _isLoadingOrders = true;
      _orderErrorMessage = null;
    });

    try {
      if (widget.accessToken.isEmpty) {
        throw Exception(
          'Login token missing. Please log out and log in again.',
        );
      }

      final uri = Uri.parse(apiBaseUrl).replace(
        path: '/orders/list',
        queryParameters: {
          'offset': '1',
          'limit': _orderPageSize.toString(),
          'search': _searchText.trim(),
          'sortBy': 'orderNumber',
          'order': 'desc',
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
          'Order history request failed with status ${response.statusCode}.',
        );
      }

      final responseBody = _decodeResponseBody(response.body);
      final orders = _parseOrders(responseBody);

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoadingOrders = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _orders = const [];
        _isLoadingOrders = false;
        _orderErrorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.isEmpty) return const {};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'data': decoded};

    return const {};
  }

  List<_OrderHistoryData> _parseOrders(Map<String, dynamic> responseBody) {
    final rawOrders = _firstListFromPaths(responseBody, const [
      ['data'],
      ['orders'],
      ['order'],
      ['items'],
      ['rows'],
      ['result'],
      ['result', 'orders'],
      ['result', 'items'],
      ['result', 'rows'],
      ['data', 'orders'],
      ['data', 'items'],
      ['data', 'rows'],
      ['data', 'result'],
    ]);

    return rawOrders
        .whereType<Map<String, dynamic>>()
        .map(_orderFromJson)
        .where((order) => order.orderId.isNotEmpty)
        .toList();
  }

  _OrderHistoryData _orderFromJson(Map<String, dynamic> json) {
    final orderId = _firstStringFromKeys(json, const [
      'orderNumber',
      'order_number',
      'orderNo',
      'order_no',
      'number',
      'code',
      'id',
      '_id',
    ]);

    var customerName = _firstStringFromKeys(json, const [
      'customerName',
      'customer_name',
      'clientName',
      'client_name',
      'name',
    ]);

    var customerId = _firstStringFromKeys(json, const [
      'customerId',
      'customer_id',
      'customerID',
      'clientId',
      'client_id',
    ]);

    if (customerName.isEmpty) {
      customerName = _firstStringFromNestedMap(
        json,
        const ['customer', 'customerDetails', 'customer_details', 'client'],
        const [
          'name',
          'fullName',
          'full_name',
          'customerName',
          'customer_name',
          'companyName',
          'company_name',
        ],
      );
    }

    if (customerId.isEmpty) {
      customerId = _firstStringFromNestedMap(
        json,
        const ['customer', 'customerDetails', 'customer_details', 'client'],
        const ['id', '_id', 'customerId', 'customer_id', 'uuid'],
      );
    }

    final dateText = _firstStringFromKeys(json, const [
      'dateTime',
      'date_time',
      'orderDate',
      'order_date',
      'createdAt',
      'created_at',
      'completedAt',
      'completed_at',
      'deliveredAt',
      'delivered_at',
      'updatedAt',
      'updated_at',
    ]);

    final status = _firstStringFromKeys(json, const [
      'status',
      'orderStatus',
      'order_status',
      'deliveryStatus',
      'delivery_status',
    ]);

    final addressLine = _firstStringFromKeys(json, const [
      'address',
      'deliveryAddress',
      'delivery_address',
      'customerAddress',
      'customer_address',
      'addressLine1',
      'address_line_1',
      'street',
    ]);

    final nestedAddressLine = _firstStringFromNestedMap(
      json,
      const ['customer', 'customerDetails', 'customer_details', 'client'],
      const [
        'address',
        'fullAddress',
        'full_address',
        'deliveryAddress',
        'delivery_address',
        'customerAddress',
        'customer_address',
        'addressLine1',
        'address_line_1',
        'street',
      ],
    );

    final addressCity = _firstStringFromKeys(json, const [
      'city',
      'state',
      'province',
      'postalCode',
      'postal_code',
      'zip',
    ]);

    final nestedAddressCity = _firstStringFromNestedMap(
      json,
      const ['customer', 'customerDetails', 'customer_details', 'client'],
      const ['city', 'state', 'province', 'postalCode', 'postal_code', 'zip'],
    );

    final paymentMethod = _firstStringFromKeys(json, const [
      'paymentMethod',
      'payment_method',
      'paymentType',
      'payment_type',
      'method',
    ]);

    final transactionId = _firstStringFromKeys(json, const [
      'transactionId',
      'transaction_id',
      'paymentTransactionId',
      'payment_transaction_id',
      'referenceNo',
      'reference_no',
    ]);

    final total = _firstDoubleFromKeys(json, const [
      'total',
      'totalAmount',
      'total_amount',
      'orderTotal',
      'order_total',
      'grandTotal',
      'grand_total',
      'netAmount',
      'net_amount',
      'amount',
    ]);

    return _OrderHistoryData(
      orderId: orderId,
      customerId: customerId,
      customerName: customerName.isEmpty ? 'Unknown Customer' : customerName,
      dateTime: _parseDateTime(dateText),
      total: total,
      status: status.isEmpty ? 'DELIVERED' : status.toUpperCase(),
      addressLine: _firstNonEmptyString(
        addressLine,
        nestedAddressLine,
        'No address available',
      ),
      addressCity: _firstNonEmptyString(addressCity, nestedAddressCity),
      paymentMethod: paymentMethod.isEmpty ? 'Cash' : paymentMethod,
      transactionId: transactionId.isEmpty ? 'Not available' : transactionId,
      items: _parseDeliveredItems(json, total),
    );
  }

  List<OrderDetailsItem> _parseDeliveredItems(
    Map<String, dynamic> json,
    double orderTotal,
  ) {
    final rawItems = _firstListFromPaths(json, const [
      ['products'],
      ['items'],
      ['orderItems'],
      ['order_items'],
      ['orderProducts'],
      ['order_products'],
      ['details'],
      ['data', 'products'],
      ['data', 'items'],
      ['data', 'orderItems'],
    ]);

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(_deliveredItemFromJson)
        .where((item) => item.name.isNotEmpty)
        .toList();

    if (items.isNotEmpty) return items;

    return [
      OrderDetailsItem(
        name: 'Delivered Items',
        quantity: 1,
        unitPrice: orderTotal,
        lineTotal: orderTotal,
      ),
    ];
  }

  OrderDetailsItem _deliveredItemFromJson(Map<String, dynamic> json) {
    var name = _firstStringFromKeys(json, const [
      'name',
      'productName',
      'product_name',
      'itemName',
      'item_name',
      'title',
      'description',
    ]);

    if (name.isEmpty) {
      name = _firstStringFromNestedMap(
        json,
        const ['product', 'item'],
        const ['name', 'productName', 'product_name', 'title'],
      );
    }

    final quantity = _firstIntFromKeys(json, const [
      'quantity',
      'qty',
      'selectedQuantity',
      'selected_quantity',
      'deliveredQuantity',
      'delivered_quantity',
    ]);

    final unitPrice = _firstDoubleFromKeys(json, const [
      'unitPrice',
      'unit_price',
      'price',
      'sellingPrice',
      'selling_price',
      'rate',
    ]);

    final parsedLineTotal = _firstDoubleFromKeys(json, const [
      'lineTotal',
      'line_total',
      'total',
      'totalAmount',
      'total_amount',
      'amount',
    ]);
    final lineTotal = parsedLineTotal > 0
        ? parsedLineTotal
        : (quantity * unitPrice);

    return OrderDetailsItem(
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
    );
  }

  List<dynamic> _firstListFromPaths(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = _valueAtPath(source, path);
      if (value is List) return value;

      if (value is Map<String, dynamic>) {
        final nestedList = _firstListFromKeys(value, const [
          'orders',
          'order',
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
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
    }

    return const [];
  }

  String _firstStringFromKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }

    return '';
  }

  String _firstStringFromNestedMap(
    Map<String, dynamic> source,
    List<String> mapKeys,
    List<String> valueKeys,
  ) {
    for (final mapKey in mapKeys) {
      final value = source[mapKey];
      if (value is Map<String, dynamic>) {
        final nestedValue = _firstStringFromKeys(value, valueKeys);
        if (nestedValue.isNotEmpty) return nestedValue;
      }
    }

    return '';
  }

  String _firstNonEmptyString(
    String first,
    String second, [
    String fallback = '',
  ]) {
    if (first.isNotEmpty) return first;
    if (second.isNotEmpty) return second;
    return fallback;
  }

  double _firstDoubleFromKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim().replaceAll(',', ''));
        if (parsed != null) return parsed;
      }
    }

    return 0;
  }

  int _firstIntFromKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }

    return 1;
  }

  Object? _valueAtPath(Map<String, dynamic> source, List<String> path) {
    Object? current = source;

    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }

    return current;
  }

  DateTime _parseDateTime(String value) {
    if (value.isEmpty) return DateTime.now();

    return DateTime.tryParse(value) ?? DateTime.now();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();

    setState(() => _searchText = value);

    _searchDebounce = Timer(const Duration(milliseconds: 450), _fetchOrders);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
                          onChanged: _scheduleSearch,
                        ),
                        const SizedBox(height: 24),
                        _HistoryFilterBar(
                          selectedFilter: _selectedFilter,
                          onSelected: (filter) {
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                        const SizedBox(height: 34),
                        if (_isLoadingOrders)
                          const _OrderHistoryLoadingList()
                        else if (_orderErrorMessage != null)
                          _OrderHistoryErrorMessage(
                            message: _orderErrorMessage!,
                            onRetry: _fetchOrders,
                          )
                        else if (filteredOrders.isEmpty)
                          const _EmptyHistoryMessage()
                        else
                          for (
                            var index = 0;
                            index < filteredOrders.length;
                            index++
                          ) ...[
                            _OrderHistoryCard(
                              order: filteredOrders[index],
                              accessToken: widget.accessToken,
                              dashboardCustomerId: widget.dashboardCustomerId,
                            ),
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
    required this.customerId,
    required this.customerName,
    required this.dateTime,
    required this.total,
    required this.addressLine,
    required this.addressCity,
    required this.paymentMethod,
    required this.transactionId,
    required this.items,
    this.status = 'DELIVERED',
  });

  final String orderId;
  final String customerId;
  final String customerName;
  final DateTime dateTime;
  final double total;
  final String status;
  final String addressLine;
  final String addressCity;
  final String paymentMethod;
  final String transactionId;
  final List<OrderDetailsItem> items;

  _OrderHistoryData copyWith({
    String? orderId,
    String? customerId,
    String? customerName,
    DateTime? dateTime,
    double? total,
    String? status,
    String? addressLine,
    String? addressCity,
    String? paymentMethod,
    String? transactionId,
    List<OrderDetailsItem>? items,
  }) {
    return _OrderHistoryData(
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      dateTime: dateTime ?? this.dateTime,
      total: total ?? this.total,
      status: status ?? this.status,
      addressLine: addressLine ?? this.addressLine,
      addressCity: addressCity ?? this.addressCity,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      items: items ?? this.items,
    );
  }
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
  const _OrderHistoryCard({
    required this.order,
    required this.accessToken,
    required this.dashboardCustomerId,
  });

  final _OrderHistoryData order;
  final String accessToken;
  final String dashboardCustomerId;

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
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => OrderDetailsPage(
                      order: OrderDetailsData(
                        orderId: order.orderId,
                        customerId: order.customerId.isEmpty
                            ? dashboardCustomerId
                            : order.customerId,
                        accessToken: accessToken,
                        customerName: order.customerName,
                        dateTime: order.dateTime,
                        status: order.status,
                        addressLine: order.addressLine,
                        addressCity: order.addressCity,
                        items: order.items,
                        total: order.total,
                        paymentMethod: order.paymentMethod,
                        transactionId: order.transactionId,
                      ),
                    ),
                  ),
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

class _OrderHistoryErrorMessage extends StatelessWidget {
  const _OrderHistoryErrorMessage({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2D7E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF243348),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OrderHistoryLoadingList extends StatelessWidget {
  const _OrderHistoryLoadingList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _OrderHistorySkeletonCard(),
        SizedBox(height: 20),
        _OrderHistorySkeletonCard(),
        SizedBox(height: 20),
        _OrderHistorySkeletonCard(),
      ],
    );
  }
}

class _OrderHistorySkeletonCard extends StatelessWidget {
  const _OrderHistorySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2D7E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Row(
            children: [
              Expanded(child: _HistorySkeletonBlock(height: 26)),
              SizedBox(width: 80),
              _HistorySkeletonBlock(width: 118, height: 32),
            ],
          ),
          SizedBox(height: 16),
          _HistorySkeletonBlock(width: 180, height: 20),
          SizedBox(height: 24),
          Divider(height: 1, color: Color(0xFFE5E7EB)),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _HistorySkeletonBlock(height: 42)),
              SizedBox(width: 80),
              _HistorySkeletonBlock(width: 92, height: 42),
            ],
          ),
          SizedBox(height: 28),
          _HistorySkeletonBlock(width: 140, height: 22),
        ],
      ),
    );
  }
}

class _HistorySkeletonBlock extends StatelessWidget {
  const _HistorySkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFD2D7E0),
        borderRadius: BorderRadius.circular(8),
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
