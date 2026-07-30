// Immutable data model for one customer shown in the delivery workflow.
//
// DeliveryDashboardPage creates this object from the customer API response.
// ProductSelectionPage and PaymentCollectionPage then pass the same object
// forward so each step can display the selected customer's name/address without
// re-fetching the customer record.
class CustomerCardData {
  const CustomerCardData({
    required this.id,
    required this.name,
    required this.code,
    required this.telephone,
    required this.address,
  });

  // Backend customer id. This is the safest value to use when another endpoint
  // needs to identify the customer, such as address or order APIs.
  final String id;

  // Customer display name shown in cards, headers, and summaries.
  final String name;

  // Customer/business code shown in the dashboard card.
  final String code;

  // Contact number shown in the dashboard card.
  final String telephone;

  // Resolved delivery address. The dashboard may fetch this from a separate
  // address endpoint after loading the base customer record.
  final String address;

  // Creates a modified copy while keeping the object immutable. This is useful
  // when one API provides basic customer details and a later API adds/updates
  // only the address.
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
