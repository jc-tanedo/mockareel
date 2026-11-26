/// Coordinates explicitly attached to a Google Maps listing. A viewport can
/// supply the missing prefix of a Plus Code but never a pin by itself.
abstract final class MapsPin {
  static final _pair = RegExp(r'^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$');
  static final _target = RegExp(
    r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)(?=[!/?&#]|$)',
  );
  static final _viewport = RegExp(
    r'/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(\d+(?:\.\d+)?)([zm])',
  );
  static const _alphabet = '23456789CFGHJMPQRVWX';
  static final _codePattern = RegExp(
    '^([$_alphabet]{2}|[$_alphabet]{4}|[$_alphabet]{6}|[$_alphabet]{8})\\+[$_alphabet]{2,7}\$',
  );

  static (double, double)? _read(RegExpMatch? m) {
    if (m == null) return null;
    final lat = double.tryParse(m[1]!), lon = double.tryParse(m[2]!);
    return lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180
        ? (lat, lon)
        : null;
  }

  // Google links can contain opaque binary tracking parameters. Decode only
  // the field being used so an unrelated byte cannot discard the listing.
  static String decoded(String value) {
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
  }

  static String? queryValue(Uri uri, String key) {
    for (final part in uri.query.split('&')) {
      final split = part.indexOf('=');
      if (split < 0 || decoded(part.substring(0, split)) != key) continue;
      return decoded(part.substring(split + 1).replaceAll('+', ' '));
    }
    return null;
  }

  static (double, double)? fromListing(Uri uri, {String plusCode = ''}) {
    final path = decoded(uri.path);
    final target =
        _read(_target.firstMatch(path)) ??
        _read(_target.firstMatch(decoded(uri.toString())));
    if (target != null) return target;
    for (final value in [
      queryValue(uri, 'query'),
      queryValue(uri, 'q'),
      if (path.split('/') case ['', 'maps', 'place', final point, ...]) point,
    ]) {
      final pin = _read(_pair.firstMatch(value?.trim() ?? ''));
      if (pin != null) return pin;
    }

    // Maps shows either a global Open Location Code or a locality-relative
    // code. Shorter codes need a closer viewport to disambiguate the cell.
    final code = plusCode.trim().toUpperCase().split(RegExp(r'\s+')).first;
    if (!_codePattern.hasMatch(code)) return null;
    final missing = 8 - code.indexOf('+');
    final digits = code.replaceAll('+', '');
    final period = switch (missing) {
      6 => .05,
      4 => 1.0,
      _ => 20.0,
    };
    final ref = _viewport.firstMatch(path);
    final center = _read(ref);
    var lat = -90.0, lon = -180.0, step = 20.0;
    if (missing > 0) {
      if (center == null) return null;
      final scale = double.parse(ref![3]!);
      final local = ref[4] == 'z'
          ? scale >= (missing == 6 ? 16 : 12)
          : scale > 0 && scale <= (missing == 6 ? 1000 : 5000);
      if (!local) return null;
      lat += ((center.$1 - lat) / period).floor() * period;
      lon += ((center.$2 - lon) / period).floor() * period;
      step = period / 20;
    }
    final pairLength = 10 - missing;
    for (var i = 0; i < pairLength; i += 2) {
      lat += _alphabet.indexOf(digits[i]) * step;
      lon += _alphabet.indexOf(digits[i + 1]) * step;
      if (i + 2 < pairLength) step /= 20;
    }
    var latStep = step, lonStep = step;
    for (final unit in digits.substring(pairLength).codeUnits) {
      final index = _alphabet.indexOf(String.fromCharCode(unit));
      latStep /= 5;
      lonStep /= 4;
      lat += (index ~/ 4) * latStep;
      lon += (index % 4) * lonStep;
    }
    lat += latStep / 2;
    lon += lonStep / 2;
    if (missing > 0) {
      final (refLat, refLon) = center!;
      lat += ((refLat - lat) / period).round() * period;
      lon += ((refLon - lon) / period).round() * period;
      lon = (lon + 180) % 360 - 180;
      // The card's pin should be close to the displayed local map.
      final maxOffset = missing == 6 ? .0125 : .25;
      if ((lat - refLat).abs() > maxOffset ||
          ((lon - refLon + 540) % 360 - 180).abs() > maxOffset) {
        return null;
      }
    }
    return lat.abs() <= 90 && lon.abs() <= 180 ? (lat, lon) : null;
  }
}
