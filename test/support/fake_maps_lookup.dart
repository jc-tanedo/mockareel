import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/services/maps_web_session.dart';

typedef MapsLookupHandler =
    Future<MapsWebSnapshot> Function(String input, String? expectedName);

class FakeMapsLookup implements MapsLookupDriver {
  final MapsLookupHandler handler;
  int cancellations = 0;
  bool disposed = false;
  FakeMapsLookup(this.handler);
  @override
  Future<void> initialize() async {}
  @override
  Future<MapsWebSnapshot> lookup(String input, {String? expectedName}) =>
      handler(input, expectedName);
  @override
  Future<MapsWebSnapshot> readPage() => handler('', null);
  @override
  void cancel() {
    cancellations++;
  }

  @override
  void dispose() {
    disposed = true;
  }
}
