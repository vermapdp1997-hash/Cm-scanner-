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
  late Animation<double> _s, _f;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _s = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _f = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _c.forward();

    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainDashboardScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        ));
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
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.document_scanner_rounded, size: 68, color: Color(0xFF00796B)),
                ),
                const SizedBox(height: 20),
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
  bool _isSearching = false, _isGridView = false, _sortAscending = false;
  String _selectedCategory = 'All';
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
    final String? rawData = prefs.getString('saved_documents_v2');
    if (rawData != null && mounted) {
      try {
        final List decoded = jsonDecode(rawData);
        setState(() {
          _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _filterDocs();
        });
      } catch (e) {
        debugPrint("Doc read err: $e");
      }
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
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(q);
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
    final index = _savedDocs.indexWhere((d) => d['id'] == id);
    if (index != -1) {
      setState(() {
        _savedDocs[index]['isFavorite'] = !(_savedDocs[index]['isFavorite'] ?? false);
        _filterDocs();
      });
      await _commitDocsToPrefs();
    }
  }

  Future<List<String>> _copyImagesToPermanentStorage(List<String> tempPaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);

    List<String> persistentPaths = [];
    for (int i = 0; i < tempPaths.length; i++) {
      final tempFile = File(tempPaths[i]);
      if (await tempFile.exists()) {
        final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';
        final savedFile = await tempFile.copy('${scansDir.path}/$fileName');
        persistentPaths.add(savedFile.path);
      }
    }
    return persistentPaths;
  }

  Future<void> _saveDocToStorage(String title, List<String> rawPaths, {String category = 'Documents'}) async {
    final persistentPaths = await _copyImagesToPermanentStorage(rawPaths);
    if (persistentPaths.isEmpty) {
      _showToast('Failed to save scanned images.');
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
    final docToDelete = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (docToDelete.isNotEmpty && docToDelete['images'] != null) {
      for (String p in docToDelete['images']) {
        final f = File(p);
        if (await f.exists()) {
          try { await f.delete(); } catch (_) {}
        }
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
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: limit));
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

  Future<void> _processIdCardCollage(List<String> frontAndBack, String prefix) async {
    try {
      final frontBytes = await File(frontAndBack[0]).readAsBytes();
      final backBytes = await File(frontAndBack[1]).readAsBytes();

      final frontImg = (await (await ui.instantiateImageCodec(frontBytes)).getNextFrame()).image;
      final backImg = (await (await ui.instantiateImageCodec(backBytes)).getNextFrame()).image;

      const a4Width = 1240.0, a4Height = 1754.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, a4Width, a4Height));
      canvas.drawRect(const Rect.fromLTWH(0, 0, a4Width, a4Height), Paint()..color = Colors.white);

      const cardW = 750.0, cardH = 470.0, left = (a4Width - cardW) / 2;
      final borderPaint = Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.stroke..strokeWidth = 2.0;

      final rect1 = const Rect.fromLTWH(left, 200.0, cardW, cardH);
      canvas.drawImageRect(frontImg, Rect.fromLTWH(0, 0, frontImg.width.toDouble(), frontImg.height.toDouble()), rect1, Paint());
      canvas.drawRect(rect1, borderPaint);

      final rect2 = const Rect.fromLTWH(left, 820.0, cardW, cardH);
      canvas.drawImageRect(backImg, Rect.fromLTWH(0, 0, backImg.width.toDouble(), backImg.height.toDouble()), rect2, Paint());
      canvas.drawRect(rect2, borderPaint);

      final textPainter = TextPainter(
        text: const TextSpan(text: 'Bharat Scanner Pro • Verified ID Print Layout (A4)', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((a4Width - textPainter.width) / 2, a4Height - 90));

      final collage = await recorder.endRecording().toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await collage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final collageFile = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await collageFile.writeAsBytes(byteData.buffer.asUint8List());
        await _saveDocToStorage('ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}', [collageFile.path], category: 'ID Cards');
      }
    } catch (e) {
      if (mounted) _promptDocName(frontAndBack, prefix, 'ID Cards');
    }
  }

  void _promptDocName(List<String> images, String prefix, String category) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Scanned File', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ ${images.length} page(s) ready.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Document Name', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveDocToStorage(nameCtrl.text.trim(), images, category: category);
            },
            child: const Text('Save Document'),
          ),
        ],
      ),
    );
  }

  void _openCompressionDialog(List<dynamic> images, String title) {
    double qualitySlider = 0.5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Compress Document', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scale: ${(qualitySlider * 100).toInt()}%'),
              Slider(
                value: qualitySlider, min: 0.1, max: 1.0, divisions: 9, activeColor: const Color(0xFF00796B),
                onChanged: (val) => setDialogState(() => qualitySlider = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _exportPdfWithScale(images, "${title}_Compressed", scale: qualitySlider);
              },
              child: const Text('Export Compressed PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareImages(List images, String title, {double scale = 1.0}) async {
    List<XFile> shareFiles = [];
    final appDir = await getTemporaryDirectory();

    for (int i = 0; i < images.length; i++) {
      final f = File(images[i]);
      if (await f.exists()) {
        if (scale < 1.0) {
          final bytes = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: (1200 * scale).toInt().clamp(300, 2500));
          final frame = await codec.getNextFrame();
          final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (resized != null) {
            final compressedFile = File('${appDir.path}/img_${title}_p$i.png');
            await compressedFile.writeAsBytes(resized.buffer.asUint8List());
            shareFiles.add(XFile(compressedFile.path));
            continue;
          }
        }
        shareFiles.add(XFile(f.path));
      }
    }
    if (shareFiles.isNotEmpty) {
      await Share.shareXFiles(shareFiles, text: '$title - Bharat Scanner Pro');
    } else {
      _showToast('No images to share.');
    }
  }

  Future<void> _exportPdfWithScale(List images, String title, {double scale = 1.0, String? watermark}) async {
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
          final rawBytes = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: (1200 * scale).toInt().clamp(350, 2000));
          final frame = await codec.getNextFrame();
          final resizedData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          finalBytes = resizedData != null ? resizedData.buffer.asUint8List() : rawBytes;
        } else {
          finalBytes = await f.readAsBytes();
        }

        final img = pw.MemoryImage(finalBytes);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Stack(
            alignment: pw.Alignment.center,
            children: [
              pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
              if (watermark != null && watermark.isNotEmpty)
                pw.Center(child: pw.Transform.rotate(angle: -0.6, child: pw.Text(watermark, style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0x35000000))))),
            ],
          ),
        ));
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
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(imagePath));
      await textRecognizer.close();
      text = recognizedText.text;
    } catch (e) {
      debugPrint("OCR Err: $e");
    }

    if (!mounted) return;
    if (text.trim().isEmpty) return _showToast('No readable text detected.');

    final textCtrl = TextEditingController(text: text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AI OCR Extracted Text', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.copy_rounded, color: Color(0xFF00796B)), onPressed: () {
                  Clipboard.setData(ClipboardData(text: textCtrl.text));
                  _showToast('Copied to clipboard!');
                }),
              ],
            ),
            const Divider(),
            TextField(controller: textCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Text'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () => Share.share(textCtrl.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWatermarkDialog() {
    if (_savedDocs.isEmpty) return _showToast('Please scan a document first.');
    String selectedDocId = _savedDocs.first['id'];
    final wmCtrl = TextEditingController(text: 'CONFIDENTIAL');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add PDF Watermark'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedDocId,
                decoration: const InputDecoration(labelText: 'Select Document', border: OutlineInputBorder()),
                items: _savedDocs.map((doc) => DropdownMenuItem(value: doc['id'].toString(), child: Text(doc['title'], overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) { if (val != null) setModalState(() => selectedDocId = val); },
              ),
              const SizedBox(height: 14),
              TextField(controller: wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                final chosenDoc = _savedDocs.firstWhere((d) => d['id'] == selectedDocId);
                _exportPdfWithScale(chosenDoc['images'], "${chosenDoc['title']}_Watermarked", watermark: wmCtrl.text.trim());
              },
              child: const Text('Apply & Share PDF'),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF00796B), duration: const Duration(seconds: 2)));
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
            : const Text('BHARAT SCANNER PRO', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
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
        shape: const CircleBorder(),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        onPressed: () => _startDocScan(),
        child: const Icon(Icons.camera_alt_rounded, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: () => setState(() => _currentTabIndex = 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_shared_rounded, color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey),
                  Text('Docs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 0 ? const Color(0xFF00796B) : Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 44),
            InkWell(
              onTap: () => setState(() => _currentTabIndex = 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.widgets_rounded, color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey),
                  Text('Studio & Office', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 1 ? const Color(0xFF00796B) : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Saved Files (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(
              children: [
                IconButton(icon: Icon(_sortAscending ? Icons.sort_by_alpha_rounded : Icons.access_time_rounded), onPressed: () => setState(() { _sortAscending = !_sortAscending; _filterDocs(); })),
                IconButton(icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded), onPressed: () => setState(() => _isGridView = !_isGridView)),
              ],
            ),
          ],
        ),
        if (_filteredDocs.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text("No documents saved yet.")))
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
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
    final List imgList = doc['images'] ?? [];
    final hasImage = imgList.isNotEmpty && File(imgList.first).existsSync();
    final isFav = doc['isFavorite'] == true;

    return Card(
      child: ListTile(
        leading: hasImage ? Image.file(File(imgList.first), width: 50, height: 60, fit: BoxFit.cover) : const Icon(Icons.broken_image),
        title: Text(doc['title'] ?? 'Untitled', maxLines: 1),
        subtitle: Text('${doc['pages']} pages • ${doc['date']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded, color: isFav ? Colors.amber : Colors.grey), onPressed: () => _toggleFavorite(doc['id'])),
            IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2E7D32)), onPressed: () => _exportPdfWithScale(imgList, doc['title'])),
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
          onSharePdf: (p, t) => _exportPdfWithScale(p, t),
          onShareImages: (p, t) => _shareImages(p, t),
          onCompress: (p, t) => _openCompressionDialog(p, t),
        ))),
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> doc) {
    final List imgList = doc['images'] ?? [];
    final hasImage = imgList.isNotEmpty && File(imgList.first).existsSync();

    return Card(
      child: Column(
        children: [
          Expanded(child: hasImage ? Image.file(File(imgList.first), width: double.infinity, fit: BoxFit.cover) : const Center(child: Icon(Icons.broken_image))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(doc['title'] ?? 'Untitled', maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => _deleteDoc(doc['id'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Tools & Productivity Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85,
          children: [
            _buildToolCard('ID Card A4', Icons.badge_outlined, Colors.blue, () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card')),
            _buildToolCard('Single Card', Icons.credit_card_rounded, const Color(0xFF00796B), () => _startDocScan(limit: 1, category: 'ID Cards', prefix: 'Card')),
            _buildToolCard('Presentation', Icons.slideshow_rounded, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard('Resume Maker', Icons.assignment_ind_rounded, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildToolCard('GST Invoice', Icons.receipt_rounded, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard('Letters', Icons.mail_outline_rounded, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard('Smart Notes', Icons.note_alt_outlined, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: true)))),
            _buildToolCard('Passport Photo', Icons.portrait_rounded, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
            _buildToolCard('Digital Sign', Icons.draw_rounded, Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildToolCard('Photo Rotate', Icons.rotate_right_rounded, Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
            _buildToolCard('Watermark', Icons.branding_watermark_outlined, Colors.brown, () => _openWatermarkDialog()),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withAlpha(25), child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// 3. DOCUMENT DETAIL SCREEN WITH REAL FILTER BAKING
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Function(String) onExtractText;
  final Function(List, String) onSharePdf;
  final Function(List, String) onShareImages;
  final Function(List, String) onCompress;

  const DocumentDetailScreen({super.key, required this.doc, required this.onDelete, required this.onDocUpdated, required this.onExtractText, required this.onSharePdf, required this.onShareImages, required this.onCompress});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _pageController = PageController();
  }

  Future<void> _applyAndBakeFilter(int mode) async {
    if (_images.isEmpty) return;
    ColorFilter? filter;
    if (mode == 1) {
      filter = const ColorFilter.matrix([1.2, 0, 0, 0, -10, 0, 1.2, 0, 0, -10, 0, 0, 1.2, 0, -10, 0, 0, 0, 1, 0]);
    } else if (mode == 2) {
      filter = const ColorFilter.matrix([1.5, 1.5, 1.5, 0, -160, 1.5, 1.5, 1.5, 0, -160, 1.5, 1.5, 1.5, 0, -160, 0, 0, 0, 1, 0]);
    }

    if (filter == null) return;
    final currFile = File(_images[_currentPage]);
    final bytes = await currFile.readAsBytes();
    final img = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
    canvas.drawImage(img, Offset.zero, Paint()..colorFilter = filter);

    final outputImg = await recorder.endRecording().toImage(img.width, img.height);
    final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/scans/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());

      setState(() => _images[_currentPage] = newFile.path);
      widget.doc['images'] = _images;
      widget.onDocUpdated(widget.doc);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filter permanently applied.')));
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
            onSelected: _applyAndBakeFilter,
            itemBuilder: (_) => const [PopupMenuItem(value: 1, child: Text('Magic Color')), PopupMenuItem(value: 2, child: Text('High Contrast B&W'))],
          ),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => widget.onSharePdf(_images, widget.doc['title'] ?? 'Doc')),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
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
              label: const Text('OCR Insights', style: TextStyle(color: Colors.tealAccent)),
              onPressed: () => widget.onExtractText(_images[_currentPage]),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. DIGITAL SIGNATURE STUDIO (Auto-Trimmed Transparent PNG)
class DigitalSignatureScreen extends StatefulWidget {
  const DigitalSignatureScreen({super.key});
  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final List<Offset?> _points = [];
  Color _penColor = Colors.black;

  Future<void> _saveSignature() async {
    final validPoints = _points.whereType<Offset>().toList();
    if (validPoints.isEmpty) return;

    double minX = validPoints.first.dx, maxX = validPoints.first.dx, minY = validPoints.first.dy, maxY = validPoints.first.dy;
    for (var p in validPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    const padding = 20.0;
    minX = (minX - padding).clamp(0, 5000);
    minY = (minY - padding).clamp(0, 5000);
    final width = (maxX - minX + (padding * 2)).clamp(50.0, 5000.0);
    final height = (maxY - minY + (padding * 2)).clamp(50.0, 5000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.translate(-minX, -minY);

    final paint = Paint()..color = _penColor..strokeCap = StrokeCap.round..strokeWidth = 4.0;
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
    }

    final img = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Signature_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My Cropped Digital Signature (Transparent PNG)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature Studio'),
        actions: [
          IconButton(icon: const Icon(Icons.cleaning_services_rounded), onPressed: () => setState(() => _points.clear())),
          IconButton(icon: const Icon(Icons.check_rounded, color: Color(0xFF00796B), size: 28), onPressed: _saveSignature),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanUpdate: (details) => setState(() => _points.add((context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition))),
          onPanEnd: (_) => _points.add(null),
          child: CustomPaint(painter: _SignaturePainter(points: _points, color: _penColor), size: Size.infinite),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  _SignaturePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeCap = StrokeCap.round..strokeWidth = 3.5;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 5. PASSPORT PHOTO STUDIO (8 & 16 Photos Toggle)
class PassportPhotoStudioScreen extends StatefulWidget {
  const PassportPhotoStudioScreen({super.key});
  @override
  State<PassportPhotoStudioScreen> createState() => _PassportPhotoStudioScreenState();
}

class _PassportPhotoStudioScreenState extends State<PassportPhotoStudioScreen> {
  String? _selectedImagePath;
  int _photoCount = 8;

  Future<void> _pickPhoto() async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
    final res = await scanner.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) setState(() => _selectedImagePath = res.images.first);
  }

  Future<void> _generateA4PrintSheet() async {
    if (_selectedImagePath == null) return;
    final pdf = pw.Document();
    final passImage = pw.MemoryImage(await File(_selectedImagePath!).readAsBytes());
    final double width = _photoCount == 8 ? 115 : 85;
    final double height = _photoCount == 8 ? 150 : 110;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        children: [
          pw.Header(level: 0, text: 'Passport Photos Print Sheet ($_photoCount Photos)'),
          pw.Wrap(
            spacing: 12, runSpacing: 14,
            children: List.generate(_photoCount, (index) => pw.Container(width: width, height: height, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Image(passImage, fit: pw.BoxFit.cover))),
          ),
        ],
      ),
    ));

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Passport_Sheet_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
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
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400)),
              child: _selectedImagePath != null ? Image.file(File(_selectedImagePath!), fit: BoxFit.cover) : const Icon(Icons.portrait, size: 70, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _pickPhoto, child: const Text('Capture / Choose Portrait')),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 8, label: Text('8 Photos')), ButtonSegment(value: 16, label: Text('16 Photos'))],
              selected: {_photoCount},
              onSelectionChanged: (set) => setState(() => _photoCount = set.first),
            ),
            const SizedBox(height: 16),
            if (_selectedImagePath != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: Text('Generate $_photoCount-Photo A4 Print PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: _generateA4PrintSheet,
              ),
          ],
        ),
      ),
    );
  }
}

// 6. UNIVERSAL IMAGE TOOLS (Physical 90° Rotate)
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imagePath;

  Future<void> _rotatePhysically() async {
    if (_imagePath == null) return;
    final bytes = await File(_imagePath!).readAsBytes();
    final img = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.height.toDouble(), img.width.toDouble()));
    canvas.translate(img.height.toDouble() / 2, img.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(img, Offset(-img.width.toDouble() / 2, -img.height.toDouble() / 2), Paint());

    final rotatedImg = await recorder.endRecording().toImage(img.height, img.width);
    final byteData = await rotatedImg.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/scans/rotated_${DateTime.now().millisecondsSinceEpoch}.png');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());
      setState(() => _imagePath = newFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Studio & Editor'),
        actions: [
          if (_imagePath != null) IconButton(icon: const Icon(Icons.rotate_right_rounded), onPressed: _rotatePhysically),
          if (_imagePath != null) IconButton(icon: const Icon(Icons.share_rounded, color: Color(0xFF00796B)), onPressed: () => Share.shareXFiles([XFile(_imagePath!)])),
        ],
      ),
      body: Center(
        child: _imagePath == null
            ? ElevatedButton(
                onPressed: () async {
                  final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
                  final res = await scanner.scanDocument();
                  if (res?.images != null && res!.images.isNotEmpty) setState(() => _imagePath = res.images.first);
                },
                child: const Text('Select Image'),
              )
            : Image.file(File(_imagePath!)),
      ),
    );
  }
}

