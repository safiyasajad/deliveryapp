import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'orderx_logo.dart';

// DeliveryDashboardPage is shown after a successful login.
// It receives userName and accessToken from LoginPortalPage.
// userName is used in the greeting.
// accessToken is used to call protected backend APIs like the customer list.
class DeliveryDashboardPage extends StatefulWidget {
  const DeliveryDashboardPage({
    super.key,
    required this.userName,
    required this.accessToken,
  });

  // Name shown in the greeting.
  // This comes from /user/personal-info after the user signs in.
  final String userName;

  // JWT returned by /login.
  // The customer endpoint needs this in the Authorization header.
  final String accessToken;

  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage> {
  // Customer list shown in the card panel.
  // This starts empty and is filled by _fetchCustomers() after the page opens.
  List<CustomerCardData> _customers = const [];

  // Search input state.
  // _searchController reads the actual text field value.
  // _searchText stores the latest typed text so the UI can filter the cards.
  final _searchController = TextEditingController();

  // API state for the customer list.
  // _isLoadingCustomers shows a spinner while the HTTP request is in progress.
  // _customerErrorMessage stores a readable error if the API request fails.
  bool _isLoadingCustomers = true;
  String? _customerErrorMessage;

  // Stores which customer is selected.
  // This is nullable because the API can return zero customers.
  CustomerCardData? _selectedCustomer;
  String _searchText = '';

  @override
  void initState() {
    super.initState();

    // Fetch the real customer list as soon as the dashboard is created.
    // The API URL matches the endpoint provided by the backend:
    // /customer/customer-management?offset=1&limit=15&search=&sortBy=name&order=ASC
    _fetchCustomers();
  }

  @override
  void dispose() {
    // Dispose the search controller when this screen closes.
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerCardData> get _filteredCustomers {
    // Search checks the customer name, code, telephone number, and address.
    // This is local filtering over the fetched customer list.
    // Later, this can be changed to call the backend with search=<query>.
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _customers;

    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(query) ||
          customer.code.toLowerCase().contains(query) ||
          customer.telephone.toLowerCase().contains(query) ||
          customer.address.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _fetchCustomers() async {
    final apiBaseUrl = dotenv.env['API_BASE_URL'];

    if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
      setState(() {
        _isLoadingCustomers = false;
        _customerErrorMessage = 'API base URL is missing from .env.';
      });
      return;
    }

    setState(() {
      _isLoadingCustomers = true;
      _customerErrorMessage = null;
    });

    try {
      if (widget.accessToken.isEmpty) {
        throw Exception(
          'Login token missing. Please log out and log in again.',
        );
      }

      final uri = Uri.parse(apiBaseUrl).replace(
        path: '/customer/customer-management',
        queryParameters: const {
          'offset': '1',
          'limit': '15',
          'search': '',
          'sortBy': 'name',
          'order': 'ASC',
        },
      );

      // Fetch customers from the backend using the access token from login.
      // If the endpoint is protected, Authorization: Bearer <token> lets the
      // backend know which signed-in user is making the request.
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (widget.accessToken.isNotEmpty)
            'Authorization': 'Bearer ${widget.accessToken}',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Customer request failed with status ${response.statusCode}.',
        );
      }

      final responseBody = _decodeResponseBody(response.body);
      final customersWithoutAddresses = _parseCustomers(responseBody);

      // The customer-management endpoint gives us each customer's basic data.
      // Addresses come from a second endpoint that needs the customer's id:
      // /customer_address/address-management?customerId=<CUSTOMER_ID>
      final customers = await Future.wait(
        customersWithoutAddresses.map(
          (customer) => _customerWithFetchedAddress(
            apiBaseUrl: apiBaseUrl,
            customer: customer,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _customers = customers;
        _selectedCustomer = customers.isEmpty ? null : customers.first;
        _isLoadingCustomers = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _customers = const [];
        _selectedCustomer = null;
        _isLoadingCustomers = false;
        _customerErrorMessage = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    // Convert the customer API JSON response into a Dart Map.
    // Empty or non-object responses become an empty map so the UI can show a
    // friendly empty/error state instead of crashing.
    if (body.isEmpty) return const {};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'data': decoded};

    return const {};
  }

  List<CustomerCardData> _parseCustomers(Map<String, dynamic> responseBody) {
    // Different APIs wrap lists differently. This checks common structures:
    // { data: [...] }
    // { data: { customers: [...] } }
    // { customers: [...] }
    // { result: { rows: [...] } }
    final rawCustomers = _firstListFromPaths(responseBody, const [
      ['data'],
      ['customers'],
      ['customer'],
      ['items'],
      ['rows'],
      ['result'],
      ['result', 'customers'],
      ['result', 'items'],
      ['result', 'rows'],
      ['data', 'customers'],
      ['data', 'items'],
      ['data', 'rows'],
      ['data', 'result'],
    ]);

    return rawCustomers
        .whereType<Map<String, dynamic>>()
        .map(_customerFromJson)
        .where((customer) => customer.name.isNotEmpty)
        .toList();
  }

  CustomerCardData _customerFromJson(Map<String, dynamic> json) {
    // Maps one API customer object into the fields required by the card UI.
    // These keys are intentionally flexible because the exact QA response shape
    // may differ from the column names shown in the admin table.
    final name = _firstStringFromKeys(json, const [
      'name',
      'fullName',
      'full_name',
      'firstName',
      'first_name',
      'customerName',
      'customer_name',
      'displayName',
      'display_name',
      'companyName',
      'company_name',
    ]);

    final id = _firstStringFromKeys(json, const [
      'id',
      '_id',
      'customerId',
      'customer_id',
      'uuid',
    ]);

    final code = _firstStringFromKeys(json, const [
      'code',
      'customerCode',
      'customer_code',
      'customerNo',
      'customer_no',
      'customerNumber',
      'customer_number',
      'reference',
      'ref',
      'id',
    ]);

    final telephone = _firstStringFromKeys(json, const [
      'telephone',
      'telephoneNumber',
      'telephone_number',
      'phone',
      'phoneNumber',
      'phone_number',
      'mobile',
      'mobileNumber',
      'mobile_number',
      'contact',
      'contactNumber',
      'contact_number',
    ]);

    final address = _firstStringFromKeys(json, const [
      'address',
      'fullAddress',
      'full_address',
      'addressLine1',
      'address_line_1',
      'address1',
      'street',
      'city',
      'deliveryAddress',
      'delivery_address',
      'customerAddress',
      'customer_address',
      'location',
    ]);

    return CustomerCardData(
      id: id,
      name: name,
      code: code.isEmpty ? 'No code' : code,
      telephone: telephone.isEmpty ? 'No telephone number' : telephone,
      address: address.isEmpty ? 'No address available' : address,
    );
  }

  Future<CustomerCardData> _customerWithFetchedAddress({
    required String apiBaseUrl,
    required CustomerCardData customer,
  }) async {
    // If there is no id, we cannot call the address endpoint for this customer.
    // Keep the address from the customer list response if it exists.
    if (customer.id.isEmpty) return customer;

    try {
      final uri = Uri.parse(apiBaseUrl).replace(
        path: '/customer_address/address-management',
        queryParameters: {'customerId': customer.id},
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (widget.accessToken.isNotEmpty)
            'Authorization': 'Bearer ${widget.accessToken}',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return customer;
      }

      final responseBody = _decodeResponseBody(response.body);
      final address = _parseAddress(responseBody);

      if (address.isEmpty) return customer;

      return customer.copyWith(address: address);
    } catch (_) {
      // Address fetch failure should not remove the customer from the list.
      // Keep the customer card with its original fallback address.
      return customer;
    }
  }

  String _parseAddress(Map<String, dynamic> responseBody) {
    // Address endpoint responses can be shaped as:
    // { data: [...] }, { data: {...} }, { addresses: [...] }, or a direct object.
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
      final firstAddress = addressMaps.first;
      return _addressFromJson(firstAddress);
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
    // Prefer complete address fields first. If the API sends separate address
    // parts, join those parts into one readable line for the card.
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
    // Reads the first list found at any requested JSON path.
    // If a path points to a map instead of a list, the method also checks common
    // list keys inside that map.
    for (final path in paths) {
      final value = _valueAtPath(source, path);
      if (value is List) return value;

      if (value is Map<String, dynamic>) {
        final nestedList = _firstListFromKeys(value, const [
          'customers',
          'customer',
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
    // Reads the first list from a flat object using several possible keys.
    for (final key in keys) {
      final value = source[key];
      if (value is List) return value;
    }

    return const [];
  }

  String _firstStringFromKeys(Map<String, dynamic> source, List<String> keys) {
    // Reads the first non-empty string from a customer object.
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }

    return '';
  }

  Object? _valueAtPath(Map<String, dynamic> source, List<String> path) {
    // Safely reads nested JSON values.
    // Example path ['data', 'customers'] reads source['data']['customers'].
    Object? current = source;

    for (final key in path) {
      if (current is! Map<String, dynamic>) return null;
      current = current[key];
    }

    return current;
  }

  Map<String, dynamic>? _firstNestedMapFromPaths(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    // Reads the first map found at any requested JSON path.
    for (final path in paths) {
      final value = _valueAtPath(source, path);
      if (value is Map<String, dynamic>) return value;
    }

    return null;
  }

  void _selectCustomer(CustomerCardData selectedCustomer) {
    // Store the selected customer object.
    // This works even when the visible cards are filtered by search.
    setState(() {
      _selectedCustomer = selectedCustomer;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate screen-specific display values before building widgets.
    // filteredCustomers controls which cards appear after search.
    // displayName prevents an empty greeting if an empty name is ever passed in.
    final filteredCustomers = _filteredCustomers;
    final selectedCustomer = _selectedCustomer;
    final displayName = widget.userName.trim().isEmpty
        ? 'User'
        : widget.userName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // Fixed top header: logo, title, refresh button, and logout
                // button. The refresh button calls the same API loading method
                // used when the screen first opens.
                _DashboardHeader(
                  isRefreshing: _isLoadingCustomers,
                  onRefresh: _fetchCustomers,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    // Main dashboard content scrolls independently from the
                    // fixed bottom action bar.
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Greeting section at the top of the dashboard.
                        Text(
                          'Hello, $displayName',
                          style: const TextStyle(
                            color: Color(0xFF010713),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Who are we delivering to today?',
                          style: TextStyle(
                            color: Color(0xFF243348),
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 34),

                        // Search section.
                        // This filters the customers that were fetched from the
                        // backend customer-management endpoint.
                        const _SectionLabel('Search Customer'),
                        const SizedBox(height: 8),
                        _SearchField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        // Customer card list loaded from the backend.
                        _CustomerListPanel(
                          customers: filteredCustomers,
                          selectedCustomer: selectedCustomer,
                          isLoading: _isLoadingCustomers,
                          errorMessage: _customerErrorMessage,
                          onRetry: _fetchCustomers,
                          onSelected: _selectCustomer,
                        ),
                        const SizedBox(height: 30),

                        // Small pinned summary for the selected customer.
                        if (selectedCustomer != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _PinnedCustomerChip(
                              customerName: selectedCustomer.name,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _BottomActionBar(
                  isEnabled: selectedCustomer != null,
                  onContinue: () {
                    if (selectedCustomer == null) return;

                    // Placeholder action until the next delivery workflow page
                    // is added. For now it confirms the selected customer.
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Selected ${selectedCustomer.name}'),
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerCardData {
  // Small data model for one customer card.
  // This keeps the UI clean because each card receives a typed object instead
  // of several loose strings.
  const CustomerCardData({
    required this.id,
    required this.name,
    required this.code,
    required this.telephone,
    required this.address,
  });

  final String id;
  final String name;
  final String code;
  final String telephone;
  final String address;

  CustomerCardData copyWith({
    String? id,
    String? name,
    String? code,
    String? telephone,
    String? address,
  }) {
    return CustomerCardData(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      telephone: telephone ?? this.telephone,
      address: address ?? this.address,
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.isRefreshing, required this.onRefresh});

  // True while customer data is being fetched from the backend.
  // The header uses this to show a small spinner instead of the refresh icon.
  final bool isRefreshing;

  // Called when the user taps the refresh button.
  // In the parent widget this points to _fetchCustomers(), so refresh gets the
  // latest customer list and the latest address data for each customer.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    // Header matches the mockup: small OrderX logo on the left, title beside it,
    // action icons on the right, and a subtle bottom border.
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        border: Border(bottom: BorderSide(color: Color(0xFFD8DCE3))),
      ),
      child: Row(
        children: [
          const OrderXLogo(size: 40, borderRadius: 8),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'OrderX Delivery',
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
            // Disable refresh while a request is already running. This prevents
            // duplicate API calls if the user taps repeatedly.
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF003469),
                      strokeWidth: 2.4,
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF003469), size: 28),
            tooltip: 'Refresh customers',
          ),
          IconButton(
            onPressed: () {
              // Returning from the dashboard triggers _clearLoginForm() in the
              // login page because LoginPortalPage awaits this route.
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout, color: Color(0xFF003469), size: 28),
            tooltip: 'Log out',
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
    // Reusable section label used above the search field.
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2D3645),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: .4,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Search text field from the mockup.
    // The parent owns the controller and onChanged callback so the parent can
    // update filtered customer results.
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        color: Color(0xFF26364D),
        fontSize: 20,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: 'Enter name, code or telephone...',
        hintStyle: const TextStyle(
          color: Color(0xFF5D6B7D),
          fontSize: 20,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF637184),
          size: 30,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF8E96A3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0A3C73), width: 1.4),
        ),
      ),
    );
  }
}

class _CustomerListPanel extends StatelessWidget {
  const _CustomerListPanel({
    required this.customers,
    required this.selectedCustomer,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onSelected,
  });

  final List<CustomerCardData> customers;
  final CustomerCardData? selectedCustomer;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<CustomerCardData> onSelected;

  @override
  Widget build(BuildContext context) {
    // Loading state shown while the customer API request is running.
    if (isLoading) {
      return const _CustomerPanelShell(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF06376F)),
          ),
        ),
      );
    }

    // Error state shown if the API request fails.
    if (errorMessage != null) {
      return _CustomerPanelShell(
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

    // Empty state shown when the API returns no customers or search filters out
    // all fetched customers.
    if (customers.isEmpty) {
      return const _CustomerPanelShell(
        child: Text(
          'No customers found.',
          style: TextStyle(
            color: Color(0xFF26364D),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _CustomerPanelShell(
      child: Column(
        children: [
          // Build each card and add spacing between cards, but not after the
          // final card.
          for (var index = 0; index < customers.length; index++) ...[
            _CustomerCard(
              customer: customers[index],
              isSelected: customers[index] == selectedCustomer,
              onTap: () => onSelected(customers[index]),
            ),
            if (index != customers.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CustomerPanelShell extends StatelessWidget {
  const _CustomerPanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Shared panel around loading, error, empty, and list states.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DCE3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  final CustomerCardData customer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selected cards use a blue border and pale-blue background.
    // Unselected cards stay white with a lighter border.
    final borderColor = isSelected
        ? const Color(0xFF0A3C73)
        : const Color(0xFFD2D7E0);
    final backgroundColor = isSelected
        ? const Color(0xFFD8E5FF)
        : const Color(0xFFFFFFFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // InkWell gives the card a proper tap interaction/ripple.
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isSelected ? 2.2 : 1),
          ),
          child: Row(
            children: [
              // Customer details take all available width.
              // The selection circle stays fixed on the right.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF020711),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CustomerDetailLine(
                      icon: Icons.tag_outlined,
                      text: customer.code,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 8),
                    _CustomerDetailLine(
                      icon: Icons.phone_outlined,
                      text: customer.telephone,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 8),
                    _CustomerDetailLine(
                      icon: Icons.location_on_outlined,
                      text: customer.address,
                      fontSize: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _SelectionIndicator(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerDetailLine extends StatelessWidget {
  const _CustomerDetailLine({
    required this.icon,
    required this.text,
    required this.fontSize,
  });

  final IconData icon;
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // One icon + text row inside a customer card.
    // Used for customer code, telephone, and address lines.
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0A3C73), size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF22324A),
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    // Selected state: filled blue circle with a check mark.
    if (isSelected) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF06376F),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 24),
      );
    }

    // Unselected state: white circle with a light gray border.
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC1C8D4), width: 3),
      ),
    );
  }
}

class _PinnedCustomerChip extends StatelessWidget {
  const _PinnedCustomerChip({required this.customerName});

  final String customerName;

  @override
  Widget build(BuildContext context) {
    // The pinned chip summarizes the currently selected customer.
    // ConstrainedBox prevents overflow on narrow mobile screens.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 64,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A4587),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_border, color: Color(0xFF8DB8FF), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pinned: $customerName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8DB8FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.isEnabled, required this.onContinue});

  final bool isEnabled;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    // Fixed bottom action area from the mockup.
    // It stays separate from the scrollable content above it.
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
            // Later this should navigate to the next step for the selected
            // customer, such as package details or delivery confirmation.
            onPressed: isEnabled ? onContinue : null,
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
                  'Continue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
