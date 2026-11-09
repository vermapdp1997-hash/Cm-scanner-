import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Ads init: $e");
  }
  runApp(const BharatScannerApp());
}

class BharatScannerApp extends StatelessWidget {
  const BharatScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat Scanner Pro AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF004D40),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// 1. SPLASH SCREEN
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  late Animation<double> _f;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _s = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _f = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _c.forward();

    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainDashboardScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      body: Center(
        child: FadeTransition(
          opacity: _f,
          child: ScaleTransition(
            scale: _s,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.document_scanner_rounded, size: 60, color: Color(0xFF00796B)),
                ),
                const SizedBox(height: 18),
                const Text('BHARAT SCANNER PRO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(45), borderRadius: BorderRadius.circular(20)),
                  child: const Text('⚡ AI Studio & Office Suite', style: TextStyle(color: Color(0xFFB2DFDB), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. MAIN DASHBOARD
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _savedDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  bool _isSearching = false;
  bool _isGridView = false;
  String _selectedCategory = 'All';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  String get _bannerId => kReleaseMode ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/6300978111';
  String get _interstitialId => kReleaseMode ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _loadSavedDocs();
    _loadBannerAd();
    _loadInterstitialAd();
    _searchController.addListener(_filterDocs);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) => _interstitialAd = null,
      ),
    );
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString('saved_documents_v2');
    if (rawData != null && mounted) {
      final List decoded = jsonDecode(rawData);
      setState(() {
        _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _filterDocs();
      });
    }
  }

  Future<void> _commitDocsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents_v2', jsonEncode(_savedDocs));
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final matchesSearch = (doc['title'] ?? '').toString().toLowerCase().contains(q);
        final matchesCat = _selectedCategory == 'All' ||
            (_selectedCategory == 'Starred' ? (doc['isFavorite'] == true) : doc['category'] == _selectedCategory);
        return matchesSearch && matchesCat;
      }).toList();

      if (_sortAscending) {
        _filteredDocs.sort((a, b) => (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
      } else {
        _filteredDocs.sort((a, b) => (b['id'] ?? '').toString().compareTo((a['id'] ?? '').toString()));
      }
    });
  }

  Future<void> _toggleFavorite(String id) async {
    final idx = _savedDocs.indexWhere((d) => d['id'] == id);
    if (idx != -1) {
      setState(() {
        _savedDocs[idx]['isFavorite'] = !(_savedDocs[idx]['isFavorite'] ?? false);
        _filterDocs();
      });
      await _commitDocsToPrefs();
    }
  }

  Future<void> _saveDocToStorage(String title, List<String> rawPaths, {String category = 'Documents'}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);

    List<String> persistentPaths = [];
    for (int i = 0; i < rawPaths.length; i++) {
      final temp = File(rawPaths[i]);
      if (await temp.exists()) {
        final saved = await temp.copy('${scansDir.path}/doc_${DateTime.now().millisecondsSinceEpoch}_p$i.jpg');
        persistentPaths.add(saved.path);
      }
    }

    if (persistentPaths.isEmpty) {
      _showToast('Failed to save scanned files.');
      return;
    }

    final newDoc = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title.isEmpty ? 'Doc_${DateFormat('ddMMM_HHmm').format(DateTime.now())}' : title,
      'category': category,
      'isFavorite': false,
      'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      'images': persistentPaths,
      'pages': persistentPaths.length,
    };

    setState(() {
      _savedDocs.insert(0, newDoc);
      _filterDocs();
    });
    await _commitDocsToPrefs();
    _showToast('✅ Saved to $category');
  }

  Future<void> _deleteDoc(String id) async {
    final doc = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (doc.isNotEmpty && doc['images'] != null) {
      for (String p in doc['images']) {
        final f = File(p);
        if (await f.exists()) await f.delete();
      }
    }
    setState(() {
      _savedDocs.removeWhere((item) => item['id'] == id);
      _filterDocs();
    });
    await _commitDocsToPrefs();
    _showToast('Document deleted permanently');
  }

  Future<void> _startDocScan({int limit = 50, String category = 'Documents', String prefix = 'Doc'}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: limit),
    );
    try {
      final result = await scanner.scanDocument();
      if (!mounted || result?.images == null || result!.images.isEmpty) return;

      if (category == 'ID Cards' && result.images.length >= 2) {
        _processIdCardCollage(result.images.sublist(0, 2), prefix);
      } else {
        _promptDocName(result.images, prefix, category);
      }
    } catch (e) {
      debugPrint("Scan Err: $e");
    }
  }

  Future<void> _processIdCardCollage(List<String> cards, String prefix) async {
    try {
      final frontBytes = await File(cards[0]).readAsBytes();
      final backBytes = await File(cards[1]).readAsBytes();
      final fImg = (await (await ui.instantiateImageCodec(frontBytes)).getNextFrame()).image;
      final bImg = (await (await ui.instantiateImageCodec(backBytes)).getNextFrame()).image;

      const w = 1240.0;
      const h = 1754.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

      const cardW = 750.0;
      const cardH = 470.0;
      const left = (w - cardW) / 2;
      final bPaint = Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.stroke..strokeWidth = 2.0;

      final r1 = const Rect.fromLTWH(left, 200, cardW, cardH);
      canvas.drawImageRect(fImg, Rect.fromLTWH(0, 0, fImg.width.toDouble(), fImg.height.toDouble()), r1, Paint());
      canvas.drawRect(r1, bPaint);

      final r2 = const Rect.fromLTWH(left, 820, cardW, cardH);
      canvas.drawImageRect(bImg, Rect.fromLTWH(0, 0, bImg.width.toDouble(), bImg.height.toDouble()), r2, Paint());
      canvas.drawRect(r2, bPaint);

      final picture = recorder.endRecording();
      final collage = await picture.toImage(w.toInt(), h.toInt());
      final byteData = await collage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final file = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        await _saveDocToStorage('ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}', [file.path], category: 'ID Cards');
      }
    } catch (e) {
      if (mounted) _promptDocName(cards, prefix, 'ID Cards');
    }
  }

  void _promptDocName(List<String> images, String prefix, String category) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Document Name', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveDocToStorage(nameCtrl.text.trim(), images, category: category);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openCompressionDialog(List<dynamic> images, String title) {
    double scale = 0.5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Compress Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Compression Scale: ${(scale * 100).toInt()}%'),
              Slider(
                value: scale, min: 0.1, max: 1.0, divisions: 9,
                activeColor: const Color(0xFF00796B),
                onChanged: (v) => setDState(() => scale = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _exportPdf(images, "${title}_Compressed", scale: scale);
              },
              child: const Text('Export PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImages(List images, String title) async {
    List<XFile> files = [];
    for (var p in images) {
      final f = File(p);
      if (await f.exists()) files.add(XFile(f.path));
    }
    if (files.isNotEmpty) {
      await Share.shareXFiles(files, text: '$title - Bharat Scanner Pro');
    }
  }

  Future<void> _exportPdf(List images, String title, {double scale = 1.0, String? watermark}) async {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }

    final pdf = pw.Document();
    for (var path in images) {
      final f = File(path);
      if (await f.exists()) {
        Uint8List finalBytes;
        if (scale < 1.0) {
          final raw = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(raw, targetWidth: (1200 * scale).toInt().clamp(350, 2000));
          final frame = await codec.getNextFrame();
          final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          finalBytes = resized != null ? resized.buffer.asUint8List() : raw;
        } else {
          finalBytes = await f.readAsBytes();
        }

        final img = pw.MemoryImage(finalBytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) => pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                if (watermark != null && watermark.isNotEmpty)
                  pw.Center(
                    child: pw.Transform.rotate(
                      angle: -0.6,
                      child: pw.Text(watermark, style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0x35000000))),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Scanner Pro');
  }

  Future<void> _extractTextWithAI(String imagePath) async {
    String text = '';
    try {
      final recognizer = TextRecognizer();
      final res = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      await recognizer.close();
      text = res.text;
    } catch (_) {}

    if (!mounted || text.trim().isEmpty) {
      _showToast('No readable text detected.');
      return;
    }

    final ctrl = TextEditingController(text: text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AI OCR Extracted Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.copy), onPressed: () {
                  Clipboard.setData(ClipboardData(text: ctrl.text));
                  _showToast('Copied to clipboard!');
                }),
              ],
            ),
            TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share Text'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () => Share.share(ctrl.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWatermarkDialog() {
    if (_savedDocs.isEmpty) return _showToast('Scan a document first.');
    String docId = _savedDocs.first['id'];
    final wmCtrl = TextEditingController(text: 'CONFIDENTIAL');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add PDF Watermark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: docId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _savedDocs.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['title'], overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => docId = v!,
            ),
            const SizedBox(height: 10),
            TextField(controller: wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final chosen = _savedDocs.firstWhere((d) => d['id'] == docId);
              _exportPdf(chosen['images'], "${chosen['title']}_Watermarked", watermark: wmCtrl.text.trim());
            },
            child: const Text('Apply & Share'),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF00796B)));
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(controller: _searchController, autofocus: true, decoration: const InputDecoration(hintText: 'Search...', border: InputBorder.none))
            : const Text('BHARAT SCANNER PRO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF004D40))),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab()),
          if (_isBannerLoaded && _bannerAd != null)
            SafeArea(child: SizedBox(width: _bannerAd!.size.width.toDouble(), height: _bannerAd!.size.height.toDouble(), child: AdWidget(ad: _bannerAd!))),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => _startDocScan(),
        child: const Icon(Icons.camera_alt_rounded, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: Icon(Icons.folder, color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey), onPressed: () => setState(() => _currentTabIndex = 0)),
            const SizedBox(width: 40),
            IconButton(icon: Icon(Icons.widgets, color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey), onPressed: () => setState(() => _currentTabIndex = 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Saved Files (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                IconButton(icon: Icon(_sortAscending ? Icons.sort_by_alpha : Icons.access_time), onPressed: () => setState(() { _sortAscending = !_sortAscending; _filterDocs(); })),
                IconButton(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _isGridView = !_isGridView)),
              ],
            ),
          ],
        ),
        if (_filteredDocs.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: Text("No documents found. Tap Camera to scan!")))
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75),
            itemBuilder: (ctx, i) => _buildGridCard(_filteredDocs[i]),
          )
        else
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) => _buildListCard(_filteredDocs[i]),
          ),
      ],
    );
  }

  Widget _buildListCard(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();
    final isFav = doc['isFavorite'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: hasImg ? Image.file(File(imgs.first), width: 50, height: 60, fit: BoxFit.cover) : const Icon(Icons.broken_image),
        title: Text(doc['title'] ?? 'Untitled', maxLines: 1),
        subtitle: Text('${doc['pages']} pages • ${doc['date']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : Colors.grey), onPressed: () => _toggleFavorite(doc['id'])),
            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF2E7D32)), onPressed: () => _exportPdf(imgs, doc['title'])),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteDoc(doc['id'])),
          ],
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(
          doc: doc,
          onDelete: () => _deleteDoc(doc['id']),
          onDocUpdated: (u) async {
            final idx = _savedDocs.indexWhere((d) => d['id'] == u['id']);
            if (idx != -1) { setState(() { _savedDocs[idx] = u; _filterDocs(); }); await _commitDocsToPrefs(); }
          },
          onExtractText: (p) => _extractTextWithAI(p),
          onSharePdf: (p, t) => _exportPdf(p, t),
        ))),
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();

    return Card(
      child: Column(
        children: [
          Expanded(child: hasImg ? Image.file(File(imgs.first), width: double.infinity, fit: BoxFit.cover) : const Center(child: Icon(Icons.broken_image))),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(doc['title'] ?? 'Untitled', maxLines: 1)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => _deleteDoc(doc['id'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85,
      children: [
        _buildToolBtn('ID Card A4', Icons.badge, Colors.blue, () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card')),
        _buildToolBtn('Single Card', Icons.credit_card, Colors.teal, () => _startDocScan(limit: 1, category: 'ID Cards', prefix: 'Card')),
        _buildToolBtn('Passport Photo', Icons.portrait, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
        _buildToolBtn('Digital Sign', Icons.draw, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
        _buildToolBtn('Photo Studio', Icons.rotate_right, Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
        _buildToolBtn('Watermark', Icons.branding_watermark, Colors.amber.shade900, () => _openWatermarkDialog()),
        _buildToolBtn('GST Invoice', Icons.receipt_long, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
        _buildToolBtn('Resume Maker', Icons.assignment_ind, Colors.lightBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
        _buildToolBtn('Smart Notes', Icons.note_alt, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen()))),
      ],
    );
  }

  Widget _buildToolBtn(String title, IconData icon, Color col, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: col.withAlpha(25), child: Icon(icon, color: col, size: 22)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// 3. DOCUMENT DETAIL SCREEN
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Function(String) onExtractText;
  final Function(List, String) onSharePdf;

  const DocumentDetailScreen({super.key, required this.doc, required this.onDelete, required this.onDocUpdated, required this.onExtractText, required this.onSharePdf});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late List<String> _images;
  int _currentPage = 0;
  final PageController _controller = PageController();

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
  }

  Future<void> _applyFilter(int mode) async {
    if (_images.isEmpty) return;
    ColorFilter? filter;
    if (mode == 1) {
      filter = const ColorFilter.matrix([1.2, 0, 0, 0, -10, 0, 1.2, 0, 0, -10, 0, 0, 1.2, 0, -10, 0, 0, 0, 1, 0]);
    } else if (mode == 2) {
      filter = const ColorFilter.matrix([1.5, 1.5, 1.5, 0, -160, 1.5, 1.5, 1.5, 0, -160, 1.5, 1.5, 1.5, 0, -160, 0, 0, 0, 1, 0]);
    }

    if (filter == null) return;
    final file = File(_images[_currentPage]);
    final bytes = await file.readAsBytes();
    final img = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
    canvas.drawImage(img, Offset.zero, Paint()..colorFilter = filter);
    final output = await recorder.endRecording().toImage(img.width, img.height);
    final byteData = await output.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/scans/flt_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());
      setState(() => _images[_currentPage] = newFile.path);
      widget.doc['images'] = _images;
      widget.onDocUpdated(widget.doc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text(widget.doc['title'] ?? 'Document'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_vintage, color: Colors.tealAccent),
            onSelected: _applyFilter,
            itemBuilder: (_) => const [PopupMenuItem(value: 1, child: Text('Magic Color')), PopupMenuItem(value: 2, child: Text('High Contrast B&W'))],
          ),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => widget.onSharePdf(_images, widget.doc['title'] ?? 'Doc')),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _images.length,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (_, i) => InteractiveViewer(child: Center(child: Image.file(File(_images[i])))),
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('Page ${_currentPage + 1} of ${_images.length}', style: const TextStyle(color: Colors.white)),
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome, color: Colors.tealAccent),
              label: const Text('OCR Text', style: TextStyle(color: Colors.tealAccent)),
              onPressed: () => widget.onExtractText(_images[_currentPage]),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. DIGITAL SIGNATURE STUDIO (Auto-Trim Transparent PNG)
class DigitalSignatureScreen extends StatefulWidget {
  const DigitalSignatureScreen({super.key});
  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final List<Offset?> _points = [];
  Color _penColor = Colors.black;

  Future<void> _saveSignature() async {
    final valid = _points.whereType<Offset>().toList();
    if (valid.isEmpty) return;

    double minX = valid.first.dx, maxX = valid.first.dx, minY = valid.first.dy, maxY = valid.first.dy;
    for (var p in valid) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    const pad = 20.0;
    minX = (minX - pad).clamp(0, 5000);
    minY = (minY - pad).clamp(0, 5000);
    final w = (maxX - minX + (pad * 2)).clamp(50.0, 5000.0);
    final h = (maxY - minY + (pad * 2)).clamp(50.0, 5000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.translate(-minX, -minY);

    final paint = Paint()..color = _penColor..strokeCap = StrokeCap.round..strokeWidth = 4.0;
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
    }

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Signature_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'Transparent Signature PNG');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature'),
        actions: [
          IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _points.clear())),
          IconButton(icon: const Icon(Icons.check, color: Color(0xFF00796B)), onPressed: _saveSignature),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() => _points.add((context.findRenderObject() as RenderBox).globalToLocal(d.globalPosition))),
          onPanEnd: (_) => _points.add(null),
          child: CustomPaint(painter: _SignPainter(points: _points, color: _penColor), size: Size.infinite),
        ),
      ),
    );
  }
}

