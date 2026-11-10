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

// GLOBAL THEME CONTROLLER (Default clean Teal theme)
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFF00796B));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Ads init: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final colorVal = prefs.getInt('primary_color_val');
  if (colorVal != null) {
    appPrimaryColor.value = Color(colorVal);
  }

  runApp(const BharatDocScannerApp());
}

class BharatDocScannerApp extends StatelessWidget {
  const BharatDocScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, color, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeMode,
          builder: (_, mode, ___) {
            return MaterialApp(
              title: 'Bharat Document Scanner AI',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF7F9FA),
                colorSchemeSeed: color,
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  iconTheme: IconThemeData(color: Colors.black87),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorSchemeSeed: color,
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  backgroundColor: Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  iconTheme: IconThemeData(color: Colors.white),
                ),
              ),
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

// 1. SPLASH SCREEN (Attractive Red Glossy Badge Logo as requested)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 2000), () {
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
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // RED COLOR GLOSSY ATTRACTIVE LOGO
  Widget _buildAppBadgeLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFB71C1C), Color(0xFF7F0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withAlpha(140),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.white.withAlpha(90), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Glass Reflection Shine (Chamak)
            Positioned(
              top: -30,
              left: -30,
              child: Container(
                width: 130,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: const BorderRadius.all(Radius.elliptical(120, 80)),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'DOC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'SCANNER',
                          style: TextStyle(
                            color: Color(0xFFFFEBEE),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFFF5252),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('AI EDITION', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAppBadgeLogo(),
                const SizedBox(height: 24),
                const Text(
                  'BHARAT DOCUMENT SCANNER AI',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.8),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(20)),
                  child: const Text('⚡ India’s Smartest AI Office & Scan Suite', style: TextStyle(color: Color(0xFFB2DFDB), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. MAIN DASHBOARD SCREEN
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

  String get _bannerId => 'ca-app-pub-3940256099942544/6300978111';
  String get _interstitialId => 'ca-app-pub-3940256099942544/1033173712';

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
        onAdFailedToLoad: (ad, err) {
          debugPrint("Banner err: $err");
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (err) {
          debugPrint("Interstitial err: $err");
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents_v3');
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
    await prefs.setString('saved_documents_v3', jsonEncode(_savedDocs));
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
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }

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
      'images': List<String>.from(persistentPaths),
      'originalImages': List<String>.from(persistentPaths),
      'pages': persistentPaths.length,
    };

    setState(() {
      _savedDocs.insert(0, newDoc);
      _filterDocs();
    });
    await _commitDocsToPrefs();
    _showToast('✅ Saved to Bharat Document Scanner AI');
  }

  Future<void> _updateExistingDoc(Map<String, dynamic> updatedDoc) async {
    final idx = _savedDocs.indexWhere((d) => d['id'] == updatedDoc['id']);
    if (idx != -1) {
      setState(() {
        _savedDocs[idx] = updatedDoc;
        _filterDocs();
      });
      await _commitDocsToPrefs();
    }
  }

  Future<void> _deleteDoc(String id) async {
    final docToDelete = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (docToDelete.isNotEmpty && docToDelete['images'] != null) {
      for (String p in docToDelete['images']) {
        final f = File(p);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
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

  Future<void> _startDocScan({int limit = 50, String category = 'Documents', String prefix = 'Doc', bool galleryOnly = false}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: limit,
      ),
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

  // Bottom Sheet matching Screenshot 1
  void _openAddDocumentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: appPrimaryColor.value.withAlpha(30), shape: BoxShape.circle),
                      child: Icon(Icons.note_add_rounded, color: appPrimaryColor.value, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Add New Document', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        Text('Choose from below options', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(height: 24),
                _buildSheetTile(
                  icon: Icons.photo_library_rounded,
                  iconColor: const Color(0xFF00ACC1),
                  title: 'Import from Gallery',
                  subtitle: 'Select existing photos from device',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan(galleryOnly: true);
                  },
                ),
                _buildSheetTile(
                  icon: Icons.camera_alt_rounded,
                  iconColor: const Color(0xFF1E88E5),
                  title: 'Scan from Camera',
                  subtitle: 'Capture documents, bills, papers',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan();
                  },
                ),
                _buildSheetTile(
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFFE53935),
                  title: 'ID Card Mode (Front & Back)',
                  subtitle: 'Combine both sides into single page',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card');
                  },
                ),
                _buildSheetTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFF43A047),
                  title: 'Import Documents & PDF',
                  subtitle: 'Merge or convert office files',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfStudioScreen(
                          savedDocs: _savedDocs,
                          onExportPdf: (paths, title) => _exportPdfWithScale(paths, title),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _processIdCardCollage(List<String> frontAndBack, String prefix) async {
    try {
      final frontBytes = await File(frontAndBack[0]).readAsBytes();
      final backBytes = await File(frontAndBack[1]).readAsBytes();

      final frontCodec = await ui.instantiateImageCodec(frontBytes);
      final frontFrame = await frontCodec.getNextFrame();
      final frontImg = frontFrame.image;

      final backCodec = await ui.instantiateImageCodec(backBytes);
      final backFrame = await backCodec.getNextFrame();
      final backImg = backFrame.image;

      const a4Width = 1240.0;
      const a4Height = 1754.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, a4Width, a4Height));

      canvas.drawRect(const Rect.fromLTWH(0, 0, a4Width, a4Height), Paint()..color = Colors.white);

      const cardW = 750.0;
      const cardH = 470.0;
      const left = (a4Width - cardW) / 2;
      final borderPaint = Paint()
        ..color = const Color(0xFFCFD8DC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      const top1 = 200.0;
      final rect1 = Rect.fromLTWH(left, top1, cardW, cardH);
      canvas.drawImageRect(frontImg, Rect.fromLTWH(0, 0, frontImg.width.toDouble(), frontImg.height.toDouble()), rect1, Paint());
      canvas.drawRect(rect1, borderPaint);

      const top2 = 820.0;
      final rect2 = Rect.fromLTWH(left, top2, cardW, cardH);
      canvas.drawImageRect(backImg, Rect.fromLTWH(0, 0, backImg.width.toDouble(), backImg.height.toDouble()), rect2, Paint());
      canvas.drawRect(rect2, borderPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Bharat Document Scanner AI • Official Verified ID Layout',
          style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((a4Width - textPainter.width) / 2, a4Height - 90));

      final picture = recorder.endRecording();
      final a4CollageImg = await picture.toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await a4CollageImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final collageFile = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await collageFile.writeAsBytes(byteData.buffer.asUint8List());

        await _saveDocToStorage(
          'ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}',
          [collageFile.path],
          category: 'ID Cards',
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: appPrimaryColor.value),
            const SizedBox(width: 8),
            const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ ${images.length} page(s) ready.', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Document Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveDocToStorage(nameCtrl.text.trim(), images, category: category);
            },
            child: const Text('Save to Docs'),
          ),
        ],
      ),
    );
  }

  void _openCompressionDialog(List<dynamic> images, String title) {
    double scaleSlider = 0.85;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          int estimatedKb = (images.length * 750 * scaleSlider).toInt() + 45;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: appPrimaryColor.value),
                const SizedBox(width: 8),
                const Text('Smart Compress & Resize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose compression balance without losing text clarity:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Resolution: ${(scaleSlider * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: appPrimaryColor.value.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                      child: Text('~ $estimatedKb KB', style: TextStyle(color: appPrimaryColor.value, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                Slider(
                  value: scaleSlider,
                  min: 0.25,
                  max: 1.0,
                  divisions: 15,
                  activeColor: appPrimaryColor.value,
                  onChanged: (val) {
                    setDialogState(() => scaleSlider = val);
                  },
                ),
                Text(
                  scaleSlider > 0.7 ? "🌟 Best Quality (HD)" : (scaleSlider > 0.45 ? "⚡ Good for Email/Uploads" : "📦 Maximum Compression"),
                  style: TextStyle(fontSize: 11, color: appPrimaryColor.value, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportPdfWithScale(images, "${title}_Compressed", scale: scaleSlider);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Save to Phone'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveToDeviceStorage(images, title, scale: scaleSlider);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveToDeviceStorage(List images, String title, {double scale = 1.0}) async {
    try {
      final pdf = await _generatePdfDoc(images, scale: scale);
      final downloadsDir = Directory('/storage/emulated/0/Download');
      String savePath;

      if (await downloadsDir.exists()) {
        final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        savePath = "${downloadsDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        savePath = "${appDir.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      }

      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());

      _showToast('📁 Saved directly to Downloads:\n$savePath');
    } catch (e) {
      await _exportPdfWithScale(images, title, scale: scale);
    }
  }

  Future<pw.Document> _generatePdfDoc(List images, {double scale = 1.0, String? watermark}) async {
    final pdf = pw.Document();
    for (var path in images) {
      final f = File(path);
      if (await f.exists()) {
        Uint8List finalBytes;
        if (scale < 1.0) {
          final rawBytes = await f.readAsBytes();
          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: (1800 * scale).toInt().clamp(600, 3000));
          final frame = await codec.getNextFrame();
          final resizedData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          finalBytes = resizedData != null ? resizedData.buffer.asUint8List() : rawBytes;
        } else {
          finalBytes = await f.readAsBytes();
        }

        final img = pw.MemoryImage(finalBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) {
              return pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
                  if (watermark != null && watermark.isNotEmpty)
                    pw.Center(
                      child: pw.Transform.rotate(
                        angle: -0.6,
                        child: pw.Text(
                          watermark,
                          style: pw.TextStyle(
                            fontSize: 48,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0x35000000),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }
    }
    return pdf;
  }

  Future<void> _exportPdfWithScale(List images, String title, {double scale = 1.0, String? watermark}) async {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }

    final pdf = await _generatePdfDoc(images, scale: scale, watermark: watermark);
    final dir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File("${dir.path}/$safeName.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Document Scanner AI');
  }

  Future<void> _shareImages(List images, String title, {double scale = 1.0}) async {
    List<XFile> shareFiles = [];
    for (int i = 0; i < images.length; i++) {
      final f = File(images[i]);
      if (await f.exists()) {
        shareFiles.add(XFile(f.path));
      }
    }

    if (shareFiles.isNotEmpty) {
      await Share.shareXFiles(shareFiles, text: '$title - Bharat Document Scanner AI');
    } else {
      _showToast('No images available to share.');
    }
  }

  Future<void> _extractTextWithAI(String imagePath) async {
    String extractedText = '';
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      extractedText = recognizedText.text;
    } catch (e) {
      debugPrint("OCR Err: $e");
    }

    if (!mounted) return;
    if (extractedText.trim().isEmpty) {
      _showToast('No readable text detected.');
      return;
    }

    final textCtrl = TextEditingController(text: extractedText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: appPrimaryColor.value),
                    const SizedBox(width: 8),
                    const Text('AI Text Extraction Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded, color: appPrimaryColor.value),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: textCtrl.text));
                    _showToast('Copied to clipboard!');
                  },
                ),
              ],
            ),
            const Divider(),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              decoration: InputDecoration(filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Extracted Text', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () => Share.share(textCtrl.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWatermarkDialog() {
    if (_savedDocs.isEmpty) {
      _showToast('Please scan a document first.');
      return;
    }
    String selectedDocId = _savedDocs.first['id'];
    final wmCtrl = TextEditingController(text: 'CONFIDENTIAL');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Add PDF Watermark', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDocId,
                  decoration: const InputDecoration(labelText: 'Select Document', border: OutlineInputBorder()),
                  items: _savedDocs.map((doc) => DropdownMenuItem<String>(value: doc['id'].toString(), child: Text(doc['title'], overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDocId = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(controller: wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  final chosenDoc = _savedDocs.firstWhere((d) => d['id'] == selectedDocId);
                  _exportPdfWithScale(chosenDoc['images'], "${chosenDoc['title']}_Watermarked", watermark: wmCtrl.text.trim());
                },
                child: const Text('Apply & Share PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDocumentViewer(Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          doc: doc,
          onDelete: () => _deleteDoc(doc['id']),
          onDocUpdated: (updated) => _updateExistingDoc(updated),
          onExtractText: (path) => _extractTextWithAI(path),
          onSharePdf: (paths, title) => _exportPdfWithScale(paths, title),
          onShareImages: (paths, title) => _shareImages(paths, title),
          onCompress: (paths, title) => _openCompressionDialog(paths, title),
          onSaveToPhone: (paths, title) => _saveToDeviceStorage(paths, title),
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: appPrimaryColor.value, duration: const Duration(seconds: 2)),
    );
  }

  void _openThemeColorPicker() {
    final colors = [
      {'name': 'Emerald Teal', 'color': const Color(0xFF00796B)},
      {'name': 'Ocean Cyan', 'color': const Color(0xFF0288D1)},
      {'name': 'Ruby Red', 'color': const Color(0xFFD32F2F)},
      {'name': 'Deep Crimson', 'color': const Color(0xFFB71C1C)},
      {'name': 'Sapphire Blue', 'color': const Color(0xFF1565C0)},
      {'name': 'Amethyst Purple', 'color': const Color(0xFF7B1FA2)},
      {'name': 'Dark Charcoal', 'color': const Color(0xFF37474F)},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose App Theme'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((item) {
            final col = item['color'] as Color;
            return InkWell(
              onTap: () async {
                appPrimaryColor.value = col;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('primary_color_val', col.value);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item['name'] as String, style: const TextStyle(fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Dual Pill Floating Button [ 📷 | ➕ ] exactly as in the Screenshot!
  Widget _buildDualFab() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF0288D1), // Cyan/Blue as in screenshot
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withAlpha(120),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Camera Button (Left side) -> Directly scans
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
            onTap: () => _startDocScan(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
            ),
          ),
          // Vertical divider line in center
          Container(width: 1.2, height: 26, color: Colors.white.withAlpha(130)),
          // Plus Button (Right side) -> Opens bottom sheet popup
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
            onTap: _openAddDocumentBottomSheet,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [appPrimaryColor.value, appPrimaryColor.value.withAlpha(200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.document_scanner_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Bharat Document Scanner AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Premium Office Studio', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              title: Text(isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'),
              trailing: Switch(
                value: isDark,
                onChanged: (val) async {
                  appThemeMode.value = val ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dark_mode', val);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette_rounded),
              title: const Text('Change Theme Color'),
              subtitle: const Text('Teal, Blue, Red, Purple & more'),
              onTap: _openThemeColorPicker,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_shared_rounded),
              title: const Text('Documents Manager'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentTabIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.widgets_rounded),
              title: const Text('Office & AI Studio'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentTabIndex = 1);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About App'),
              subtitle: const Text('Bharat Document Scanner AI v3.0'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search documents...', border: InputBorder.none),
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: appPrimaryColor.value, borderRadius: BorderRadius.circular(6)),
                    child: const Text('BHARAT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text('DOC SCANNER AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, size: 24),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Themes',
            onPressed: _openThemeColorPicker,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab()),
              // Clean Ad Space container at bottom as in the Screenshot
              if (_isBannerLoaded && _bannerAd != null)
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                )
              else
                Container(
                  height: 38,
                  alignment: Alignment.center,
                  child: const Text('Ad Space', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
            ],
          ),
          // Dual Pill Floating Button [ 📷 | ➕ ] placed at bottom right above Ad Space
          Positioned(
            right: 18,
            bottom: _isBannerLoaded && _bannerAd != null ? (_bannerAd!.size.height.toDouble() + 14) : 52,
            child: _buildDualFab(),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_shared_rounded, color: _currentTabIndex == 0 ? appPrimaryColor.value : Colors.grey.shade400),
                    const SizedBox(height: 2),
                    Text('Documents', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 0 ? appPrimaryColor.value : Colors.grey.shade400)),
                  ],
                ),
              ),
              // Camera button in center as was originally present
              IconButton(
                icon: Icon(Icons.camera_alt_rounded, color: appPrimaryColor.value, size: 28),
                tooltip: 'Scan Document',
                onPressed: () => _startDocScan(),
              ),
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.widgets_rounded, color: _currentTabIndex == 1 ? appPrimaryColor.value : Colors.grey.shade400),
                    const SizedBox(height: 2),
                    Text('Studio Tools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 1 ? appPrimaryColor.value : Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocsTab() {
    int totalPages = _savedDocs.fold(0, (sum, item) => sum + (item['pages'] as int? ?? 1));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withAlpha(50)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Files', '${_savedDocs.length}', Icons.description_rounded, appPrimaryColor.value),
              Container(height: 30, width: 1, color: Colors.grey.shade300),
              _buildStatItem('Pages Scanned', '$totalPages', Icons.auto_stories_rounded, Colors.orange),
              Container(height: 30, width: 1, color: Colors.grey.shade300),
              _buildStatItem('AI Engine', 'Active ⚡', Icons.security_rounded, Colors.blueGrey),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', 'Starred', 'ID Cards', 'Documents', 'Passports', 'Invoices'].map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  selectedColor: appPrimaryColor.value,
                  labelStyle: TextStyle(color: isSel ? Colors.white : null, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 12),
                  onSelected: (val) => setState(() {
                    _selectedCategory = cat;
                    _filterDocs();
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Saved Documents (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(
              children: [
                IconButton(
                  tooltip: _sortAscending ? 'Sort by Date' : 'Sort A-Z',
                  icon: Icon(_sortAscending ? Icons.sort_by_alpha_rounded : Icons.sort_rounded, size: 20),
                  onPressed: () => setState(() {
                    _sortAscending = !_sortAscending;
                    _filterDocs();
                  }),
                ),
                IconButton(
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: appPrimaryColor.value.withAlpha(25), shape: BoxShape.circle),
                  child: Icon(Icons.document_scanner_rounded, size: 40, color: appPrimaryColor.value),
                ),
                const SizedBox(height: 14),
                const Text("No documents saved yet", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Scan Document / ID Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddDocumentBottomSheet,
                ),
              ],
            ),
          )
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.68),
            itemBuilder: (ctx, i) => _buildGridCard(_filteredDocs[i]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) => _buildListCard(_filteredDocs[i]),
          ),
      ],
    );
  }

  Widget _buildStatItem(String title, String count, IconData icon, Color color) {
    return Column(
      children: [
        Row(children: [Icon(icon, size: 15, color: color), const SizedBox(width: 4), Text(count, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color))]),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildListCard(Map<String, dynamic> doc) {
    final List imgList = doc['images'] ?? [];
    final hasImage = imgList.isNotEmpty && File(imgList.first).existsSync();
    final isFav = doc['isFavorite'] == true;

    return InkWell(
      onTap: () => _openDocumentViewer(doc),
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0.5,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.withAlpha(40))),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasImage ? Image.file(File(imgList.first), width: 68, height: 86, fit: BoxFit.cover) : Container(width: 68, height: 86, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded, color: isFav ? Colors.amber : Colors.grey, size: 20), onPressed: () => _toggleFavorite(doc['id'])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${doc['pages']} pages • ${doc['date']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildActionPill(Icons.download_rounded, 'Save', () => _saveToDeviceStorage(imgList, doc['title'])),
                          const SizedBox(width: 6),
                          _buildActionPill(Icons.picture_as_pdf_rounded, 'PDF', () => _exportPdfWithScale(imgList, doc['title'])),
                          const SizedBox(width: 6),
                          _buildActionPill(Icons.image_rounded, 'JPG', () => _shareImages(imgList, doc['title'])),
                          const SizedBox(width: 6),
                          _buildActionPill(Icons.tune_rounded, 'Resize', () => _openCompressionDialog(imgList, doc['title'])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _deleteDoc(doc['id'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> doc) {
    final List imgList = doc['images'] ?? [];
    final hasImage = imgList.isNotEmpty && File(imgList.first).existsSync();

    return InkWell(
      onTap: () => _openDocumentViewer(doc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.withAlpha(40))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: hasImage ? Image.file(File(imgList.first), width: double.infinity, fit: BoxFit.cover) : Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))))),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1),
                  Text('${doc['pages']} pages', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.download_rounded, size: 18), onPressed: () => _saveToDeviceStorage(imgList, doc['title'])),
                      IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.red), onPressed: () => _exportPdfWithScale(imgList, doc['title'])),
                      IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.tune_rounded, size: 18), onPressed: () => _openCompressionDialog(imgList, doc['title'])),
                      IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => _deleteDoc(doc['id'])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: appPrimaryColor.value.withAlpha(20), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: appPrimaryColor.value),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: appPrimaryColor.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        _buildSectionHeader('Smart AI Scan Modes'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(title: 'ID Card Mode', subtitle: 'Front & Back A4', icon: Icons.badge_outlined, iconColor: const Color(0xFF1976D2), onTap: () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card')),
            _buildToolCard(title: 'Single Card', subtitle: 'Aadhaar / PAN', icon: Icons.credit_card_rounded, iconColor: const Color(0xFF00796B), onTap: () => _startDocScan(limit: 1, category: 'ID Cards', prefix: 'Card')),
            _buildToolCard(title: 'Passport', subtitle: 'Full Layout', icon: Icons.menu_book_rounded, iconColor: const Color(0xFF388E3C), onTap: () => _startDocScan(limit: 2, category: 'Passports', prefix: 'Passport')),
            _buildToolCard(title: 'Smart Invoices', subtitle: 'Bill Extract', icon: Icons.receipt_long_rounded, iconColor: const Color(0xFFE65100), onTap: () => _startDocScan(limit: 5, category: 'Invoices', prefix: 'Bill')),
            _buildToolCard(
              title: 'AI OCR',
              subtitle: 'Extract Text',
              icon: Icons.auto_awesome,
              iconColor: const Color(0xFF6A1B9A),
              onTap: () {
                if (_savedDocs.isNotEmpty && _savedDocs.first['images'].isNotEmpty) {
                  _extractTextWithAI(_savedDocs.first['images'][0]);
                } else {
                  _startDocScan();
                }
              },
            ),
            _buildToolCard(title: 'From Gallery', subtitle: 'Import Images', icon: Icons.photo_library_outlined, iconColor: const Color(0xFFD81B60), onTap: () => _startDocScan()),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Office & Productivity Suite'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(title: 'PowerPoint', subtitle: 'Slides Maker', icon: Icons.slideshow_rounded, iconColor: const Color(0xFFD84315), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard(title: 'Resume Maker', subtitle: 'Pro CV Generator', icon: Icons.assignment_ind_rounded, iconColor: const Color(0xFF0277BD), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildToolCard(title: 'Invoice Maker', subtitle: 'GST Bill & Tax', icon: Icons.receipt_rounded, iconColor: const Color(0xFF2E7D32), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard(title: 'Letters', subtitle: 'Formal Templates', icon: Icons.mail_outline_rounded, iconColor: const Color(0xFF6A1B9A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard(title: 'TXT Editor', subtitle: 'Create & Edit', icon: Icons.edit_note_rounded, iconColor: const Color(0xFF00796B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: false)))),
            _buildToolCard(title: 'Notes Maker', subtitle: 'Quick Notes', icon: Icons.note_alt_outlined, iconColor: const Color(0xFFF57C00), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: true)))),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Image & PDF Studio'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(
              title: 'PDF Studio',
              subtitle: 'Merge & Split',
              icon: Icons.picture_as_pdf_rounded,
              iconColor: const Color(0xFFD32F2F),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfStudioScreen(
                    savedDocs: _savedDocs,
                    onExportPdf: (paths, title) => _exportPdfWithScale(paths, title),
                  ),
                ),
              ),
            ),
            _buildToolCard(title: 'Passport Photo', subtitle: '8 & 16 Print Sheet', icon: Icons.portrait_rounded, iconColor: const Color(0xFF1565C0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
            _buildToolCard(title: 'Digital Sign', subtitle: 'Crop PNG Sign', icon: Icons.draw_rounded, iconColor: const Color(0xFF7B1FA2), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildToolCard(
              title: 'Compressor',
              subtitle: 'Smart Slider',
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF00796B),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  final doc = _savedDocs.first;
                  _openCompressionDialog(doc['images'], doc['title']);
                } else {
                  _showToast('Scan a document first to compress.');
                }
              },
            ),
            _buildToolCard(title: 'Watermark', subtitle: 'Custom Stamp', icon: Icons.branding_watermark_outlined, iconColor: const Color(0xFF0288D1), onTap: () => _openWatermarkDialog()),
            _buildToolCard(title: 'Photo Studio', subtitle: 'Physical Rotate', icon: Icons.crop_rotate_rounded, iconColor: const Color(0xFF00897B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
          ],
        ),
        const SizedBox(height: 70), // Padding so FAB doesn't hide last cards
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: appPrimaryColor.value),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToolCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.withAlpha(40), width: 1.2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withAlpha(20)), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// 3. UPGRADED DOCUMENT DETAIL SCREEN
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  final Function(Map<String, dynamic>) onDocUpdated;
  final Function(String) onExtractText;
  final Function(List, String) onSharePdf;
  final Function(List, String) onShareImages;
  final Function(List, String) onCompress;
  final Function(List, String) onSaveToPhone;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
    required this.onDelete,
    required this.onDocUpdated,
    required this.onExtractText,
    required this.onSharePdf,
    required this.onShareImages,
    required this.onCompress,
    required this.onSaveToPhone,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<String> _images;
  late List<String> _originalImages;
  late String _title;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _originalImages = List<String>.from(widget.doc['originalImages'] ?? widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
    _pageController = PageController();
  }

  void _renameDoc() {
    final ctrl = TextEditingController(text: _title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _title = ctrl.text.trim();
                widget.doc['title'] = _title;
              });
              widget.onDocUpdated(widget.doc);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewPages() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 20),
    );
    try {
      final res = await scanner.scanDocument();
      if (res?.images != null && res!.images.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');

        for (int i = 0; i < res.images.length; i++) {
          final tempF = File(res.images[i]);
          if (await tempF.exists()) {
            final targetPath = '${scansDir.path}/doc_${DateTime.now().millisecondsSinceEpoch}_add$i.jpg';
            await tempF.copy(targetPath);
            _images.add(targetPath);
            _originalImages.add(targetPath);
          }
        }

        setState(() {
          widget.doc['images'] = _images;
          widget.doc['originalImages'] = _originalImages;
          widget.doc['pages'] = _images.length;
        });
        widget.onDocUpdated(widget.doc);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${res.images.length} new page(s).')));
        }
      }
    } catch (e) {
      debugPrint("Add page err: $e");
    }
  }

  void _deleteCurrentPage() {
    if (_images.length <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Document?'),
          content: const Text('This is the only page in the document. Deleting it will remove the whole document.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDelete();
                Navigator.pop(context);
              },
              child: const Text('Delete Doc'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this page?'),
        content: Text('Do you want to delete Page ${_currentPage + 1}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final removedPath = _images.removeAt(_currentPage);
              if (_originalImages.length > _currentPage) {
                _originalImages.removeAt(_currentPage);
              }

              final f = File(removedPath);
              if (await f.exists()) await f.delete();

              setState(() {
                widget.doc['images'] = _images;
                widget.doc['originalImages'] = _originalImages;
                widget.doc['pages'] = _images.length;
                if (_currentPage >= _images.length) {
                  _currentPage = _images.length - 1;
                }
              });
              widget.onDocUpdated(widget.doc);
            },
            child: const Text('Delete Page'),
          ),
        ],
      ),
    );
  }

  void _resetToOriginalImage() {
    if (_currentPage < _originalImages.length) {
      setState(() {
        _images[_currentPage] = _originalImages[_currentPage];
        widget.doc['images'] = _images;
      });
      widget.onDocUpdated(widget.doc);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored original unfiltered photo.')));
    }
  }

  Future<void> _applyFilter(int mode) async {
    if (_images.isEmpty) return;

    ColorFilter? filter;
    if (mode == 1) {
      filter = const ColorFilter.matrix([
        1.25, 0, 0, 0, -10,
        0, 1.25, 0, 0, -10,
        0, 0, 1.25, 0, -10,
        0, 0, 0, 1, 0,
      ]);
    } else if (mode == 2) {
      filter = const ColorFilter.matrix([
        1.5, 1.5, 1.5, 0, -160,
        1.5, 1.5, 1.5, 0, -160,
        1.5, 1.5, 1.5, 0, -160,
        0, 0, 0, 1, 0,
      ]);
    } else if (mode == 3) {
      filter = const ColorFilter.matrix([
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0.299, 0.587, 0.114, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }

    if (filter == null) return;

    final sourcePath = (_currentPage < _originalImages.length) ? _originalImages[_currentPage] : _images[_currentPage];
    final currFile = File(sourcePath);
    final bytes = await currFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
    final paint = Paint()..colorFilter = filter;
    canvas.drawImage(img, Offset.zero, paint);

    final picture = recorder.endRecording();
    final outputImg = await picture.toImage(img.width, img.height);
    final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final newFile = File('${appDir.path}/scans/filtered_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());

      setState(() {
        _images[_currentPage] = newFile.path;
        widget.doc['images'] = _images;
      });
      widget.onDocUpdated(widget.doc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filter applied. Tap "Reset" anytime to revert.')));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: _renameDoc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 14, color: Colors.white70),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white), tooltip: 'Add Pages', onPressed: _addNewPages),
          IconButton(icon: const Icon(Icons.download_rounded, color: Colors.white), tooltip: 'Save to Phone', onPressed: () => widget.onSaveToPhone(_images, _title)),
          IconButton(icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent), tooltip: 'Delete Page', onPressed: _deleteCurrentPage),
        ],
      ),
      body: _images.isEmpty
          ? const Center(child: Text('No images available', style: TextStyle(color: Colors.white)))
          : Stack(
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: Colors.black87,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Page ${_currentPage + 1} of ${_images.length}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent, visualDensity: VisualDensity.compact),
                                icon: const Icon(Icons.restore_rounded, size: 16),
                                label: const Text('Reset', style: TextStyle(fontSize: 12)),
                                onPressed: _resetToOriginalImage,
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<int>(
                                onSelected: _applyFilter,
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(value: 1, child: Text('✨ Magic Color')),
                                  PopupMenuItem(value: 2, child: Text('📄 High Contrast B&W')),
                                  PopupMenuItem(value: 3, child: Text('🩶 Crisp Grayscale')),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: appPrimaryColor.value, borderRadius: BorderRadius.circular(10)),
                                  child: const Row(
                                    children: [
                                      Text('Filters', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _images.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (ctx, i) {
                          final file = File(_images[i]);
                          if (!file.existsSync()) return const Center(child: Text('Image file not found', style: TextStyle(color: Colors.white)));
                          return InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.file(file, fit: BoxFit.contain),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_currentPage > 0)
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withAlpha(150),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                          onPressed: () {
                            _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                          },
                        ),
                      ),
                    ),
                  ),
                if (_currentPage < _images.length - 1)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withAlpha(150),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                          onPressed: () {
                            _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomAction(Icons.download_rounded, 'Save to Phone', () => widget.onSaveToPhone(_images, _title)),
              _buildBottomAction(Icons.picture_as_pdf_rounded, 'Share PDF', () => widget.onSharePdf(_images, _title)),
              _buildBottomAction(Icons.image_rounded, 'Share JPG', () => widget.onShareImages(_images, _title)),
              _buildBottomAction(Icons.tune_rounded, 'Compress', () => widget.onCompress(_images, _title)),
              _buildBottomAction(Icons.auto_awesome, 'AI Insights', () {
                if (_images.isNotEmpty) widget.onExtractText(_images[_currentPage]);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// 4. PDF STUDIO SCREEN
class PdfStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  final Function(List, String) onExportPdf;

  const PdfStudioScreen({super.key, required this.savedDocs, required this.onExportPdf});

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedMergeDocIds = {};

  String? _selectedSplitDocId;
  final Set<int> _selectedSplitPageIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.savedDocs.isNotEmpty) {
      _selectedSplitDocId = widget.savedDocs.first['id'];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _executeMerge() {
    if (_selectedMergeDocIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 documents to merge.')));
      return;
    }

    List<String> combinedImages = [];
    for (String id in _selectedMergeDocIds) {
      final doc = widget.savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) {
        combinedImages.addAll(List<String>.from(doc['images']));
      }
    }

    if (combinedImages.isNotEmpty) {
      widget.onExportPdf(combinedImages, "Merged_Document_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    }
  }

  void _executeSplit() {
    if (_selectedSplitDocId == null || _selectedSplitPageIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a document and at least 1 page to extract.')));
      return;
    }

    final doc = widget.savedDocs.firstWhere((d) => d['id'] == _selectedSplitDocId, orElse: () => {});
    if (doc.isNotEmpty && doc['images'] != null) {
      final allImgs = List<String>.from(doc['images']);
      List<String> chosenImgs = [];
      for (int i in _selectedSplitPageIndices) {
        if (i < allImgs.length) chosenImgs.add(allImgs[i]);
      }

      if (chosenImgs.isNotEmpty) {
        widget.onExportPdf(chosenImgs, "${doc['title']}_Split_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Studio (Merge & Split)'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: appPrimaryColor.value,
          labelColor: appPrimaryColor.value,
          tabs: const [
            Tab(icon: Icon(Icons.merge_type_rounded), text: 'Merge PDFs'),
            Tab(icon: Icon(Icons.call_split_rounded), text: 'Split / Extract'),
          ],
        ),
      ),
      body: widget.savedDocs.isEmpty
          ? const Center(child: Text('No scanned documents available. Scan some pages first!'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMergeTab(),
                _buildSplitTab(),
              ],
            ),
    );
  }

  Widget _buildMergeTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: appPrimaryColor.value.withAlpha(20),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Select 2 or more documents to combine into a single PDF.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.savedDocs.length,
            itemBuilder: (ctx, i) {
              final doc = widget.savedDocs[i];
              final isSelected = _selectedMergeDocIds.contains(doc['id']);
              return CheckboxListTile(
                activeColor: appPrimaryColor.value,
                title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${doc['pages']} pages • ${doc['date']}'),
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedMergeDocIds.add(doc['id']);
                    } else {
                      _selectedMergeDocIds.remove(doc['id']);
                    }
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text('Merge & Export PDF (${_selectedMergeDocIds.length} Selected)', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _executeMerge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitTab() {
    final currentDoc = widget.savedDocs.firstWhere((d) => d['id'] == _selectedSplitDocId, orElse: () => widget.savedDocs.first);
    final List imgs = currentDoc['images'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSplitDocId,
            decoration: const InputDecoration(labelText: 'Choose Document to Split', border: OutlineInputBorder()),
            items: widget.savedDocs.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['title'], overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSplitDocId = val;
                _selectedSplitPageIndices.clear();
              });
            },
          ),
          const SizedBox(height: 16),
          Text('Select Pages to Extract (${_selectedSplitPageIndices.length} chosen):', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              itemCount: imgs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75),
              itemBuilder: (ctx, idx) {
                final isChosen = _selectedSplitPageIndices.contains(idx);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isChosen) {
                        _selectedSplitPageIndices.remove(idx);
                      } else {
                        _selectedSplitPageIndices.add(idx);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isChosen ? appPrimaryColor.value : Colors.grey.shade400, width: isChosen ? 3 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(File(imgs[idx]), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Text('P${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (isChosen)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(Icons.check_circle, color: appPrimaryColor.value, size: 22),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Extract Selected Pages as New PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _executeSplit,
            ),
          ),
        ],
      ),
    );
  }
}

// 5. DIGITAL SIGNATURE STUDIO
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

    double minX = validPoints.first.dx;
    double maxX = validPoints.first.dx;
    double minY = validPoints.first.dy;
    double maxY = validPoints.first.dy;

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

    final paint = Paint()
      ..color = _penColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Signature_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My Digital Signature - Bharat Document Scanner AI');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature Studio'),
        actions: [
          IconButton(icon: const Icon(Icons.cleaning_services_rounded), tooltip: 'Clear', onPressed: () => setState(() => _points.clear())),
          IconButton(icon: Icon(Icons.check_rounded, color: appPrimaryColor.value, size: 28), tooltip: 'Export Signature', onPressed: _saveSignature),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sign with finger inside box:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Row(
                  children: [Colors.black, Colors.blue.shade900, Colors.red.shade900].map((c) {
                    return InkWell(
                      onTap: () => setState(() => _penColor = c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: _penColor == c ? Colors.black : Colors.transparent, width: 2)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    RenderBox renderBox = context.findRenderObject() as RenderBox;
                    _points.add(renderBox.globalToLocal(details.globalPosition));
                  });
                },
                onPanEnd: (DragEndDetails details) => _points.add(null),
                child: CustomPaint(painter: _SignaturePainter(points: _points, color: _penColor), size: Size.infinite),
              ),
            ),
          ),
        ],
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
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 6. PASSPORT PHOTO STUDIO
class PassportPhotoStudioScreen extends StatefulWidget {
  const PassportPhotoStudioScreen({super.key});
  @override
  State<PassportPhotoStudioScreen> createState() => _PassportPhotoStudioScreenState();
}

