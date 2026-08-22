/// Inward/Outward document type lists per REQUIREMENTS.md §6.4. Only
/// "Work Order" was confirmed as an inward example in the source
/// spreadsheet — the rest are reasonable placeholders pending stakeholder
/// confirmation (§12 item 5); "Other" is always available as an escape
/// hatch.
const List<String> kInwardDocTypes = [
  'Work Order',
  'Tender Document',
  'Letter',
  'Notice',
  'Other',
];

const List<String> kOutwardDocTypes = [
  'Work Order',
  'Letter',
  'Request for EMD Clearance',
  'Request for References',
  'Request for Recommendations',
  'Other',
];

const List<String> kDispatchModes = ['Courier', 'Post', 'Hand Delivery', 'Email'];