// 7. POWERPOINT / PRESENTATION STUDIO
class PowerPointStudioScreen extends StatefulWidget {
  const PowerPointStudioScreen({super.key});
  @override
  State<PowerPointStudioScreen> createState() => _PowerPointStudioScreenState();
}

class _PowerPointStudioScreenState extends State<PowerPointStudioScreen> {
  final List<Map<String, String>> _slides = [
    {'title': 'Project Overview', 'content': '1. Objectives & Roadmap\n2. Key Performance Indicators'},
    {'title': 'Final Conclusion', 'content': '• Timelines & Budget\n• Execution Strategy'},
  ];

  Future<void> _exportSlidesAsPdf() async {
    final pdf = pw.Document();
    for (int i = 0; i < _slides.length; i++) {
      final s = _slides[i];
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(32),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal, width: 3)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ));
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Presentation_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Presentation Slides (PDF)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentation Studio'),
        actions: [IconButton(icon: const Icon(Icons.share_rounded, color: Color(0xFF00796B)), onPressed: _exportSlidesAsPdf)],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slides.length,
        itemBuilder: (ctx, i) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Slide Title'), onChanged: (v) => _slides[i]['title'] = v),
                TextFormField(initialValue: _slides[i]['content'], maxLines: 3, decoration: const InputDecoration(labelText: 'Content'), onChanged: (v) => _slides[i]['content'] = v),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Add Slide'),
        onPressed: () => setState(() => _slides.add({'title': 'New Slide', 'content': 'Bullet points...'})),
      ),
    );
  }
}