class _PassportPhotoStudioScreenState extends State<PassportPhotoStudioScreen> {
  String? _selectedImagePath;
  int _photoCount = 8;

  Future<void> _pickPhoto() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1),
    );
    try {
      final res = await scanner.scanDocument();
      if (res?.images != null && res!.images.isNotEmpty) {
        setState(() => _selectedImagePath = res.images.first);
      }
    } catch (e) {
      debugPrint("Photo capture err: $e");
    }
  }

  Future<void> _generateA4PrintSheet() async {
    if (_selectedImagePath == null) return;

    final pdf = pw.Document();
    final imgBytes = await File(_selectedImagePath!).readAsBytes();
    final passImage = pw.MemoryImage(imgBytes);

    final double width = _photoCount == 8 ? 110 : 80;
    final double height = _photoCount == 8 ? 145 : 105;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Header(level: 0, text: 'Bharat Document Scanner AI - Passport Sheet ($_photoCount Layout)'),
              pw.SizedBox(height: 16),
              pw.Wrap(
                spacing: 12,
                runSpacing: 16,
                children: List.generate(_photoCount, (index) {
                  return pw.Container(
                    width: width,
                    height: height,
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                    child: pw.Image(passImage, fit: pw.BoxFit.cover),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Passport_Sheet_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Maker')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 160,
                height: 200,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400, width: 2)),
                child: _selectedImagePath != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(_selectedImagePath!), fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.portrait, size: 80, color: Colors.grey), Text('Select or Capture Face', style: TextStyle(fontSize: 11, color: Colors.grey))]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Capture / Choose Portrait Photo'),
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              onPressed: _pickPhoto,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Layout Option: ', style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 8, label: Text('8 Photos')),
                    ButtonSegment(value: 16, label: Text('16 Photos')),
                  ],
                  selected: {_photoCount},
                  onSelectionChanged: (set) => setState(() => _photoCount = set.first),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedImagePath != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: Text('Generate $_photoCount-Photo A4 Print PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
                onPressed: _generateA4PrintSheet,
              ),
          ],
        ),
      ),
    );
  }
}

