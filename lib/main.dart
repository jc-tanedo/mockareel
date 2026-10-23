import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MockareelApp());

const ink = Color(0xFF0A1018);
const panel = Color(0xFF111B27);
const mint = Color(0xFF55E3C0);

class MockareelApp extends StatelessWidget {
  const MockareelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mockareel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: ColorScheme.fromSeed(
              seedColor: mint, brightness: Brightness.dark),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF182432),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        home: const EditorPage(),
      );
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _picker = ImagePicker();
  final _name = TextEditingController(text: 'Kura Sushi Nishishinjuku');
  final _subtitle =
      TextEditingController(text: 'Conveyor belt sushi · Japanese restaurant');
  final _rating = TextEditingController(text: '4.6');
  final _address = TextEditingController(text: 'Shinjuku, Tokyo, Japan');
  final List<XFile> _media = [];
  final List<double> _durations = [3.5, 3.5, 4, 3.5, 4];
  int _tab = 0;
  int _selected = 0;
  bool _saved = false;
  static const _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('draft');
    if (value == null || !mounted) return;
    final data = jsonDecode(value) as Map<String, dynamic>;
    setState(() {
      final place = data['place'] as Map<String, dynamic>? ?? data;
      _name.text = place['name'] as String? ?? _name.text;
      _subtitle.text = place['subtitle'] as String? ?? _subtitle.text;
      _rating.text = place['rating'] as String? ?? _rating.text;
      _address.text = place['address'] as String? ?? _address.text;
      _durations.setAll(
          0,
          ((data['clipDurationsSeconds'] ?? data['durations'])
                      as List<dynamic>? ??
                  [])
              .map((e) => (e as num).toDouble())
              .take(5));
      _media.addAll((data['media'] as List<dynamic>? ?? [])
          .whereType<String>()
          .map(XFile.new));
    });
  }

  Map<String, Object> _project() => {
        'template': 'Google Maps Place Story',
        'version': 1,
        'place': {
          'name': _name.text,
          'subtitle': _subtitle.text,
          'rating': _rating.text,
          'address': _address.text
        },
        'clipDurationsSeconds': _durations,
        'media': _media.map((f) => f.path).toList(),
        'format': '9:16',
        'createdAt': DateTime.now().toIso8601String(),
      };

  Future<void> _save() async {
    final p = _project();
    await (await SharedPreferences.getInstance())
        .setString('draft', jsonEncode(p));
    if (mounted) setState(() => _saved = true);
    _toast('Project saved on this device');
  }

  Future<void> _pickMedia() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isNotEmpty && mounted) {
      setState(() {
        _media.addAll(files);
        _selected = _media.length - 1;
      });
    }
  }

  Future<void> _findPlace() async {
    if (_mapsApiKey.isEmpty) {
      final q = Uri.encodeComponent(
          _name.text.isEmpty ? 'restaurants near me' : _name.text);
      await launchUrl(
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
          mode: LaunchMode.externalApplication);
      if (mounted) {
        _toast('Add a Places API key to enable in-app search and autofill.');
      }
      return;
    }
    final query = TextEditingController(text: _name.text);
    List<Map<String, dynamic>> results = [];
    bool loading = false;
    String? error;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, refresh) => AlertDialog(
                  backgroundColor: panel,
                  title: const Text('Find a place'),
                  content: SizedBox(
                      width: 420,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: query,
                            autofocus: true,
                            decoration: InputDecoration(
                                hintText: 'Search places',
                                suffixIcon: IconButton(
                                    onPressed: loading
                                        ? null
                                        : () async {
                                            refresh(() {
                                              loading = true;
                                              error = null;
                                            });
                                            try {
                                              final response = await http.post(
                                                  Uri.https(
                                                      'places.googleapis.com',
                                                      '/v1/places:autocomplete'),
                                                  headers: {
                                                    'Content-Type':
                                                        'application/json',
                                                    'X-Goog-Api-Key':
                                                        _mapsApiKey
                                                  },
                                                  body: jsonEncode(
                                                      {'input': query.text}));
                                              if (response.statusCode != 200) {
                                                throw Exception(
                                                    'Places search returned ${response.statusCode}. Check API key and Places API access.');
                                              }
                                              results = ((jsonDecode(
                                                                  response.body)[
                                                              'suggestions']
                                                          as List<dynamic>? ??
                                                      [])
                                                  .where((e) => (e as Map<
                                                          String, dynamic>)
                                                      .containsKey(
                                                          'placePrediction'))
                                                  .map((e) => e['placePrediction']
                                                      as Map<String, dynamic>)
                                                  .toList());
                                            } catch (e) {
                                              error = e.toString().replaceFirst(
                                                  'Exception: ', '');
                                            }
                                            refresh(() {
                                              loading = false;
                                            });
                                          },
                                    icon:
                                        const Icon(Icons.search, color: mint))),
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus()),
                        if (loading)
                          const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(color: mint)),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(error!,
                                  style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 12))),
                        if (!loading && results.isNotEmpty)
                          ...results.map((item) {
                            final structured = item['structuredFormat']
                                    as Map<String, dynamic>? ??
                                {};
                            final main = (structured['mainText']
                                        as Map<String, dynamic>?)?['text']
                                    as String? ??
                                '';
                            final secondary = (structured['secondaryText']
                                        as Map<String, dynamic>?)?['text']
                                    as String? ??
                                '';
                            return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.location_on_outlined,
                                    color: mint),
                                title: Text(main,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(secondary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                onTap: () async {
                                  final placeId = item['placeId'] as String?;
                                  if (placeId == null) return;
                                  Navigator.pop(dialogContext);
                                  await _loadPlace(placeId);
                                });
                          }),
                        if (!loading && results.isEmpty && error == null)
                          const Padding(
                              padding: EdgeInsets.only(top: 14),
                              child: Text(
                                  'Search for a place to see matching results.',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12))),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'))
                  ],
                )));
    query.dispose();
  }

  Future<void> _loadPlace(String placeId) async {
    try {
      final response = await http.get(
          Uri.https('places.googleapis.com', '/v1/places/$placeId',
              {'languageCode': 'en'}),
          headers: {
            'X-Goog-Api-Key': _mapsApiKey,
            'X-Goog-FieldMask':
                'displayName,formattedAddress,shortFormattedAddress,rating,primaryTypeDisplayName'
          });
      if (response.statusCode != 200) {
        throw Exception('Place details returned ${response.statusCode}.');
      }
      final place = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name.text = (place['displayName'] as Map<String, dynamic>?)?['text']
                as String? ??
            _name.text;
        _subtitle.text = (place['primaryTypeDisplayName']
                as Map<String, dynamic>?)?['text'] as String? ??
            _subtitle.text;
        _rating.text =
            (place['rating'] as num?)?.toStringAsFixed(1) ?? _rating.text;
        _address.text = place['shortFormattedAddress'] as String? ??
            place['formattedAddress'] as String? ??
            _address.text;
      });
      _toast('Place details added. Edit any field below.');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _export() async {
    await Share.share(const JsonEncoder.withIndent('  ').convert(_project()),
        subject: 'My Mockareel project');
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Column(children: [
        _topBar(),
        Expanded(
            child: IndexedStack(index: _tab, children: [
          _editTab(),
          _cardsTab(),
          _scrollTab(),
          _exportTab()
        ])),
        _bottomNav(),
      ])),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: Column(children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: mint.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.location_on_rounded,
                    color: mint, size: 21)),
            const SizedBox(width: 10),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Google Maps Place',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('STORY STUDIO  ·  9:16 VERTICAL',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          letterSpacing: 1.2))
                ])),
            IconButton(
                onPressed: _save,
                icon: Icon(
                    _saved ? Icons.cloud_done_rounded : Icons.save_outlined,
                    color: mint)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _findPlace,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Find a place'),
                    style: _outlineButton())),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Export project'),
                    style: FilledButton.styleFrom(
                        backgroundColor: mint, foregroundColor: ink))),
          ]),
        ]),
      );

  ButtonStyle _outlineButton() => OutlinedButton.styleFrom(
      foregroundColor: mint,
      side: BorderSide(color: mint.withValues(alpha: .4)),
      visualDensity: VisualDensity.compact);

  Widget _editTab() =>
      ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 24), children: [
        _preview(),
        const SizedBox(height: 18),
        _sectionTitle('PLACE DETAILS', 'Edit any field'),
        const SizedBox(height: 12),
        _field('Place name', _name, Icons.place_outlined),
        const SizedBox(height: 9),
        _field('Category & description', _subtitle, Icons.short_text_rounded),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
              child: _field('Rating', _rating, Icons.star_outline_rounded,
                  keyboard: TextInputType.number)),
          const SizedBox(width: 9),
          Expanded(child: _field('Location', _address, Icons.map_outlined))
        ]),
        const SizedBox(height: 18),
        _sectionTitle('YOUR MEDIA', '${_media.length} clips'),
        const SizedBox(height: 10),
        _uploadCard(),
        if (_media.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(_media.length, (i) => _mediaTile(i)),
        ],
      ]);

  Widget _preview() => Container(
        height: 245,
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF214A51),
                  Color(0xFF152A36),
                  Color(0xFF35253B)
                ]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
              top: -25,
              right: -5,
              child: Icon(Icons.ramen_dining,
                  size: 210, color: Colors.white.withValues(alpha: .06))),
          Positioned(
              left: 20,
              top: 24,
              child: _chip(Icons.location_on, 'PLACE PREVIEW')),
          Positioned(
              top: 22, right: 18, child: _chip(Icons.aspect_ratio, '9:16')),
          Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF101820).withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  _name.text.isEmpty
                                      ? 'Your place name'
                                      : _name.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold))),
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFFC857), size: 17),
                          Text(' ${_rating.text}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700))
                        ]),
                        const SizedBox(height: 4),
                        Text(
                            _subtitle.text.isEmpty
                                ? 'Category and description'
                                : _subtitle.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 10),
                        Row(children: [
                          for (final pair in const [
                            (Icons.directions, 'Directions'),
                            (Icons.restaurant, 'Menu'),
                            (Icons.call, 'Call'),
                            (Icons.bookmark_border, 'Save')
                          ])
                            Expanded(
                                child: Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                        color: mint.withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(pair.$1, size: 12, color: mint),
                                          const SizedBox(width: 3),
                                          Flexible(
                                              child: Text(pair.$2,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      color: mint)))
                                        ])))
                        ]),
                        const SizedBox(height: 8),
                        Text(_address.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ]))),
        ]),
      );

  Widget _chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: ink.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(icon, size: 12, color: mint),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 9, letterSpacing: .8))
      ]));
  Widget _sectionTitle(String title, String trailing) => Row(children: [
        Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Text(trailing, style: const TextStyle(fontSize: 10, color: mint))
      ]);
  Widget _field(String label, TextEditingController controller, IconData icon,
          {TextInputType? keyboard}) =>
      TextField(
          controller: controller,
          keyboardType: keyboard,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, size: 18, color: mint),
              labelStyle: const TextStyle(fontSize: 12)));

  Widget _uploadCard() => InkWell(
      onTap: _pickMedia,
      borderRadius: BorderRadius.circular(18),
      child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: mint.withValues(alpha: .25))),
          child: Row(children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: mint.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: mint)),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Add videos & photos',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('Choose multiple clips from your library',
                      style: TextStyle(color: Colors.white54, fontSize: 11))
                ])),
            const Icon(Icons.add_circle_outline, color: mint)
          ])));

  Widget _mediaTile(int i) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Container(
            width: 35,
            height: 38,
            decoration: BoxDecoration(
                color: const Color(0xFF253642),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(
                _media[i].mimeType?.startsWith('video') == true
                    ? Icons.play_arrow_rounded
                    : Icons.image_outlined,
                color: mint,
                size: 19)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_media[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
        IconButton(
            onPressed: () => setState(() => _media.removeAt(i)),
            icon: const Icon(Icons.close, size: 17, color: Colors.white54)),
        const Text('SEC', style: TextStyle(fontSize: 9, color: Colors.white54)),
        SizedBox(
            width: 88,
            child: Slider(
                value: _durations[i % 5],
                min: 1,
                max: 8,
                divisions: 14,
                activeColor: mint,
                onChanged: (v) => setState(() => _durations[i % 5] = v)))
      ]));

  Widget _cardsTab() => ListView(padding: const EdgeInsets.all(18), children: [
        _sectionTitle('STORY CARDS', '5 cards · 9:16'),
        const SizedBox(height: 12),
        for (int i = 0; i < 5; i++)
          Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: i == _selected
                          ? mint.withValues(alpha: .4)
                          : Colors.white10)),
              child: Row(children: [
                CircleAvatar(
                    radius: 15,
                    backgroundColor: mint.withValues(alpha: .12),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: mint, fontSize: 12))),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        [
                          'Sushi plates',
                          'Nigiri close-up',
                          'Salmon & ikura',
                          'Conveyor belt',
                          'Shinjuku table'
                        ][i],
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${_durations[i].toStringAsFixed(1)}s',
                    style: const TextStyle(color: mint, fontSize: 12))
              ])),
        const SizedBox(height: 10),
        _uploadCard(),
      ]);

  Widget _scrollTab() => ListView(padding: const EdgeInsets.all(18), children: [
        _sectionTitle('LEFT-SCROLL STORY',
            '5 cards · ${_durations.fold<double>(0, (a, b) => a + b).toStringAsFixed(1)}s'),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
                color: panel, borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Card timing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text('Adjust how long each scene stays on screen.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 18),
              for (int i = 0; i < 5; i++)
                Column(children: [
                  Row(children: [
                    Text('CARD ${i + 1}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 1)),
                    const Spacer(),
                    Text('${_durations[i].toStringAsFixed(1)} sec',
                        style: const TextStyle(
                            color: mint, fontWeight: FontWeight.w700))
                  ]),
                  Slider(
                      value: _durations[i],
                      min: 1,
                      max: 8,
                      divisions: 14,
                      activeColor: mint,
                      onChanged: (v) => setState(() => _durations[i] = v))
                ])
            ])),
      ]);

  Widget _exportTab() => ListView(padding: const EdgeInsets.all(18), children: [
        _sectionTitle('EXPORT YOUR REEL', '9:16 VERTICAL'),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: panel, borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.movie_creation_outlined, color: mint, size: 30),
              const SizedBox(height: 12),
              const Text('Your story is ready to shape',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                  '${_media.length} media clips · ${_durations.fold<double>(0, (a, b) => a + b).toStringAsFixed(1)} seconds · ${_name.text}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 18),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: _export,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Export project file'),
                      style: FilledButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: ink,
                          padding: const EdgeInsets.all(14)))),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save project on device'),
                      style: _outlineButton().copyWith(
                          padding: const WidgetStatePropertyAll(
                              EdgeInsets.all(13)))))
            ])),
        const SizedBox(height: 12),
        const Text(
            'Project export keeps your place details and timing so you can pick up editing later. Media files stay in your device library.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
      ]);

  Widget _bottomNav() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
        decoration: const BoxDecoration(
            color: Color(0xFF0E1620),
            border: Border(top: BorderSide(color: Colors.white10))),
        child: Row(children: [
          for (final entry in [
            (Icons.tune_rounded, 'Edit', 0),
            (Icons.dashboard_customize_outlined, 'Cards', 1),
            (Icons.view_carousel_outlined, 'Scroll', 2),
            (Icons.ios_share_outlined, 'Export', 3)
          ])
            Expanded(
                child: InkWell(
              onTap: () => setState(() => _tab = entry.$3),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(entry.$1,
                        size: 19,
                        color: _tab == entry.$3 ? mint : Colors.white54),
                    const SizedBox(height: 4),
                    Text(entry.$2,
                        style: TextStyle(
                            fontSize: 10,
                            color: _tab == entry.$3 ? mint : Colors.white54)),
                  ])),
            )),
        ]),
      );

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    _rating.dispose();
    _address.dispose();
    super.dispose();
  }
}
