import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class OrderDetailsData {
  const OrderDetailsData({
    required this.orderId,
    required this.customerName,
    required this.dateTime,
    required this.status,
    required this.addressLine,
    required this.addressCity,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.transactionId,
    this.customerId = '',
    this.accessToken = '',
  });

  final String orderId;
  final String customerName;
  final DateTime dateTime;
  final String status;
  final String addressLine;
  final String addressCity;
  final List<OrderDetailsItem> items;
  final double total;
  final String paymentMethod;
  final String transactionId;
  final String customerId;
  final String accessToken;
}

class OrderDetailsItem {
  const OrderDetailsItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({super.key, required this.order});

  final OrderDetailsData order;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late String _addressLine;
  late String _addressCity;

  @override
  void initState() {
    super.initState();
    _addressLine = widget.order.addressLine;
    _addressCity = widget.order.addressCity;
    _fetchCustomerAddress();
  }

  Future<void> _fetchCustomerAddress() async {
    if (widget.order.customerId.isEmpty) return;

    final apiBaseUrl =
        dotenv.env['API_BASE_URL'] ?? 'https://qa-api.orderx.online';

    try {
      final uri = Uri.parse(apiBaseUrl).replace(
        path: '/customer_address/address-management',
        queryParameters: {'customerId': widget.order.customerId},
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (widget.order.accessToken.isNotEmpty)
            'Authorization': 'Bearer ${widget.order.accessToken}',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final responseBody = _decodeResponseBody(response.body);
      final fetchedAddress = _parseCustomerAddress(responseBody);
      if (fetchedAddress.isEmpty || !mounted) return;

      setState(() {
        _addressLine = fetchedAddress;
        _addressCity = '';
      });
    } catch (_) {
      // Keep the fallback address already passed from the order history page.
    }
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.isEmpty) return const {};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'data': decoded};

    return const {};
  }

  String _parseCustomerAddress(Map<String, dynamic> responseBody) {
    final rawAddresses = _firstListFromPaths(responseBody, const [
      ['data'],
      ['addresses'],
      ['address'],
      ['items'],
      ['rows'],
      ['result'],
      ['data', 'addresses'],
      ['data', 'items'],
      ['data', 'rows'],
      ['result', 'addresses'],
      ['result', 'items'],
      ['result', 'rows'],
    ]);

    if (rawAddresses.isNotEmpty) {
      final addressMaps = rawAddresses.whereType<Map<String, dynamic>>();
      if (addressMaps.isEmpty) return '';
      return _addressFromJson(addressMaps.first);
    }

    final addressMap =
        _firstNestedMapFromPaths(responseBody, const [
          ['data'],
          ['address'],
          ['result'],
        ]) ??
        responseBody;

    return _addressFromJson(addressMap);
  }

  String _addressFromJson(Map<String, dynamic> json) {
    final fullAddress = _firstStringFromKeys(json, const [
      'address',
      'fullAddress',
      'full_address',
      'deliveryAddress',
      'delivery_address',
      'customerAddress',
      'customer_address',
      'formattedAddress',
      'formatted_address',
    ]);

    if (fullAddress.isNotEmpty) return fullAddress;

    final addressParts = [
      _firstStringFromKeys(json, const [
        'addressLine1',
        'address_line_1',
        'address1',
      ]),
      _firstStringFromKeys(json, const [
        'addressLine2',
        'address_line_2',
        'address2',
      ]),
      _firstStringFromKeys(json, const ['street']),
      _firstStringFromKeys(json, const ['city']),
      _firstStringFromKeys(json, const ['state', 'province']),
      _firstStringFromKeys(json, const ['postalCode', 'postal_code', 'zip']),
      _firstStringFromKeys(json, const ['country']),
    ];

    return addressParts.where((part) => part.isNotEmpty).join(', ');
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
          'addresses',
          'address',
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

  Map<String, dynamic>? _firstNestedMapFromPaths(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      final value = _valueAtPath(source, path);
      if (value is Map<String, dynamic>) return value;
    }

    return null;
  }

  String _firstStringFromKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }

    return '';
  }

  Object? _valueAtPath(Map<String, dynamic> source, List<String> path) {
    Object? current = source;

    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }

    return current;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const _OrderDetailsHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrderDetailsTitle(order: order),
                        const SizedBox(height: 28),
                        const _MapPreview(),
                        const SizedBox(height: 30),
                        _CustomerDetailsCard(
                          order: order,
                          addressLine: _addressLine,
                          addressCity: _addressCity,
                        ),
                        const SizedBox(height: 32),
                        const _SectionLabel('ITEMS DELIVERED'),
                        const SizedBox(height: 20),
                        for (final item in order.items) ...[
                          _DeliveredItemCard(item: item),
                          if (item != order.items.last)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 30),
                        _PaymentSummaryCard(order: order),
                        const SizedBox(height: 30),
                        const _ReceiptActions(),
                      ],
                    ),
                  ),
                ),
                const _OrderDetailsBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsHeader extends StatelessWidget {
  const _OrderDetailsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Order Details',
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

class _OrderDetailsTitle extends StatelessWidget {
  const _OrderDetailsTitle({required this.order});

  final OrderDetailsData order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.orderId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF003469),
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF243348),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatReceiptDateTime(order.dateTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF243348),
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8708),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            order.status,
            style: const TextStyle(
              color: Color(0xFF372000),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFDDE2E7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPreviewPainter())),
          const Center(
            child: Icon(Icons.location_on, color: Color(0xFF2F363F), size: 92),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.location_on_outlined, size: 20),
              label: const Text(
                'View on Map',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF003469),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFE6EAEE);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final roadPaint = Paint()
      ..color = const Color(0xFFC9D0D8)
      ..strokeWidth = 2;
    final majorRoadPaint = Paint()
      ..color = const Color(0xFFB9C2CC)
      ..strokeWidth = 7;

    for (var x = -size.height; x < size.width; x += 34) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        roadPaint,
      );
    }

    for (var y = 16.0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 40), roadPaint);
    }

    canvas
      ..drawLine(
        Offset(size.width * .72, 0),
        Offset(size.width * .58, size.height),
        majorRoadPaint,
      )
      ..drawLine(
        Offset(size.width * .16, size.height),
        Offset(size.width * .92, 0),
        majorRoadPaint,
      );

    final shadePaint = Paint()..color = const Color(0xCC22272E);
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width * .16, size.height), shadePaint)
      ..drawRect(
        Rect.fromLTWH(size.width * .85, 0, size.width * .15, size.height),
        shadePaint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CustomerDetailsCard extends StatelessWidget {
  const _CustomerDetailsCard({
    required this.order,
    required this.addressLine,
    required this.addressCity,
  });

  final OrderDetailsData order;
  final String addressLine;
  final String addressCity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD2D7E0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFD7E4FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF003469),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CUSTOMER',
                      style: TextStyle(
                        color: Color(0xFF243348),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF020711),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFD2D7E0)),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.home_outlined,
                color: Color(0xFF003469),
                size: 30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addressLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF020711),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (addressCity.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        addressCity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF243348),
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF243348),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }
}

