enum HomeOs {
  iphone('iPhone · Classic iOS', 28, 17),
  android('Android', 324, 25),
  pixel('Google Pixel', 434, 22),
  oneUi('Samsung · One UI', 444, 16);

  final String label;
  final double iconTop, iconRadius;
  const HomeOs(this.label, this.iconTop, this.iconRadius);
}