// 7. UNIVERSAL IMAGE TOOLS (Physical 90° Rotate)
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imagePath;

  Future<void> _selectImage() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1),
    );
    try {
      final res = await scanner.scanDocument();
      if (res?.images != null && res!.images.isNotEmpty) {
        setState(() => _imagePath = res.images.first);
      }
    } catch (_) {}
  }

  Future<void> _rotatePhysically() async {
    if (_imagePath == null) return;
    final file = File(_imagePath!);
    final bytes = await file.readAsBytes();

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.height.toDouble(), img.width.toDouble()));
    canvas.translate(img.height.toDouble() / 2, img.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(img, Offset(-img.width.toDouble() / 2, -img.height.toDouble() / 2), Paint());

    final picture = recorder.endRecording();
    final rotatedImg = await picture.toImage(img.height, img.width);
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
          if (_imagePath != null) IconButton(icon: const Icon(Icons.rotate_right_rounded), tooltip: 'Rotate 90°', onPressed: _rotatePhysically),
          if (_imagePath != null) IconButton(icon: Icon(Icons.share_rounded, color: appPrimaryColor.value), onPressed: () => Share.shareXFiles([XFile(_imagePath!)])),
        ],
      ),
      body: Center(
        child: _imagePath == null
            ? ElevatedButton.icon(
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Select Photo from Camera/Gallery'),
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: _selectImage,
              )
            : Image.file(File(_imagePath!)),
      ),
    );
  }
}

