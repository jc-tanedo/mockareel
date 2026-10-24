import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
