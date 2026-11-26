import 'package:mockareel/model/ids.dart';
import 'package:mockareel/model/place_details.dart';

class OrbitLocation {
  final String id;
  PlaceDetails place;
  String? mapPath, overviewPath;
  OrbitLocation({
    String? id,
    required this.place,
    this.mapPath,
    this.overviewPath,
  }) : id = id ?? newId();
  String get label {
    if (place.name.trim().isNotEmpty) return place.name;
    if (place.address.trim().isNotEmpty) return place.address;
    if (place.latitude != null && place.longitude != null) {
      return '${place.latitude!.toStringAsFixed(4)}, ${place.longitude!.toStringAsFixed(4)}';
    }
    return 'Dropped pin';
  }

  factory OrbitLocation.fromJson(Map<String, dynamic> json) => OrbitLocation(
    id: json['id'] as String,
    place: PlaceDetails.fromJson(json['place'] as Map<String, dynamic>),
    mapPath: json['mapPath'] as String?,
    overviewPath: json['overviewPath'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'place': place.toJson(),
    'mapPath': mapPath,
    if (overviewPath != null) 'overviewPath': overviewPath,
  };
}