// 8. TXT EDITOR & NOTES MAKER (Permanent Save)
class TxtEditorNotesScreen extends StatefulWidget {
  final bool isNotes;
  const TxtEditorNotesScreen({super.key, required this.isNotes});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (widget.isNotes) {
        setState(() {
          _titleCtrl.text = p.getString('saved_note_title') ?? '';
          _bodyCtrl.text = p.getString('saved_note_body') ?? '';
        });
      }
    });
  }

  Future<void> _saveAndExport() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.isNotes) {
      await prefs.setString('saved_note_title', _titleCtrl.text.trim());
      await prefs.setString('saved_note_body', _bodyCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note permanently saved.')));
    }
    if (_bodyCtrl.text.trim().isEmpty) return;
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${_titleCtrl.text.trim().isEmpty ? 'Note' : _titleCtrl.text.trim()}.txt");
    await file.writeAsString(_bodyCtrl.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported from Bharat Scanner');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNotes ? 'Smart Notes' : 'TXT File Editor'),
        actions: [IconButton(icon: const Icon(Icons.save_rounded, color: Color(0xFF00796B)), onPressed: _saveAndExport)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Title...', border: InputBorder.none, hintStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            const Divider(),
            Expanded(child: TextField(controller: _bodyCtrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Type here...', border: InputBorder.none))),
          ],
        ),
      ),
    );
  }
}

