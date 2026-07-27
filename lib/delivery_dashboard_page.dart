import 'package:flutter/material.dart';

import 'orderx_logo.dart';

// DeliveryDashboardPage is shown after a successful login.
// It receives userName and accessToken from LoginPortalPage.
// userName is used in the greeting.
// accessToken will be used later when the real customer API is connected.
class DeliveryDashboardPage extends StatefulWidget {
  const DeliveryDashboardPage({
    super.key,
    required this.userName,
    required this.accessToken,
  });

  // Name shown in the greeting.
  // This comes from /user/personal-info after the user signs in.
  final String userName;

  // JWT returned by /login. This will be useful when the customer API is added
  // because protected endpoints usually need Authorization: Bearer <token>.
  final String accessToken;

  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage> {
  // Temporary customer data used to build the card UI.
  // Later, this list can be replaced with data returned from the customer API.
  // When the API link is added, this should become:
  // 1. An empty list at first.
  // 2. Filled after an HTTP GET request succeeds.
  // 3. Rendered by the same _CustomerListPanel and _CustomerCard widgets.
  final List<CustomerCardData> _customers = const [
    CustomerCardData(
      name: 'Sarah Jenkins',
      phone: '+1 (555) 234-8901',
      address: '452 Oak Avenue, Springfield',
    ),
    CustomerCardData(
      name: 'Michael Rodriguez',
      phone: '+1 (555) 876-5432',
      address: '12 Industrial Pkwy, Unit B',
    ),
    CustomerCardData(
      name: 'Amazon Hub Locker',
      phone: '+1 (555) 111-2222',
      address: '789 Retail Row, Ste 100',
    ),
  ];

  // Search input state.
  // _searchController reads/clears the actual text field value.
  // _searchText stores the latest typed text so the UI can filter the cards.
  final _searchController = TextEditingController();

  // Stores which customer is selected.
  // This is an index into _customers, not _filteredCustomers, so the selected
  // customer remains stable even when the search text changes.
  int _selectedCustomerIndex = 0;
  String _searchText = '';

  @override
  void dispose() {
    // Dispose the search controller when this screen closes.
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerCardData> get _filteredCustomers {
    // Search checks the customer name, phone number, and address.
    // This is local filtering over the current list.
    // Later, if the customer API supports search, this can be changed to call
    // the backend instead of filtering in Flutter.
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _customers;

    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query) ||
          customer.address.toLowerCase().contains(query);
    }).toList();
  }

  CustomerCardData get _selectedCustomer => _customers[_selectedCustomerIndex];

  void _selectCustomer(CustomerCardData selectedCustomer) {
    // Store the selected customer's index from the original list, not the
    // filtered list, so the selected card stays correct after search changes.
    setState(() {
      _selectedCustomerIndex = _customers.indexOf(selectedCustomer);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate screen-specific display values before building widgets.
    // filteredCustomers controls which cards appear after search.
    // displayName prevents an empty greeting if an empty name is ever passed in.
    final filteredCustomers = _filteredCustomers;
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
                // Fixed top header: logo, title, and logout button.
                const _DashboardHeader(),
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

                        // Search section. Later, this can either filter the
                        // locally fetched API results or call a search endpoint.
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

                        // Customer card list. This is the area that will be
                        // populated from the customer API once the link is known.
                        _CustomerListPanel(
                          customers: filteredCustomers,
                          selectedCustomer: _selectedCustomer,
                          onSelected: _selectCustomer,
                        ),
                        const SizedBox(height: 30),

                        // Small pinned summary for the selected customer.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _PinnedCustomerChip(
                            customerName: _selectedCustomer.name,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomActionBar(
                  onContinue: () {
                    // Placeholder action until the next delivery workflow page
                    // is added. For now it confirms the selected customer.
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Selected ${_selectedCustomer.name}'),
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
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    // Header matches the mockup: small OrderX logo on the left, title beside it,
    // logout icon on the right, and a subtle bottom border.
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
        hintText: 'Enter name or phone number...',
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
    required this.onSelected,
  });

  final List<CustomerCardData> customers;
  final CustomerCardData selectedCustomer;
  final ValueChanged<CustomerCardData> onSelected;

  @override
  Widget build(BuildContext context) {
    // Empty state shown when search filters out all customers.
    // This will also be useful if the customer API returns an empty list.
    if (customers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8DCE3)),
        ),
        child: const Text(
          'No customers found.',
          style: TextStyle(
            color: Color(0xFF26364D),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      // Panel around all customer cards.
      // The cards are separate selectable rows inside this framed area.
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
                      icon: Icons.phone_outlined,
                      text: customer.phone,
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
    // Used for phone and address lines.
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
  const _BottomActionBar({required this.onContinue});

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
            onPressed: onContinue,
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
