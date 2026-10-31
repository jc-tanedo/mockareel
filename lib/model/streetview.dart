import 'project.dart' show PlaceDetails;

// Bounds also apply to imported projects, before timeline or renderer use.
double _seconds(dynamic value, double fallback, double min, double max) =>
    value is num && value.toDouble().isFinite
    ? value.toDouble().clamp(min, max)
    : fallback;

class StreetviewSettings {
  double openingMapSeconds, laterMapSeconds;
  bool endOnMap;
  StreetviewSettings({
    this.openingMapSeconds = 2,
    this.laterMapSeconds = 1.5,
    this.endOnMap = false,
  });
  factory StreetviewSettings.fromJson(Map<String, dynamic> j) =>
      StreetviewSettings(
        openingMapSeconds: _seconds(j['openingMapSeconds'], 2, .5, 30),
        laterMapSeconds: _seconds(j['laterMapSeconds'], 1.5, .5, 30),
        endOnMap: j['endOnMap'] == true,
      );
  Map<String, dynamic> toJson() => {
    'openingMapSeconds': openingMapSeconds,
    'laterMapSeconds': laterMapSeconds,
    'endOnMap': endOnMap,
  };
}

class StreetviewMedia {
  PlaceDetails place;
  String? mapPath;
  String date, attribution, copyright, moreDatesLabel;
  bool locationSelected;
  bool get canCaptureMap =>
      locationSelected ||
      (place.mapsUrl?.isNotEmpty ?? false) ||
      (place.placeId?.isNotEmpty ?? false);
  bool showControls, showArrows, showLocation, panZoom;
  String transition, arrow;
  double transitionSeconds;
  StreetviewMedia({
    PlaceDetails? place,
    this.mapPath,
    this.date = '',
    this.attribution = 'Google',
    this.copyright = '© 2025 Google',
    this.moreDatesLabel = 'See more dates',
    this.locationSelected = false,
    this.showControls = true,
    this.showArrows = true,
    this.showLocation = true,
    this.panZoom = false,
    this.transition = 'arrow',
    this.arrow = 'right',
    this.transitionSeconds = .45,
  }) : place = place ?? PlaceDetails();
  factory StreetviewMedia.fromJson(Map<String, dynamic> j) => StreetviewMedia(
    place: PlaceDetails.fromJson(
      Map<String, dynamic>.from(j['place'] as Map? ?? {}),
    ),
    mapPath: j['mapPath'] as String?,
    date: j['date'] as String? ?? '',
    attribution: j['attribution'] as String? ?? 'Google',
    copyright: j['copyright'] as String? ?? '© 2025 Google',
    moreDatesLabel: j['moreDatesLabel'] as String? ?? 'See more dates',
    locationSelected: j['locationSelected'] == true,
    showControls: j['showControls'] != false,
    showArrows: j['showArrows'] != false,
    showLocation: j['showLocation'] != false,
    panZoom: j['panZoom'] == true,
    transition: j['transition'] == 'map' ? 'map' : 'arrow',
    arrow: j['arrow'] == 'left' ? 'left' : 'right',
    transitionSeconds: _seconds(j['transitionSeconds'], .45, .2, 2),
  );
  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'mapPath': mapPath,
    'date': date,
    'attribution': attribution,
    'copyright': copyright,
    'moreDatesLabel': moreDatesLabel,
    'locationSelected': locationSelected,
    'showControls': showControls,
    'showArrows': showArrows,
    'showLocation': showLocation,
    'panZoom': panZoom,
    'transition': transition,
    'arrow': arrow,
    'transitionSeconds': transitionSeconds,
  };
}
