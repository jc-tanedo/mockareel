import 'dart:ui';

/// Source attributes are kept separately so an explicit colour from a matched
/// footprint can take precedence over a material estimate from another feed.
class BuildingAppearance {
  final int? wall, roof;
  final String? wallMaterial, roofMaterial;
  const BuildingAppearance({
    this.wall,
    this.roof,
    this.wallMaterial,
    this.roofMaterial,
  });

  // CSS named colors used by OpenStreetMap, with gray normalized to grey.
  static const _named = {
    'aliceblue': 0xf0f8ff,
    'antiquewhite': 0xfaebd7,
    'aqua': 0x00ffff,
    'aquamarine': 0x7fffd4,
    'azure': 0xf0ffff,
    'beige': 0xf5f5dc,
    'bisque': 0xffe4c4,
    'black': 0x000000,
    'blanchedalmond': 0xffebcd,
    'blue': 0x0000ff,
    'blueviolet': 0x8a2be2,
    'brown': 0xa52a2a,
    'burlywood': 0xdeb887,
    'cadetblue': 0x5f9ea0,
    'chartreuse': 0x7fff00,
    'chocolate': 0xd2691e,
    'coral': 0xff7f50,
    'cornflowerblue': 0x6495ed,
    'cornsilk': 0xfff8dc,
    'crimson': 0xdc143c,
    'cyan': 0x00ffff,
    'darkblue': 0x00008b,
    'darkcyan': 0x008b8b,
    'darkgoldenrod': 0xb8860b,
    'darkgreen': 0x006400,
    'darkgrey': 0xa9a9a9,
    'darkkhaki': 0xbdb76b,
    'darkmagenta': 0x8b008b,
    'darkolivegreen': 0x556b2f,
    'darkorange': 0xff8c00,
    'darkorchid': 0x9932cc,
    'darkred': 0x8b0000,
    'darksalmon': 0xe9967a,
    'darkseagreen': 0x8fbc8f,
    'darkslateblue': 0x483d8b,
    'darkslategrey': 0x2f4f4f,
    'darkturquoise': 0x00ced1,
    'darkviolet': 0x9400d3,
    'deeppink': 0xff1493,
    'deepskyblue': 0x00bfff,
    'dimgrey': 0x696969,
    'dodgerblue': 0x1e90ff,
    'firebrick': 0xb22222,
    'floralwhite': 0xfffaf0,
    'forestgreen': 0x228b22,
    'fuchsia': 0xff00ff,
    'gainsboro': 0xdcdcdc,
    'ghostwhite': 0xf8f8ff,
    'gold': 0xffd700,
    'goldenrod': 0xdaa520,
    'green': 0x008000,
    'greenyellow': 0xadff2f,
    'grey': 0x808080,
    'honeydew': 0xf0fff0,
    'hotpink': 0xff69b4,
    'indianred': 0xcd5c5c,
    'indigo': 0x4b0082,
    'ivory': 0xfffff0,
    'khaki': 0xf0e68c,
    'lavender': 0xe6e6fa,
    'lavenderblush': 0xfff0f5,
    'lawngreen': 0x7cfc00,
    'lemonchiffon': 0xfffacd,
    'lightblue': 0xadd8e6,
    'lightcoral': 0xf08080,
    'lightcyan': 0xe0ffff,
    'lightgoldenrodyellow': 0xfafad2,
    'lightgreen': 0x90ee90,
    'lightgrey': 0xd3d3d3,
    'lightpink': 0xffb6c1,
    'lightsalmon': 0xffa07a,
    'lightseagreen': 0x20b2aa,
    'lightskyblue': 0x87cefa,
    'lightslategrey': 0x778899,
    'lightsteelblue': 0xb0c4de,
    'lightyellow': 0xffffe0,
    'lime': 0x00ff00,
    'limegreen': 0x32cd32,
    'linen': 0xfaf0e6,
    'magenta': 0xff00ff,
    'maroon': 0x800000,
    'mediumaquamarine': 0x66cdaa,
    'mediumblue': 0x0000cd,
    'mediumorchid': 0xba55d3,
    'mediumpurple': 0x9370db,
    'mediumseagreen': 0x3cb371,
    'mediumslateblue': 0x7b68ee,
    'mediumspringgreen': 0x00fa9a,
    'mediumturquoise': 0x48d1cc,
    'mediumvioletred': 0xc71585,
    'midnightblue': 0x191970,
    'mintcream': 0xf5fffa,
    'mistyrose': 0xffe4e1,
    'moccasin': 0xffe4b5,
    'navajowhite': 0xffdead,
    'navy': 0x000080,
    'oldlace': 0xfdf5e6,
    'olive': 0x808000,
    'olivedrab': 0x6b8e23,
    'orange': 0xffa500,
    'orangered': 0xff4500,
    'orchid': 0xda70d6,
    'palegoldenrod': 0xeee8aa,
    'palegreen': 0x98fb98,
    'paleturquoise': 0xafeeee,
    'palevioletred': 0xdb7093,
    'papayawhip': 0xffefd5,
    'peachpuff': 0xffdab9,
    'peru': 0xcd853f,
    'pink': 0xffc0cb,
    'plum': 0xdda0dd,
    'powderblue': 0xb0e0e6,
    'purple': 0x800080,
    'rebeccapurple': 0x663399,
    'red': 0xff0000,
    'rosybrown': 0xbc8f8f,
    'royalblue': 0x4169e1,
    'saddlebrown': 0x8b4513,
    'salmon': 0xfa8072,
    'sandybrown': 0xf4a460,
    'seagreen': 0x2e8b57,
    'seashell': 0xfff5ee,
    'sienna': 0xa0522d,
    'silver': 0xc0c0c0,
    'skyblue': 0x87ceeb,
    'slateblue': 0x6a5acd,
    'slategrey': 0x708090,
    'snow': 0xfffafa,
    'springgreen': 0x00ff7f,
    'steelblue': 0x4682b4,
    'tan': 0xd2b48c,
    'teal': 0x008080,
    'thistle': 0xd8bfd8,
    'tomato': 0xff6347,
    'turquoise': 0x40e0d0,
    'violet': 0xee82ee,
    'wheat': 0xf5deb3,
    'white': 0xffffff,
    'whitesmoke': 0xf5f5f5,
    'yellow': 0xffff00,
    'yellowgreen': 0x9acd32,
    'cream': 0xfffdd0,
  };
  static const _materials = {
    'brick': 0xae7764,
    'brique': 0xae7764,
    'stone': 0xb3a997,
    'pierre': 0xb3a997,
    'concrete': 0xa8a69e,
    'béton': 0xa8a69e,
    'glass': 0x91adb3,
    'metal': 0x949fa2,
    'steel': 0x949fa2,
    'wood': 0xaf9272,
    'timber': 0xaf9272,
    'bois': 0xaf9272,
    'plaster': 0xd1c6b7,
    'stucco': 0xd1c6b7,
    'tiles': 0xb4836b,
    'tile': 0xb4836b,
    'tuile': 0xb4836b,
    'slate': 0x717b84,
    'ardoise': 0x717b84,
    'copper': 0x81a59a,
    'thatch': 0xb5a477,
    'asphalt': 0x747477,
    'grass': 0x84936d,
    'sandstone': 0xc8b59a,
  };
  static int? _rgb(Object? value) {
    if (value is int) return value >= 0 && value <= 0xffffff ? value : null;
    if (value is! String) return null;
    final name = value.trim().toLowerCase();
    if (!RegExp(r'^#(?:[0-9a-f]{3}|[0-9a-f]{6})$').hasMatch(name)) {
      return _named[name.replaceAll('gray', 'grey').replaceAll(' ', '')];
    }
    var hex = name.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => c + c).join();
    return int.parse(hex, radix: 16);
  }

  factory BuildingAppearance.read({
    Object? wall,
    Object? roof,
    Object? wallMaterial,
    Object? roofMaterial,
  }) {
    String? material(Object? v) =>
        v is String && v.trim().isNotEmpty && v.length <= 64
        ? v.trim().toLowerCase()
        : null;
    return BuildingAppearance(
      wall: _rgb(wall),
      roof: _rgb(roof),
      wallMaterial: material(wallMaterial),
      roofMaterial: material(roofMaterial),
    );
  }
  factory BuildingAppearance.fromJson(Map data) => BuildingAppearance.read(
    wall: data['wall'],
    roof: data['roof'],
    wallMaterial: data['wallMaterial'],
    roofMaterial: data['roofMaterial'],
  );
  Map<String, Object> toJson() => {
    if (wall != null) 'wall': wall!,
    if (roof != null) 'roof': roof!,
    if (wallMaterial != null) 'wallMaterial': wallMaterial!,
    if (roofMaterial != null) 'roofMaterial': roofMaterial!,
  };
  bool get empty =>
      wall == null &&
      roof == null &&
      wallMaterial == null &&
      roofMaterial == null;
  BuildingAppearance fillFrom(BuildingAppearance other) => BuildingAppearance(
    wall: wall ?? other.wall,
    roof: roof ?? other.roof,
    wallMaterial: wallMaterial ?? other.wallMaterial,
    roofMaterial: roofMaterial ?? other.roofMaterial,
  );

  static const _walls = [
    0xb2a494,
    0xb99f91,
    0xa79e94,
    0x9ba7a8,
    0xa6ac99,
    0xc1b49d,
    0xbcb7ae,
  ];
  static const _roofs = [
    0xb5aca1,
    0xa59d96,
    0xaeaaa3,
    0x9ba7a9,
    0xa2a597,
    0xbba99b,
    0xb5b4b0,
  ];

  Color base({required bool top, required int seed, required bool dark}) {
    final rgb = top
        ? roof ?? _materials[roofMaterial] ?? _roofs[seed % _roofs.length]
        : wall ?? _materials[wallMaterial] ?? _walls[seed % _walls.length];
    final color = Color(0xff000000 | rgb);
    return dark ? Color.lerp(color, const Color(0xff263546), .48)! : color;
  }
}