// 8. POWERPOINT STUDIO
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

  void _addNewSlide() {
    setState(() => _slides.add({'title': 'New Slide Title', 'content': 'Write key points here...'}));
  }

  Future<void> _exportSlidesAsPdf() async {
    final pdf = pw.Document();
    for (int i = 0; i < _slides.length; i++) {
      final s = _slides[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(32),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal, width: 3)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 20),
                  pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18)),
                  pw.Spacer(),
                  pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Text('Slide ${i + 1} of ${_slides.length} • Bharat Document Scanner AI', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
                ],
              ),
            );
          },
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Presentation_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Exported PowerPoint Slides (PDF)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerPoint Presentation Studio'),
        actions: [
          IconButton(icon: Icon(Icons.share_rounded, color: appPrimaryColor.value), tooltip: 'Export as PDF', onPressed: _exportSlidesAsPdf),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slides.length,
        itemBuilder: (ctx, i) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: appPrimaryColor.value, width: 1.5)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Slide ${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor.value)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          if (_slides.length > 1) setState(() => _slides.removeAt(i));
                        },
                      ),
                    ],
                  ),
                  TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Slide Title', border: OutlineInputBorder()), onChanged: (val) => _slides[i]['title'] = val),
                  const SizedBox(height: 10),
                  TextFormField(initialValue: _slides[i]['content'], maxLines: 4, decoration: const InputDecoration(labelText: 'Content Bullets', border: OutlineInputBorder()), onChanged: (val) => _slides[i]['content'] = val),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: appPrimaryColor.value,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Slide'),
        onPressed: _addNewSlide,
      ),
    );
  }
}