// 9. PRO RESUME BUILDER
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Sharma');
  final _phone = TextEditingController(text: '+91 98765 43210');
  final _email = TextEditingController(text: 'rahul.sharma@email.com');
  final _summary = TextEditingController(text: 'Experienced professional dedicated to organizational growth.');

  Future<void> _generateResumePdf() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_name.text, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.Text('${_phone.text} | ${_email.text}'),
            pw.Divider(thickness: 1.5, color: PdfColors.teal),
            pw.SizedBox(height: 10),
            pw.Text('Profile Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.Text(_summary.text),
          ],
        ),
      ),
    ));

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Resume_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Professional Resume PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pro Resume Builder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _summary, maxLines: 3, decoration: const InputDecoration(labelText: 'Summary', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              onPressed: _generateResumePdf,
              child: const Text('Generate Resume PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// 10. INVOICE MAKER WITH REAL GST CALCULATION (18% Split)
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _clientName = TextEditingController(text: 'ABC Enterprises');
  final _invoiceNum = TextEditingController(text: 'INV-2026-001');
  final _itemName = TextEditingController();
  final _itemPrice = TextEditingController();
  final List<Map<String, dynamic>> _items = [{'name': 'Consulting Service', 'price': 2000.0}];

  Future<void> _exportInvoicePdf() async {
    final pdf = pw.Document();
    double subtotal = _items.fold(0.0, (s, i) => s + (i['price'] as double));
    double cgst = subtotal * 0.09;
    double sgst = subtotal * 0.09;
    double grandTotal = subtotal + cgst + sgst;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.Text('Invoice No: ${_invoiceNum.text} | Client: ${_clientName.text}'),
            pw.Divider(thickness: 1.5, color: PdfColors.teal),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Amount (INR)'],
              data: _items.map((e) => [e['name'], 'INR ${e['price']}']).toList(),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Subtotal: INR ${subtotal.toStringAsFixed(2)}'),
                  pw.Text('CGST (9%): INR ${cgst.toStringAsFixed(2)}'),
                  pw.Text('SGST (9%): INR ${sgst.toStringAsFixed(2)}'),
                  pw.Divider(),
                  pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                ],
              ),
            ),
          ],
        ),
      ),
    ));

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Invoice_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Tax Invoice PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST Invoice Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _clientName, decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _invoiceNum, decoration: const InputDecoration(labelText: 'Invoice Number', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'Item', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _itemPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF00796B), size: 36),
                  onPressed: () {
                    if (_itemName.text.isNotEmpty && _itemPrice.text.isNotEmpty) {
                      setState(() {
                        _items.add({'name': _itemName.text.trim(), 'price': double.tryParse(_itemPrice.text.trim()) ?? 0.0});
                        _itemName.clear(); _itemPrice.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._items.map((i) => ListTile(title: Text(i['name']), trailing: Text('INR ${i['price']}'))),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              onPressed: _exportInvoicePdf,
              child: const Text('Generate GST Invoice PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// 11. LETTER TEMPLATES
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _letterCtrl = TextEditingController(
    text: "To,\nThe Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nPlease grant me leave for 2 days due to urgent personal work.\n\nThank you.\nSincerely,\n[Your Name]",
  );

  Future<void> _exportLetterPdf() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Text(_letterCtrl.text, style: const pw.TextStyle(fontSize: 14, lineSpacing: 3)),
      ),
    ));
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Letter_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letter Maker Templates'),
        actions: [IconButton(icon: const Icon(Icons.share, color: Color(0xFF00796B)), onPressed: _exportLetterPdf)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Leave Application'),
                  onPressed: () => setState(() => _letterCtrl.text = "To,\nThe HR Manager,\nSubject: Leave Request\n\nRespected Sir/Madam,\nI request you to grant me leave for 2 days.\n\nRegards,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation Letter'),
                  onPressed: () => setState(() => _letterCtrl.text = "To,\nThe HR Manager,\nSubject: Resignation Letter\n\nDear Sir/Madam,\nPlease accept this letter as formal notification of my resignation.\n\nRegards,\n[Your Name]"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: TextField(controller: _letterCtrl, maxLines: null, expands: true, decoration: const InputDecoration(border: OutlineInputBorder()))),
          ],
        ),
      ),
    );
  }
}