class _SignPainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  _SignPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeCap = StrokeCap.round..strokeWidth = 3.5;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 5. PASSPORT PHOTO STUDIO (8 & 16 Toggle)
class PassportPhotoStudioScreen extends StatefulWidget {
  const PassportPhotoStudioScreen({super.key});
  @override
  State<PassportPhotoStudioScreen> createState() => _PassportPhotoStudioScreenState();
}

class _PassportPhotoStudioScreenState extends State<PassportPhotoStudioScreen> {
  String? _path;
  int _count = 8;

  Future<void> _capture() async {
    final s = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
    final res = await s.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) setState(() => _path = res.images.first);
  }

  Future<void> _exportPdf() async {
    if (_path == null) return;
    final pdf = pw.Document();
    final passImage = pw.MemoryImage(await File(_path!).readAsBytes());
    final w = _count == 8 ? 115.0 : 85.0;
    final h = _count == 8 ? 150.0 : 110.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          children: [
            pw.Header(level: 0, text: 'Passport Photos Print Sheet ($_count Photos)'),
            pw.Wrap(
              spacing: 12, runSpacing: 14,
              children: List.generate(_count, (_) => pw.Container(width: w, height: h, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Image(passImage, fit: pw.BoxFit.cover))),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/Passport_Sheet_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await f.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(f.path)], text: 'Passport Photos Print PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Maker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150, height: 190,
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey)),
              child: _path != null ? Image.file(File(_path!), fit: BoxFit.cover) : const Icon(Icons.portrait, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _capture, child: const Text('Capture / Pick Photo')),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 8, label: Text('8 Photos')), ButtonSegment(value: 16, label: Text('16 Photos'))],
              selected: {_count},
              onSelectionChanged: (s) => setState(() => _count = s.first),
            ),
            const SizedBox(height: 16),
            if (_path != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: Text('Export $_count-Photo Print PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: _exportPdf,
              ),
          ],
        ),
      ),
    );
  }
}

