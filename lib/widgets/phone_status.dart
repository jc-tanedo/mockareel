import 'package:flutter/material.dart';

class PhoneStatus extends StatelessWidget {
  final String time;
  final Color color;
  const PhoneStatus({super.key, required this.time, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt, size: 14, color: color),
          const SizedBox(width: 5),
          Icon(Icons.wifi, size: 14, color: color),
          const SizedBox(width: 5),
          Icon(Icons.battery_full, size: 18, color: color),
        ],
      ),
    ),
  );
}
