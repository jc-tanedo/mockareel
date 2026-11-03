import 'package:flutter/material.dart';
import 'phone_status.dart';

const _pink = Color(0xfffe2c55), _cyan = Color(0xff25f4ee);

class FeedChrome extends StatelessWidget {
  final String time, search;
  const FeedChrome({super.key, required this.time, this.search = ''});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              PhoneStatus(time: time),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.live_tv_outlined, size: 22),
                    const Text(
                      'Following',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Column(
                      children: [
                        const Text(
                          'For You',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(width: 25, height: 3, color: Colors.white),
                      ],
                    ),
                    const Icon(Icons.search, size: 25),
                  ],
                ),
              ),
              if (search.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 13),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          search,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 15),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 57,
        child: ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 6, 17, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _nav(Icons.home_filled, 'Home'),
                    _nav(Icons.people_outline, 'Friends'),
                    SizedBox(
                      width: 43,
                      height: 29,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 4,
                            top: 1,
                            bottom: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _cyan,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 0,
                            top: 1,
                            bottom: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _pink,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            top: 1,
                            bottom: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.black,
                                size: 25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _nav(Icons.chat_bubble_outline, 'Inbox'),
                    _nav(Icons.person_outline, 'Profile'),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _nav(IconData icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 22),
      Text(
        label,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
