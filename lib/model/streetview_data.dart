import '../features/streetview_3d/model/orbit_location.dart';
import 'place_details.dart';

// Bounds also apply to imported projects, before timeline or renderer use.
double _seconds(dynamic value, double fallback, double min, double max) =>
    value is num && value.toDouble().isFinite
    ? value.toDouble().clamp(min, max)
    : fallback;

class StreetviewSettings {
  double openingMapSeconds, laterMapSeconds;
  bool endOnMap;
  final List<OrbitLocation> locations;

  StreetviewSettings({
    this.openingMapSeconds = 2,
    this.laterMapSeconds = 1.5,
    this.endOnMap = false,
    List<OrbitLocation>? locations,
  }) : locations = locations ?? [];
  factory StreetviewSettings.fromJson(Map<String, dynamic> j) =>
      StreetviewSettings(
        locations: (j['locations'] as List?)
            ?.map((e) => OrbitLocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        openingMapSeconds: _seconds(j['openingMapSeconds'], 2, .5, 30),
        laterMapSeconds: _seconds(j['laterMapSeconds'], 1.5, .5, 30),
        endOnMap: j['endOnMap'] == true,
      );
  Map<String, dynamic> toJson() => {
    if (locations.isNotEmpty)
      'locations': locations.map((l) => l.toJson()).toList(),
    'openingMapSeconds': openingMapSeconds,
    'laterMapSeconds': laterMapSeconds,
    'endOnMap': endOnMap,
  };
}

class StreetviewMedia {
  PlaceDetails place;
  String? mapPath;
  String? wallId;
  List<String> visitedWalls;
  String walkMove;
  List<String> walkLayers;
  List<int> walkDepth;
  bool get walking => walkMove != 'hold' && walkLayers.length == 3;
  String date, attribution, copyright, moreDatesLabel;
  bool locationSelected;
  String locationOrigin;
  String? locationId;
  bool get canCaptureMap =>
      locationSelected ||
      (place.mapsUrl?.isNotEmpty ?? false) ||
      (place.placeId?.isNotEmpty ?? false);
  bool showControls,
      showArrows,
      showLocation,
      slowZoom,
      slowPan,
      turntable,
      turntableReverse;
  double zoomAmount, panAmount, turntableDegrees;
  String aerialLabel, nearbyLabel, streetviewTitle;
  bool get panZoom => slowZoom && slowPan;
  set panZoom(bool value) {
    slowZoom = value;
    slowPan = value;
  }