// 9. TXT EDITOR & NOTES MAKER
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

  Future<void> _exportFile() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.isNotes) {
      await prefs.setString('saved_note_title', _titleCtrl.text.trim());
      await prefs.setString('saved_note_body', _bodyCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note permanently saved.')));
    }

    if (_bodyCtrl.text.trim().isEmpty) return;
    final dir = await getTemporaryDirectory();
    final name = _titleCtrl.text.trim().isEmpty ? 'Document' : _titleCtrl.text.trim();
    final file = File("${dir.path}/$name.txt");
    await file.writeAsString(_bodyCtrl.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported from Bharat Document Scanner AI');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNotes ? 'Smart Notes' : 'TXT File Editor'),
        actions: [IconButton(icon: Icon(Icons.save_rounded, color: appPrimaryColor.value), onPressed: _exportFile)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: InputDecoration(hintText: widget.isNotes ? 'Note Title...' : 'File Name...', border: InputBorder.none, hintStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            Expanded(child: TextField(controller: _bodyCtrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Start typing here...', border: InputBorder.none))),
          ],
        ),
      ),
    );
  }
}

// 10. PRO RESUME BUILDER
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
  final _experience = TextEditingController(text: '• 3 Years Experience in Project Management\n• Client Relationship & Operations');
  final _education = TextEditingController(text: '• Bachelor of Technology (First Class)');
  final _skills = TextEditingController(text: 'MS Office, Teamwork, Communication, Problem Solving');

  Future<void> _generateResumePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_name.text, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                pw.Text('${_phone.text} | ${_email.text}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.Divider(thickness: 1.5, color: PdfColors.teal),
                pw.SizedBox(height: 10),
                _buildPdfSection('Profile Summary', _summary.text),
                _buildPdfSection('Work Experience', _experience.text),
                _buildPdfSection('Education', _education.text),
                _buildPdfSection('Skills & Competencies', _skills.text),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Resume_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Professional Resume - Bharat Document Scanner AI');
  }

  pw.Widget _buildPdfSection(String title, String body) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
          pw.SizedBox(height: 4),
          pw.Text(body, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pro Resume Builder (CV)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Profile Summary', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _experience, maxLines: 3, decoration: const InputDecoration(labelText: 'Work Experience', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _education, maxLines: 2, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate Resume PDF'),
              onPressed: _generateResumePdf,
            ),
          ],
        ),
      ),
    );
  }
}

