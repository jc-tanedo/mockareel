class PlaceDetails {
  String name, category, rating, address, localName, reviewCount, price, hours;
  String? placeId, mapsUrl;
  double? latitude, longitude;
  String phone, website;
  List<String> types;
  List<PlaceAction>? actionOverrides;
  bool? menuOverride;
  String? footerOverride;
  static final _menuCategoryPattern = RegExp(
    r'\b(restaurant|caf[eé]|coffee|bakery|bar|eatery|bistro|'
    r'diner|pizzeria|food|pub|grill|kitchen|brewery)\b',
    caseSensitive: false,
  );
  bool get hasMenu =>
      menuOverride ??
      (types.any(
            (t) =>
                const {
                  'restaurant',
                  'cafe',
                  'coffee_shop',
                  'bakery',
                  'bar',
                  'meal_takeaway',
                  'meal_delivery',
                  'fast_food_restaurant',
                  'food_court',
                }.contains(t) ||
                t.endsWith('_restaurant'),
          ) ||
          _menuCategoryPattern.hasMatch(category));
  List<PlaceAction> get suggestedActions => [
    PlaceAction(kind: 'directions', label: 'Directions'),
    if (hasMenu) PlaceAction(kind: 'menu', label: 'Menu'),
    if (phone.isNotEmpty) PlaceAction(kind: 'call', label: 'Call'),
    if (website.isNotEmpty) PlaceAction(kind: 'website', label: 'Website'),
    PlaceAction(kind: 'save', label: 'Save'),
  ].take(4).toList();
  List<PlaceAction> get actions => actionOverrides ?? suggestedActions;
  String get footer =>
      footerOverride ??
      (hasMenu
          ? 'View menu'
          : website.isNotEmpty
          ? 'Visit website'
          : 'Get directions');
  PlaceDetails({
    this.name = '',
    this.category = '',
    this.rating = '',
    this.address = '',
    this.placeId,
    this.mapsUrl,
    this.latitude,
    this.longitude,
    this.phone = '',
    this.website = '',
    List<String>? types,
    this.actionOverrides,
    this.menuOverride,
    this.footerOverride,
    this.localName = '',
    this.reviewCount = '',
    this.price = '',
    this.hours = '',
  }) : types = types ?? [];
  factory PlaceDetails.fromJson(Map<String, dynamic> json) => PlaceDetails(
    name: json['name'] as String? ?? '',
    category: (json['category'] ?? json['subtitle']) as String? ?? '',
    rating: json['rating']?.toString() ?? '',
    address: json['address'] as String? ?? '',
    placeId: json['placeId'] as String?,
    mapsUrl: json['mapsUrl'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    phone: json['phone'] as String? ?? '',
    website: json['website'] as String? ?? '',
    types: (json['types'] as List? ?? []).cast<String>(),
    actionOverrides: (json['actions'] as List?)
        ?.map((e) => PlaceAction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    menuOverride: json['menuOverride'] as bool?,
    footerOverride: json['footerOverride'] as String?,
    localName: json['localName'] as String? ?? '',
    reviewCount: json['reviewCount'] as String? ?? '',
    price: json['price'] as String? ?? '',
    hours: json['hours'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'rating': rating,
    'address': address,
    'placeId': placeId,
    'mapsUrl': mapsUrl,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'website': website,
    'types': types,
    'actions': actionOverrides?.map((e) => e.toJson()).toList(),
    'menuOverride': menuOverride,
    'footerOverride': footerOverride,
    'localName': localName,
    'reviewCount': reviewCount,
    'price': price,
    'hours': hours,
  };
}

class PlaceAction {
  String kind, label;
  PlaceAction({required this.kind, required this.label});
  factory PlaceAction.fromJson(Map<String, dynamic> j) => PlaceAction(
    kind: j['kind'] as String? ?? 'custom',
    label: j['label'] as String? ?? 'Action',
  );
  Map<String, dynamic> toJson() => {'kind': kind, 'label': label};
}