// 6. PHOTO STUDIO (Real Physical 90° Rotate)
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _path;

  Future<void> _rotate() async {
    if (_path == null) return;
    final raw = await File(_path!).readAsBytes();
    final img = (await (await ui.instantiateImageCodec(raw)).getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.height.toDouble(), img.width.toDouble()));
    canvas.translate(img.height.toDouble() / 2, img.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(img, Offset(-img.width.toDouble() / 2, -img.height.toDouble() / 2), Paint());

    final output = await recorder.endRecording().toImage(img.height, img.width);
    final byteData = await output.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/scans/rot_${DateTime.now().millisecondsSinceEpoch}.png');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());
      setState(() => _path = newFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate Photo Studio'),
        actions: [
          if (_path != null) IconButton(icon: const Icon(Icons.rotate_right), onPressed: _rotate),
          if (_path != null) IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(_path!)])),
        ],
      ),
      body: Center(
        child: _path == null
            ? ElevatedButton(
                onPressed: () async {
                  final s = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
                  final res = await s.scanDocument();
                  if (res?.images != null && res!.images.isNotEmpty) setState(() => _path = res.images.first);
                },
                child: const Text('Select Image'),
              )
            : Image.file(File(_path!)),
      ),
    );
  }
}

// 7. INVOICE MAKER WITH REAL GST CALCULATION (18%)
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _client = TextEditingController(text: 'ABC Enterprises');
  final _num = TextEditingController(text: 'INV-001');
  final _item = TextEditingController();
  final _price = TextEditingController();
  final List<Map<String, dynamic>> _items = [{'name': 'Professional Consulting', 'price': 2000.0}];

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    double sub = _items.fold(0.0, (s, i) => s + (i['price'] as double));
    double cgst = sub * 0.09;
    double sgst = sub * 0.09;
    double total = sub + cgst + sgst;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.Text('Invoice No: ${_num.text}'),
            pw.Text('Client: ${_client.text}'),
            pw.Divider(),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Amount (INR)'],
              data: _items.map((e) => [e['name'], 'INR ${e['price']}']).toList(),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Subtotal: INR ${sub.toStringAsFixed(2)}'),
                  pw.Text('CGST (9%): INR ${cgst.toStringAsFixed(2)}'),
                  pw.Text('SGST (9%): INR ${sgst.toStringAsFixed(2)}'),
                  pw.Text('Grand Total: INR ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/Invoice_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await f.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(f.path)], text: 'Tax Invoice PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST Invoice Maker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _client, decoration: const InputDecoration(labelText: 'Client Name')),
            TextField(controller: _num, decoration: const InputDecoration(labelText: 'Invoice Number')),
            Row(
              children: [
                Expanded(child: TextField(controller: _item, decoration: const InputDecoration(labelText: 'Item'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price'))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF00796B)),
                  onPressed: () {
                    if (_item.text.isNotEmpty && _price.text.isNotEmpty) {
                      setState(() {
                        _items.add({'name': _item.text, 'price': double.tryParse(_price.text) ?? 0.0});
                        _item.clear(); _price.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) => ListTile(title: Text(_items[i]['name']), trailing: Text('INR ${_items[i]['price']}')),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
              onPressed: _exportPdf,
              child: const Text('Generate Invoice PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// 8. RESUME BUILDER
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Sharma');
  final _phone = TextEditingController(text: '+91 9876543210');
  final _summary = TextEditingController(text: 'Dedicated Professional with experience in Project Execution.');

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_name.text, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.Text(_phone.text),
            pw.Divider(color: PdfColors.teal),
            pw.Text('Profile Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(_summary.text),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File("${dir.path}/Resume_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await f.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(f.path)], text: 'Resume PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Builder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _summary, maxLines: 3, decoration: const InputDecoration(labelText: 'Summary')),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
              onPressed: _exportPdf,
              child: const Text('Export Resume PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// 9. SMART NOTES (Permanently Saved)
class TxtEditorNotesScreen extends StatefulWidget {
  const TxtEditorNotesScreen({super.key});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => _body.text = p.getString('smart_note') ?? ''));
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('smart_note', _body.text);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note permanently saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Notes'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
          IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share(_body.text)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(controller: _body, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Type your notes here...', border: InputBorder.none)),
      ),
    );
  }
}