class _DeliveredItemCard extends StatelessWidget {
  const _DeliveredItemCard({required this.item});

  final OrderDetailsItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD2D7E0)),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF7A8593),
              size: 36,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF020711),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.quantity} x ${_formatMoney(item.unitPrice)}',
                  style: const TextStyle(
                    color: Color(0xFF243348),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatMoney(item.lineTotal),
            style: const TextStyle(
              color: Color(0xFF020711),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({required this.order});

  final OrderDetailsData order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF003469),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payment Method',
                  style: TextStyle(
                    color: Color(0xFFB7C8E3),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.credit_card, color: Color(0xFFB7C8E3), size: 22),
              const SizedBox(width: 10),
              Text(
                order.paymentMethod,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFF245A93)),
          const SizedBox(height: 22),
          const Text(
            'TOTAL AMOUNT',
            style: TextStyle(
              color: Color(0xFFB7C8E3),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatMoney(order.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8708),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transaction ID: ${order.transactionId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB7C8E3),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptActions extends StatelessWidget {
  const _ReceiptActions();

  static const _receiptAssetPath = 'assets/receipts/Invoice-000005.pdf';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReceiptActionButton(
            icon: Icons.print_outlined,
            label: 'Receipt',
            onTap: () => _openReceiptPdf(context),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _ReceiptActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () =>
                _showActionMessage(context, 'Share is not available yet.'),
          ),
        ),
      ],
    );
  }

  Future<void> _openReceiptPdf(BuildContext context) async {
    try {
      final receiptBytes = await rootBundle.load(_receiptAssetPath);
      final tempDirectory = await getTemporaryDirectory();
      final receiptFile = File('${tempDirectory.path}/Invoice-000005.pdf');

      await receiptFile.writeAsBytes(
        receiptBytes.buffer.asUint8List(),
        flush: true,
      );

      final openResult = await OpenFilex.open(receiptFile.path);
      if (openResult.type != ResultType.done && context.mounted) {
        _showActionMessage(context, openResult.message);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showActionMessage(context, 'Receipt PDF could not be opened.');
    }
  }

  void _showActionMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReceiptActionButton extends StatelessWidget {
  const _ReceiptActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF003469),
          side: const BorderSide(color: Color(0xFF06376F), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _OrderDetailsBottomNav extends StatelessWidget {
  const _OrderDetailsBottomNav();

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

String _formatMoney(double amount) {
  return amount
      .toStringAsFixed(2)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (match) => '${match[1]},',
      );
}

String _formatReceiptDateTime(DateTime dateTime) {
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