// 11. INVOICE MAKER WITH REAL GST CALCULATION (18% Split)
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _clientName = TextEditingController(text: 'Client / Company Name');
  final _invoiceNum = TextEditingController(text: 'INV-2026-001');
  final _itemName = TextEditingController();
  final _itemPrice = TextEditingController();
  List<Map<String, dynamic>> items = [
    {'name': 'Consulting Service', 'price': 1500.0},
    {'name': 'Document Processing', 'price': 800.0},
  ];

  Future<void> _exportInvoicePdf() async {
    final pdf = pw.Document();
    double subtotal = items.fold(0.0, (s, i) => s + (i['price'] as double));
    double cgst = subtotal * 0.09;
    double sgst = subtotal * 0.09;
    double grandTotal = subtotal + cgst + sgst;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                pw.SizedBox(height: 8),
                pw.Text('Invoice No: ${_invoiceNum.text} | Client: ${_clientName.text}'),
                pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
                pw.Divider(thickness: 1.5, color: PdfColors.teal),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['Item / Service Description', 'Amount (INR)'],
                  data: items.map((e) => [e['name'], 'INR ${e['price']}']).toList(),
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
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Invoice_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Tax Invoice PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice & Bill Maker')),
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
                Expanded(child: TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _itemPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (INR)', border: OutlineInputBorder()))),
                IconButton(
                  icon: Icon(Icons.add_circle, color: appPrimaryColor.value, size: 36),
                  onPressed: () {
                    if (_itemName.text.isNotEmpty && _itemPrice.text.isNotEmpty) {
                      setState(() {
                        items.add({'name': _itemName.text.trim(), 'price': double.tryParse(_itemPrice.text.trim()) ?? 0.0});
                        _itemName.clear();
                        _itemPrice.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((i) => ListTile(
                  title: Text(i['name']),
                  trailing: Text('INR ${i['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate Invoice PDF'),
              onPressed: items.isEmpty ? null : _exportInvoicePdf,
            ),
          ],
        ),
      ),
    );
  }
}

// 12. LETTER TEMPLATES
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _letterCtrl = TextEditingController(
    text: "To,\nThe Manager,\nSubject: Leave Application\n\nDear Sir/Madam,\nI am writing to formally request 2 days of leave due to urgent personal work.\n\nThank you.\nSincerely,\n[Your Name]",
  );

  Future<void> _exportLetterPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Text(_letterCtrl.text, style: const pw.TextStyle(fontSize: 14, lineSpacing: 3)),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Letter_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter PDF - Bharat Document Scanner AI');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letter Maker Templates'),
        actions: [
          IconButton(icon: Icon(Icons.share, color: appPrimaryColor.value), onPressed: _exportLetterPdf),
        ],
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
                  onPressed: () => setState(() => _letterCtrl.text = "To,\nThe HR Manager,\nSubject: Request for Leave\n\nRespected Sir/Madam,\nPlease grant me leave for 2 days due to an urgent family matter.\n\nRegards,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation Letter'),
                  onPressed: () => setState(() => _letterCtrl.text = "To,\nThe HR Manager,\nSubject: Formal Resignation\n\nDear Sir/Madam,\nPlease accept this letter as formal notification that I am resigning from my position."),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(controller: _letterCtrl, maxLines: null, expands: true, decoration: const InputDecoration(border: OutlineInputBorder())),
            ),
          ],
        ),
      ),
    );
  }
}