  String transition, arrow;
  double transitionSeconds;
  StreetviewMedia({
    PlaceDetails? place,
    this.mapPath,
    this.wallId,
    List<String>? visitedWalls,
    this.walkMove = 'hold',
    List<String>? walkLayers,
    List<int>? walkDepth,
    this.date = '',
    this.attribution = 'Google',
    this.copyright = '© 2025 Google',
    this.moreDatesLabel = 'See more dates',
    this.locationSelected = false,
    this.locationOrigin = '',
    this.locationId,
    this.showControls = true,
    this.showArrows = true,
    this.showLocation = true,
    bool panZoom = false,
    bool? slowZoom,
    bool? slowPan,
    this.turntable = false,
    this.turntableReverse = false,
    this.zoomAmount = .06,
    this.panAmount = 8 / 360,
    this.turntableDegrees = 8,
    this.aerialLabel = 'Aerial',
    this.nearbyLabel = 'See nearby attractions',
    this.streetviewTitle = '',
    this.transition = 'arrow',
    this.arrow = 'right',
    this.transitionSeconds = .55,
  }) : visitedWalls = visitedWalls ?? [],
       walkLayers = walkLayers ?? [],
       walkDepth = walkDepth ?? [],
       slowZoom = slowZoom ?? panZoom,
       slowPan = slowPan ?? panZoom,
       place = place ?? PlaceDetails();
  factory StreetviewMedia.fromJson(Map<String, dynamic> j) => StreetviewMedia(
    place: PlaceDetails.fromJson(
      Map<String, dynamic>.from(j['place'] as Map? ?? {}),
    ),
    locationId: j['locationId'] as String?,
    locationOrigin: j['locationOrigin'] as String? ?? '',
    mapPath: j['mapPath'] as String?,
    wallId: j['wallId'] as String?,
    visitedWalls: (j['visitedWalls'] as List?)?.whereType<String>().toList(),
    walkDepth: switch (j['walkDepth']) {
      final List d
          when d.length == 1024 &&
              d.every((v) => v is int && v >= 0 && v <= 255) =>
        d.cast<int>(),
      _ => [],
    },
    walkMove: const {'left', 'right', 'forward'}.contains(j['walkMove'])
        ? j['walkMove'] as String
        : 'hold',
    walkLayers: (j['walkLayers'] as List?)?.length == 3
        ? (j['walkLayers'] as List).cast<String>()
        : [],
    date: j['date'] as String? ?? '',
    attribution: j['attribution'] as String? ?? 'Google',
    copyright: j['copyright'] as String? ?? '© 2025 Google',
    moreDatesLabel: j['moreDatesLabel'] as String? ?? 'See more dates',
    locationSelected: j['locationSelected'] == true,
    showControls: j['showControls'] != false,
    showArrows: j['showArrows'] != false,
    showLocation: j['showLocation'] != false,
    panZoom: j['panZoom'] == true,
    slowZoom: j['slowZoom'] as bool?,
    slowPan: j['slowPan'] as bool?,
    turntable: j['turntable'] == true,
    turntableReverse:
        j['turntableReverse'] as bool? ??
        (_seconds(j['turntableDegrees'], 8, -15, 15) < 0),
    zoomAmount: _seconds(j['zoomAmount'], .06, 0, .2),
    panAmount: _seconds(j['panAmount'], 8 / 360, -.08, .08),
    turntableDegrees: _seconds(j['turntableDegrees'], 8, -15, 15).abs(),
    aerialLabel: j['aerialLabel'] as String? ?? 'Aerial',
    nearbyLabel: j['nearbyLabel'] as String? ?? 'See nearby attractions',
    streetviewTitle: j['streetviewTitle'] as String? ?? '',
    transition: j['transition'] == 'map' ? 'map' : 'arrow',
    arrow: j['arrow'] == 'left' ? 'left' : 'right',
    transitionSeconds: _seconds(j['transitionSeconds'], .55, .25, 2),
  );
  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'mapPath': mapPath,
    if (wallId != null) 'wallId': wallId,
    if (visitedWalls.isNotEmpty) 'visitedWalls': visitedWalls,
    if (walkLayers.length == 3) 'walkLayers': walkLayers,
    if (walkDepth.length == 1024) 'walkDepth': walkDepth,
    if (walkMove != 'hold') 'walkMove': walkMove,
    'date': date,
    'attribution': attribution,
    'copyright': copyright,
    'moreDatesLabel': moreDatesLabel,
    if (locationId != null) 'locationId': locationId,
    if (locationOrigin.isNotEmpty) 'locationOrigin': locationOrigin,
    'locationSelected': locationSelected,
    'showControls': showControls,
    'showArrows': showArrows,
    'showLocation': showLocation,
    'panZoom': panZoom,
    'slowZoom': slowZoom,
    'slowPan': slowPan,
    'turntable': turntable,
    'turntableReverse': turntableReverse,
    'zoomAmount': zoomAmount,
    'panAmount': panAmount,
    'turntableDegrees': turntableDegrees,
    'aerialLabel': aerialLabel,
    'nearbyLabel': nearbyLabel,
    'streetviewTitle': streetviewTitle,
    'transition': transition,
    'arrow': arrow,
    'transitionSeconds': transitionSeconds,
  };
}
