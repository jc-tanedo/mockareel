import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../model/maps_web_result.dart';
import '../model/project.dart';
import '../services/maps_web_session.dart';
import '../widgets/place_search_dialog.dart';

class MapsWebSearchPage extends StatefulWidget {
  final String initial;
  final Future<String?> Function()? requestApiKey;
  final MapsLookupDriver? driver;
  final Widget? browserOverride;
  const MapsWebSearchPage({
    super.key,
    this.initial = '',
    this.requestApiKey,
    this.driver,
    this.browserOverride,
  }) : assert(driver == null || browserOverride != null);
  @override
  State<MapsWebSearchPage> createState() => _MapsWebSearchPageState();
}

class _MapsWebSearchPageState extends State<MapsWebSearchPage> {
  late final _query = TextEditingController(text: widget.initial);
  WebViewController? _controller;
  MapsLookupDriver? _driver;
  List<MapsWebResult> _results = [];
  MapsWebSnapshot? _details;
  bool _ready = false, _busy = false, _showBrowser = false;
  String? _message;
  String _status = 'Starting search…';
  int _operation = 0, _review = -1;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (widget.driver != null) {
        _driver = widget.driver;
      } else {
        if (kIsWeb ||
            !const [
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.macOS,
            ].contains(defaultTargetPlatform)) {
          throw const FormatException(
            'Key-free search needs a supported mobile WebView. You can use API lookup or edit the place manually.',
          );
        }
        _controller = WebViewController();
        _driver = MapsWebSession(
          _controller!,
          onStatus: (value) {
            if (mounted) setState(() => _status = value);
          },
        );
      }
      if (mounted) setState(() {});
      await _driver!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Search could not start. Check that Android System WebView is up to date, or use API lookup/manual editing.',
        );
      }
    }
  }

  void _apply(MapsWebSnapshot snapshot) {
    setState(() {
      _details = snapshot.place == null ? null : snapshot;
      _review = -1;
      if (snapshot.results.isNotEmpty) _results = snapshot.results;
      _message = snapshot.state == 'empty'
          ? 'No places found. Try a name and city.'
          : snapshot.state == 'interaction'
          ? 'Google needs your interaction. Show the browser to continue, then tap Read page.'
          : snapshot.place == null && snapshot.results.isEmpty
          ? 'No readable place yet. Try Read page after the browser finishes loading.'
          : null;
      _showBrowser = false;
    });
  }

  Future<void> _run(Future<MapsWebSnapshot> Function() action) async {
    if (!_ready || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final snapshot = await action();
      if (mounted && operation == _operation) _apply(snapshot);
    } catch (e) {
      if (mounted && operation == _operation) {
        setState(
          () => _message = e
              .toString()
              .replaceFirst('FormatException: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty || _busy || !_ready) return;
    setState(() {
      _results = [];
      _details = null;
      _showBrowser = false;
      _status = 'Searching Google Maps…';
    });
    await _run(() => _driver!.lookup(_query.text));
  }

  void _cancel() {
    _operation++;
    _driver?.cancel();
    setState(() {
      _busy = false;
      _message = 'Search cancelled. You can try another query.';
    });
  }

  Future<void> _select(MapsWebResult item) async {
    setState(() => _status = 'Reading place details…');
    await _run(() async {
      final snapshot = await _driver!.lookup(item.url, expectedName: item.name);
      // Search-card URLs can include an official Places ID and exact target
      // coordinates that the final listing URL has dropped during navigation.
      final hint = item.toPlace();
      snapshot.place?.placeId ??= hint.placeId;
      snapshot.place?.latitude ??= hint.latitude;
      snapshot.place?.longitude ??= hint.longitude;
      return snapshot;
    });
  }

  Future<void> _apiSearch() async {
    if (_busy || widget.requestApiKey == null) return;
    final key = await widget.requestApiKey!();
    if (!mounted || key == null || key.isEmpty) return;
    final place = await showDialog<PlaceDetails>(
      context: context,
      builder: (_) => PlaceSearchDialog(apiKey: key, initial: _query.text),
    );
    if (mounted && place != null) Navigator.pop(context, MapsWebImport(place));
  }

  @override
  void dispose() {
    _operation++;
    _driver?.dispose();
    _query.dispose();
    super.dispose();
  }

  Widget _place() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final detail = _details!, place = detail.place!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (place.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          place.category,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (place.rating.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xffffcc66),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            place.rating,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (place.reviewCount.isNotEmpty)
                      Text(
                        '${place.reviewCount} reviews',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final field in [
                  (Icons.place_outlined, place.address),
                  (Icons.schedule, place.hours),
                  (Icons.phone_outlined, place.phone),
                  (Icons.language, place.website),
                ])
                  if (field.$2.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(field.$1, size: 20, color: colors.primary),
                      title: Text(
                        field.$2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'All imported details remain editable.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Map header: capture a Google map without a key in Place → Header.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (detail.reviews.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Featured review',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Optional. Google may shorten the text; you can edit it after import.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: RadioGroup<int>(
              groupValue: _review,
              onChanged: (v) => setState(() => _review = v ?? -1),
              child: Column(
                children: [
                  const RadioListTile<int>(
                    value: -1,
                    title: Text('No featured review'),
                  ),
                  for (var i = 0; i < detail.reviews.length; i++)
                    RadioListTile<int>(
                      value: i,
                      title: Text(
                        detail.reviews[i].author.isEmpty
                            ? 'Review ${i + 1}'
                            : detail.reviews[i].author,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: Text(
                        '${detail.reviews[i].rating}/5',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        detail.reviews[i].text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _resultsView() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        if (_busy) ...[
          const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancel search'),
                ),
              ],
            ),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: _details != null
              ? _place()
              : _results.isNotEmpty
              ? ListView.builder(
                  itemCount: _results.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _results.length) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Results from Google Maps · Refine your search for more places.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final item = _results[i];
                    return ListTile(
                      enabled: !_busy,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.place_outlined,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      title: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (item.rating.isNotEmpty) '${item.rating}/5',
                          item.category,
                          item.address.isEmpty ? item.summary : item.address,
                        ].where((x) => x.isNotEmpty).join(' · '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _select(item),
                    );
                  },
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.travel_explore,
                            color: colors.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _busy ? 'Finding your place' : 'Find a place',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Search by name and city, or paste a Google Maps share link. No API key needed.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: _details != null && _results.isNotEmpty && !_showBrowser
            ? IconButton(
                tooltip: 'Back to search results',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _details = null;
                  _review = -1;
                }),
              )
            : null,
        title: const Text('Google Maps'),
        actions: [
          if (_details != null && !_busy)
            IconButton(
              tooltip: 'Refresh place details',
              onPressed: () => _run(() => _driver!.readPage()),
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: _showBrowser ? 'Hide browser' : 'Show browser',
            onPressed: _ready
                ? () => setState(() => _showBrowser = !_showBrowser)
                : null,
            icon: Icon(
              _showBrowser
                  ? Icons.visibility_off_outlined
                  : Icons.open_in_browser,
            ),
          ),
          if (widget.requestApiKey != null)
            PopupMenuButton<String>(
              onSelected: (_) => _apiSearch(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'api',
                  child: Text('Use API lookup'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KEY-FREE SEARCH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _query,
                  enabled: !_busy,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Place and city, or Google Maps link',
                    prefixIcon: const Icon(Icons.place_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Search Google Maps',
                      onPressed: _ready && !_busy ? _search : null,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, size) => Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (_controller != null || widget.browserOverride != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: _showBrowser ? size.maxWidth : 1000,
                      height: _showBrowser ? size.maxHeight : 800,
                      child: ExcludeSemantics(
                        excluding: !_showBrowser,
                        child: IgnorePointer(
                          ignoring: !_showBrowser,
                          child:
                              widget.browserOverride ??
                              WebViewWidget(controller: _controller!),
                        ),
                      ),
                    ),
                  if (!_showBrowser)
                    Positioned.fill(
                      child: Material(
                        color: colors.surface,
                        child: _resultsView(),
                      ),
                    ),
                  if (_showBrowser)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton.icon(
                          onPressed: _ready && !_busy
                              ? () => _run(() => _driver!.readPage())
                              : null,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Read page'),
                        ),
                      ),
                    ),
                  if (!_showBrowser && _details != null && !_busy)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: SafeArea(
                        top: false,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(
                            context,
                            MapsWebImport(
                              _details!.place!,
                              review: _review < 0
                                  ? null
                                  : _details!.reviews[_review],
                            ),
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Use this place'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
