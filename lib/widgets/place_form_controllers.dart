import 'package:flutter/material.dart';
import '../model/project.dart';

class PlaceFormControllers {
  final name = TextEditingController();
  final category = TextEditingController();
  final rating = TextEditingController();
  final address = TextEditingController();
  final localName = TextEditingController();
  final reviews = TextEditingController();
  final price = TextEditingController();
  final hours = TextEditingController();

  List<TextEditingController> get all => [
    name,
    category,
    rating,
    address,
    localName,
    reviews,
    price,
    hours,
  ];

  void populate(ReelPlace place) {
    name.text = place.name;
    category.text = place.category;
    rating.text = place.rating;
    address.text = place.address;
    localName.text = place.localName;
    reviews.text = place.reviewCount;
    price.text = place.price;
    hours.text = place.hours;
  }

  void saveTo(ReelPlace place) {
    place.name = name.text;
    place.category = category.text;
    place.rating = rating.text;
    place.address = address.text;
    place.localName = localName.text;
    place.reviewCount = reviews.text;
    place.price = price.text;
    place.hours = hours.text;
  }

  void dispose() {
    for (final c in all) {
      c.dispose();
    }
  }
}
