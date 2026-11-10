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

// ============================================================================
// GLOBAL CONTROLLERS & LOCALIZATION
// ============================================================================
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
// Default Theme Color: Vibrant Pink
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFFE91E63));
// Language state: false = English, true = Hindi
final ValueNotifier<bool> isHindiLanguage = ValueNotifier(false);

class AppLang {
  static String tr(String key) {
    final bool hi = isHindiLanguage.value;
    final Map<String, List<String>> dict = {
      'docs': ['Documents', 'दस्तावेज़'],
      'tools': ['Studio Tools', 'स्टूडियो टूल्स'],
      'search': ['Search documents...', 'दस्तावेज़ खोजें...'],
      'total_files': ['Total Files', 'कुल फाइलें'],
      'scanned_pages': ['Pages Scanned', 'स्कैन पेज'],
      'all': ['All', 'सभी'],
      'starred': ['Starred', 'पसंदीदा'],
      'new_folder': ['+ New Folder', '+ नया फ़ोल्डर'],
      'create_folder': ['Create New Folder', 'नया फ़ोल्डर बनाएं'],
      'folder_name': ['Folder Name', 'फ़ोल्डर का नाम'],
      'cancel': ['Cancel', 'रद्द करें'],
      'create': ['Create', 'बनाएं'],
      'save': ['Save to Docs', 'सेव करें'],
      'merge_pdf': ['Merge to PDF', 'मर्ज PDF'],
      'share': ['Share', 'शेयर करें'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents saved yet', 'अभी तक कोई दस्तावेज़ नहीं है'],
      'scan_now': ['Scan Document Now', 'डॉक्यूमेंट स्कैन करें'],
      'select_all': ['Select All', 'सभी चुनें'],
      'choose_folder': ['Save to Folder:', 'फ़ोल्डर चुनें:'],
    };
    if (dict.containsKey(key)) {
      return hi ? dict[key]![1] : dict[key]![0];
    }
    return key;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("AdMob Init: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final colorVal = prefs.getInt('primary_color_val');
  if (colorVal != null) {
    appPrimaryColor.value = Color(colorVal);
  }

  isHindiLanguage.value = prefs.getBool('app_language_hindi') ?? false;

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
            return ValueListenableBuilder<bool>(
              valueListenable: isHindiLanguage,
              builder: (_, __, ____) {
                return MaterialApp(
                  title: 'Bharat Document Scanner AI',
                  debugShowCheckedModeBanner: false,
                  themeMode: mode,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
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
      },
    );
  }
}

// ============================================================================
// 1. SPLASH SCREEN (Logo-less, Text Typographic Intro)
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 2200), () {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [appPrimaryColor.value, appPrimaryColor.value.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: appPrimaryColor.value.withOpacity(0.4), blurRadius: 28, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFCE4EC), Color(0xFFF48FB1)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: const Text(
                      'BHARAT',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Text(
                    'DOCUMENT SCANNER AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.5,
                      color: Color(0xFFF06292),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public, size: 14, color: Color(0xFF80DEEA)),
                        SizedBox(width: 6),
                        Text('Global AI Document Suite', style: TextStyle(color: Color(0xFFE0F2F1), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MAIN DASHBOARD SCREEN (Folders, Multi-Select, Real Ads, Play Store Ready)
// ============================================================================
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _savedDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _userFolders = ['All', 'General', 'Personal', 'Work', 'Invoices', 'Starred'];
  bool _isSearching = false;
  bool _isGridView = false;
  String _selectedCategory = 'All';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();

  // Multi-Selection System
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  // Real Production AdMob Ad Unit IDs
  final String _bannerId = 'ca-app-pub-7940311763952252/4182204348';
  final String _interstitialId = 'ca-app-pub-7940311763952252/1256658100';

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadUserFolders();
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

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _loadInterstitialAd();
    }
  }

  Future<void> _loadUserFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v1');
    if (customFolders != null && customFolders.isNotEmpty) {
      setState(() {
        _userFolders = ['All', ...customFolders, 'Starred'];
      });
    }
  }

  Future<void> _createNewFolderDialog() async {
    final folderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: appPrimaryColor.value),
            const SizedBox(width: 8),
            Text(AppLang.tr('create_folder'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: folderCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLang.tr('folder_name'),
            hintText: 'e.g. Bills, Taxes, Personal...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            onPressed: () async {
              final name = folderCtrl.text.trim();
              if (name.isNotEmpty && !_userFolders.contains(name)) {
                final prefs = await SharedPreferences.getInstance();
                final currentCustom = _userFolders.where((f) => f != 'All' && f != 'Starred').toList();
                currentCustom.add(name);
                await prefs.setStringList('custom_user_folders_v1', currentCustom);
                setState(() {
                  _userFolders = ['All', ...currentCustom, 'Starred'];
                  _selectedCategory = name;
                });
                _filterDocs();
                Navigator.pop(ctx);
              }
            },
            child: Text(AppLang.tr('create')),
          ),
        ],
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
            (_selectedCategory == 'Starred' ? (doc['isFavorite'] == true) : (doc['category'] ?? 'General') == _selectedCategory);
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

  Future<void> _saveDocToStorage(String title, List<String> rawPaths, {String category = 'General'}) async {
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
    _showToast('✅ Saved successfully');
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
      _selectedDocIds.remove(id);
      _filterDocs();
    });
    await _commitDocsToPrefs();
    _showToast('Document deleted permanently');
  }

  void _deleteSelectedDocs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Documents?'),
        content: Text('Are you sure you want to delete ${_selectedDocIds.length} items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              for (String id in _selectedDocIds.toList()) {
                _deleteDoc(id);
              }
              setState(() {
                _isSelectionMode = false;
                _selectedDocIds.clear();
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _mergeAndShareSelectedDocs() async {
    if (_selectedDocIds.isEmpty) return;
    _showInterstitialAd();

    List<String> allSelectedImgs = [];
    for (String id in _selectedDocIds) {
      final doc = _savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) {
        allSelectedImgs.addAll(List<String>.from(doc['images']));
      }
    }

    if (allSelectedImgs.isNotEmpty) {
      await _exportPdfWithScale(allSelectedImgs, "Merged_Docs_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    }
  }

  Future<void> _startDocScan({int limit = 50, String category = 'General', String prefix = 'Doc', bool galleryOnly = false}) async {
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
        _promptDocNameAndFolder(result.images, prefix, category);
      }
    } catch (e) {
      debugPrint("Scan Err: $e");
    }
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
          category: 'Personal',
        );
      }
    } catch (e) {
      if (mounted) _promptDocNameAndFolder(frontAndBack, prefix, 'Personal');
    }
  }

  void _promptDocNameAndFolder(List<String> images, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = (defaultCat == 'All' || defaultCat == 'Starred') ? 'General' : defaultCat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final foldersAvailable = _userFolders.where((f) => f != 'All' && f != 'Starred').toList();
          if (!foldersAvailable.contains(chosenFolder)) {
            foldersAvailable.add(chosenFolder);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: appPrimaryColor.value),
                const SizedBox(width: 8),
                Text(AppLang.tr('save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ ${images.length} page(s) ready.', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Document Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(AppLang.tr('choose_folder'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: chosenFolder,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  items: foldersAvailable.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => chosenFolder = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr('cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveDocToStorage(nameCtrl.text.trim(), images, category: chosenFolder);
                },
                child: Text(AppLang.tr('save')),
              ),
            ],
          );
        },
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
                      decoration: BoxDecoration(color: appPrimaryColor.value.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
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
                  onChanged: (val) => setDialogState(() => scaleSlider = val),
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
                label: const Text('Save Safely'),
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

  // Google Play Scoped Storage Compliant Saver
  Future<void> _saveToDeviceStorage(List images, String title, {double scale = 1.0}) async {
    try {
      final pdf = await _generatePdfDoc(images, scale: scale);
      Directory? appDir = await getExternalStorageDirectory();
      appDir ??= await getApplicationDocumentsDirectory();

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = "${appDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());

      _showToast('📁 Saved safely: ${file.path}');
      await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Document Scanner AI');
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
    _showInterstitialAd();
    final pdf = await _generatePdfDoc(images, scale: scale, watermark: watermark);
    final dir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File("${dir.path}/$safeName.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Document Scanner AI');
  }

  Future<void> _shareImages(List images, String title) async {
    List<XFile> shareFiles = [];
    for (int i = 0; i < images.length; i++) {
      final f = File(images[i]);
      if (await f.exists()) shareFiles.add(XFile(f.path));
    }
    if (shareFiles.isNotEmpty) {
      await Share.shareXFiles(shareFiles, text: '$title - Bharat Document Scanner AI');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: appPrimaryColor.value, duration: const Duration(seconds: 2)),
    );
  }

  // Multi-Theme Picker Dialog
  void _openThemeColorPicker() {
    final colors = [
      {'name': 'Pink (Default)', 'color': const Color(0xFFE91E63)},
      {'name': 'Emerald Teal', 'color': const Color(0xFF00796B)},
      {'name': 'Ocean Cyan', 'color': const Color(0xFF0288D1)},
      {'name': 'Ruby Red', 'color': const Color(0xFFD32F2F)},
      {'name': 'Saffron Orange', 'color': const Color(0xFFFF6F00)},
      {'name': 'Royal Sapphire', 'color': const Color(0xFF1565C0)},
      {'name': 'Amethyst Purple', 'color': const Color(0xFF7B1FA2)},
      {'name': 'Forest Green', 'color': const Color(0xFF2E7D32)},
      {'name': 'Midnight Charcoal', 'color': const Color(0xFF263238)},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Choose Color Theme', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: colors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (ctx, i) {
              final item = colors[i];
              final col = item['color'] as Color;
              final isSelected = appPrimaryColor.value.value == col.value;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: col,
                        border: Border.all(color: isSelected ? Colors.black : Colors.white, width: isSelected ? 3 : 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(item['name'] as String, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Compact Dual Pill Button [ 📷 | ➕ ]
  Widget _buildDualFab() {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, themeColor, __) {
        return Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor, themeColor.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                onTap: () => _startDocScan(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.4)),
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                onTap: () => _startDocScan(galleryOnly: true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        );
      },
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
      drawer: _buildAppDrawer(isDark),
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedDocIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            : (_isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(hintText: AppLang.tr('search'), border: InputBorder.none),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: appPrimaryColor.value, borderRadius: BorderRadius.circular(6)),
                        child: const Text('AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text('BHARAT SCANNER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: AppLang.tr('select_all'),
              icon: const Icon(Icons.select_all_rounded),
              onPressed: () {
                setState(() {
                  if (_selectedDocIds.length == _filteredDocs.length) {
                    _selectedDocIds.clear();
                  } else {
                    _selectedDocIds.addAll(_filteredDocs.map((d) => d['id'].toString()));
                  }
                });
              },
            ),
            IconButton(
              tooltip: AppLang.tr('merge_pdf'),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _selectedDocIds.isEmpty ? null : _mergeAndShareSelectedDocs,
            ),
            IconButton(
              tooltip: AppLang.tr('delete'),
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: _selectedDocIds.isEmpty ? null : _deleteSelectedDocs,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedDocIds.clear();
              }),
            ),
          ] else ...[
            TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.translate_rounded, size: 16),
              label: Text(isHindiLanguage.value ? 'हिन्दी' : 'EN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () async {
                final nextVal = !isHindiLanguage.value;
                isHindiLanguage.value = nextVal;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('app_language_hindi', nextVal);
              },
            ),
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search_rounded, size: 22),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              }),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab(),
          Positioned(right: 16, bottom: 16, child: _buildDualFab()),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: ValueListenableBuilder<Color>(
        valueListenable: appPrimaryColor,
        builder: (_, col, __) {
          return Container(
            height: 52,
            width: 52,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [col, col.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: col.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: FloatingActionButton(
              shape: const CircleBorder(),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              onPressed: () => _startDocScan(),
              child: const Icon(Icons.camera_alt_rounded, size: 24),
            ),
          );
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 6,
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(AppLang.tr('docs'), Icons.folder_special_rounded, _currentTabIndex == 0, () => setState(() => _currentTabIndex = 0)),
                const SizedBox(width: 48),
                _buildNavItem(AppLang.tr('tools'), Icons.auto_awesome_mosaic_rounded, _currentTabIndex == 1, () => setState(() => _currentTabIndex = 1)),
              ],
            ),
          ),
          if (_isBannerLoaded && _bannerAd != null)
            SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, bool isSel, VoidCallback onTap) {
    final color = isSel ? appPrimaryColor.value : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocsTab() {
    int totalPages = _savedDocs.fold(0, (sum, item) => sum + (item['pages'] as int? ?? 1));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(AppLang.tr('total_files'), '${_savedDocs.length}', Icons.insert_drive_file_rounded),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              _buildStat(AppLang.tr('scanned_pages'), '$totalPages', Icons.pages_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                avatar: Icon(Icons.add, size: 14, color: appPrimaryColor.value),
                label: Text(AppLang.tr('new_folder'), style: TextStyle(color: appPrimaryColor.value, fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: _createNewFolderDialog,
              ),
              const SizedBox(width: 6),
              ..._userFolders.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    selectedColor: appPrimaryColor.value,
                    labelStyle: TextStyle(color: isSel ? Colors.white : null, fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                    onSelected: (val) => setState(() {
                      _selectedCategory = cat;
                      _filterDocs();
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Documents (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Row(
              children: [
                if (!_isSelectionMode && _filteredDocs.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Select', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _isSelectionMode = true),
                  ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 18),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ],
        ),

        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 50, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(AppLang.tr('no_docs'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: Text(AppLang.tr('scan_now')),
                    onPressed: () => _startDocScan(),
                  ),
                ],
              ),
            ),
          )
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
            itemBuilder: (ctx, i) => _buildDocGridCard(_filteredDocs[i]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) => _buildDocListTile(_filteredDocs[i]),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStat(String label, String count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: appPrimaryColor.value),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildDocListTile(Map<String, dynamic> doc) {
    final String id = doc['id'];
    final bool isSelected = _selectedDocIds.contains(id);
    final List imgs = doc['images'] ?? [];
    final bool hasImage = imgs.isNotEmpty && File(imgs.first).existsSync();

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? appPrimaryColor.value : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: hasImage ? Image.file(File(imgs.first), width: 50, height: 60, fit: BoxFit.cover) : Container(width: 50, height: 60, color: Colors.grey.shade200),
            ),
            if (_isSelectionMode)
              Positioned(
                top: 0,
                left: 0,
                child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? appPrimaryColor.value : Colors.white),
              ),
          ],
        ),
        title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
        subtitle: Text('${doc['pages']} pages • ${doc['category'] ?? 'General'} • ${doc['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: _isSelectionMode
            ? Checkbox(
                activeColor: appPrimaryColor.value,
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedDocIds.add(id);
                    } else {
                      _selectedDocIds.remove(id);
                    }
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onPressed: () => _openDocDetail(doc),
              ),
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedDocIds.remove(id);
              } else {
                _selectedDocIds.add(id);
              }
            });
          } else {
            _openDocDetail(doc);
          }
        },
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedDocIds.add(id);
          });
        },
      ),
    );
  }

  Widget _buildDocGridCard(Map<String, dynamic> doc) {
    final String id = doc['id'];
    final bool isSelected = _selectedDocIds.contains(id);
    final List imgs = doc['images'] ?? [];
    final bool hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedDocIds.remove(id);
            } else {
              _selectedDocIds.add(id);
            }
          });
        } else {
          _openDocDetail(doc);
        }
      },
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedDocIds.add(id);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? appPrimaryColor.value : Colors.grey.withOpacity(0.2), width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: hasImg ? Image.file(File(imgs.first), fit: BoxFit.cover) : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  if (_isSelectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: appPrimaryColor.value),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Text('${doc['pages']} p • ${doc['category'] ?? 'General'}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocDetail(Map<String, dynamic> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          doc: doc,
          onDelete: () => _deleteDoc(doc['id']),
          onDocUpdated: _updateExistingDoc,
          onExtractText: _extractTextWithAI,
          onSharePdf: (paths, title) => _exportPdfWithScale(paths, title),
          onShareImages: _shareImages,
          onCompress: (paths, title) => _openCompressionDialog(paths, title),
          onSaveToPhone: _saveToDeviceStorage,
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
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard(title: 'ID Card Mode', subtitle: 'Front & Back', icon: Icons.badge_outlined, iconColor: const Color(0xFF1976D2), onTap: () => _startDocScan(limit: 2, category: 'Personal', prefix: 'ID_Card')),
            _buildToolCard(title: 'Passport', subtitle: 'Full Layout', icon: Icons.menu_book_rounded, iconColor: const Color(0xFF388E3C), onTap: () => _startDocScan(limit: 2, category: 'Personal', prefix: 'Passport')),
            _buildToolCard(title: 'Invoices', subtitle: 'Bill Extract', icon: Icons.receipt_long_rounded, iconColor: const Color(0xFFE65100), onTap: () => _startDocScan(limit: 5, category: 'Invoices', prefix: 'Bill')),
            _buildToolCard(title: 'AI OCR', subtitle: 'Extract Text', icon: Icons.auto_awesome, iconColor: const Color(0xFF6A1B9A), onTap: () {
              if (_savedDocs.isNotEmpty && _savedDocs.first['images'].isNotEmpty) {
                _extractTextWithAI(_savedDocs.first['images'][0]);
              } else {
                _startDocScan();
              }
            }),
            _buildToolCard(title: 'From Gallery', subtitle: 'Import Images', icon: Icons.photo_library_outlined, iconColor: const Color(0xFFD81B60), onTap: () => _startDocScan(galleryOnly: true)),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Office & Productivity Suite'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard(title: 'PowerPoint', subtitle: 'Slides Maker', icon: Icons.slideshow_rounded, iconColor: const Color(0xFFD84315), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard(title: 'Resume Maker', subtitle: 'Pro CV Maker', icon: Icons.assignment_ind_rounded, iconColor: const Color(0xFF0277BD), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildToolCard(title: 'Invoice Maker', subtitle: 'GST Bill & Tax', icon: Icons.receipt_rounded, iconColor: const Color(0xFF2E7D32), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard(title: 'Letters', subtitle: 'Formal Templates', icon: Icons.mail_outline_rounded, iconColor: const Color(0xFF6A1B9A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard(title: 'TXT Editor', subtitle: 'Create & Edit', icon: Icons.edit_note_rounded, iconColor: const Color(0xFF00796B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: false)))),
            _buildToolCard(title: 'Notes Maker', subtitle: 'Quick Notes', icon: Icons.note_alt_outlined, iconColor: const Color(0xFFF57C00), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: true)))),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Image & PDF Studio'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard(title: 'PDF Studio', subtitle: 'Merge & Split', icon: Icons.picture_as_pdf_rounded, iconColor: const Color(0xFFD32F2F), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfStudioScreen(savedDocs: _savedDocs, onExportPdf: (paths, title) => _exportPdfWithScale(paths, title))))),
            _buildToolCard(title: 'Passport Photo', subtitle: 'Print Sheet', icon: Icons.portrait_rounded, iconColor: const Color(0xFF1565C0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
            _buildToolCard(title: 'Digital Sign', subtitle: 'Sign PNG', icon: Icons.draw_rounded, iconColor: const Color(0xFF7B1FA2), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildToolCard(title: 'Compressor', subtitle: 'Smart Slider', icon: Icons.tune_rounded, iconColor: const Color(0xFF00796B), onTap: () {
              if (_savedDocs.isNotEmpty) {
                final doc = _savedDocs.first;
                _openCompressionDialog(doc['images'], doc['title']);
              } else {
                _showToast('Scan a document first to compress.');
              }
            }),
            _buildToolCard(title: 'Watermark', subtitle: 'Custom Stamp', icon: Icons.branding_watermark_outlined, iconColor: const Color(0xFF0288D1), onTap: _openWatermarkDialog),
            _buildToolCard(title: 'Photo Rotate', subtitle: '90° Angle', icon: Icons.crop_rotate_rounded, iconColor: const Color(0xFF00897B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: appPrimaryColor.value),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToolCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withOpacity(0.15)), child: Icon(icon, color: iconColor, size: 22)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(bool isDark) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: appPrimaryColor.value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.document_scanner_rounded, size: 36, color: Colors.white),
                SizedBox(height: 8),
                Text('BHARAT SCANNER AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Global Document Edition', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          ListTile(
            leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            title: Text(isDark ? 'Light Mode' : 'Dark Mode'),
            onTap: () async {
              appThemeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_dark_mode', !isDark);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: const Text('Change Theme Color'),
            onTap: _openThemeColorPicker,
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Language / भाषा'),
            subtitle: Text(isHindiLanguage.value ? 'हिन्दी (Hindi)' : 'English'),
            trailing: Switch(
              value: isHindiLanguage.value,
              activeColor: appPrimaryColor.value,
              onChanged: (val) async {
                isHindiLanguage.value = val;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('app_language_hindi', val);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: const Text('Privacy Policy'),
            subtitle: const Text('Google Play Policy Compliant'),
            onTap: () {
              Navigator.pop(context);
              _showToast('Privacy Policy: All document files remain secure locally on your device.');
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. UPGRADED DOCUMENT DETAIL SCREEN (Filters, Multi-Page Selection, OCR)
// ============================================================================
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

  bool _isPageSelectionMode = false;
  final Set<int> _selectedPageIndices = {};

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

  void _shareOnlySelectedPagesPdf() {
    if (_selectedPageIndices.isEmpty) return;
    List<String> chosen = [];
    for (int idx in _selectedPageIndices) {
      if (idx < _images.length) chosen.add(_images[idx]);
    }
    widget.onSharePdf(chosen, "${_title}_Pages");
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
          IconButton(
            tooltip: 'Select Specific Pages',
            icon: Icon(_isPageSelectionMode ? Icons.check_circle : Icons.checklist_rounded,
                color: _isPageSelectionMode ? appPrimaryColor.value : Colors.white),
            onPressed: () {
              setState(() {
                _isPageSelectionMode = !_isPageSelectionMode;
                if (!_isPageSelectionMode) _selectedPageIndices.clear();
              });
            },
          ),
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
                if (_isPageSelectionMode)
                  Positioned(
                    top: 55,
                    right: 16,
                    child: FilterChip(
                      selected: _selectedPageIndices.contains(_currentPage),
                      label: Text(_selectedPageIndices.contains(_currentPage) ? 'Page Selected ✓' : 'Select This Page'),
                      selectedColor: appPrimaryColor.value,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedPageIndices.add(_currentPage);
                          } else {
                            _selectedPageIndices.remove(_currentPage);
                          }
                        });
                      },
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
              _buildBottomAction(Icons.download_rounded, 'Save PDF', () => widget.onSaveToPhone(_images, _title)),
              if (_isPageSelectionMode)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                  icon: const Icon(Icons.share, size: 16),
                  label: Text('Share (${_selectedPageIndices.length}) Pgs'),
                  onPressed: _selectedPageIndices.isEmpty ? null : _shareOnlySelectedPagesPdf,
                )
              else
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

// ============================================================================
// 4. PDF STUDIO (Merge & Split Tabbed Suite)
// ============================================================================
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
    List<String> combined = [];
    for (String id in _selectedMergeDocIds) {
      final doc = widget.savedDocs.firstWhere((d) => d['id'] == id, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) {
        combined.addAll(List<String>.from(doc['images']));
      }
    }
    if (combined.isNotEmpty) {
      widget.onExportPdf(combined, "Merged_Doc_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    }
  }

  void _executeSplit() {
    if (_selectedSplitDocId == null || _selectedSplitPageIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select pages to extract.')));
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
        widget.onExportPdf(chosenImgs, "${doc['title']}_Extracted");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Studio'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: appPrimaryColor.value,
          labelColor: appPrimaryColor.value,
          tabs: const [
            Tab(text: 'Merge PDFs'),
            Tab(text: 'Split / Extract'),
          ],
        ),
      ),
      body: widget.savedDocs.isEmpty
          ? const Center(child: Text('No documents scanned yet.'))
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
        Expanded(
          child: ListView.builder(
            itemCount: widget.savedDocs.length,
            itemBuilder: (ctx, i) {
              final doc = widget.savedDocs[i];
              final isSel = _selectedMergeDocIds.contains(doc['id']);
              return CheckboxListTile(
                activeColor: appPrimaryColor.value,
                title: Text(doc['title'] ?? 'Untitled'),
                subtitle: Text('${doc['pages']} pages'),
                value: isSel,
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
              icon: const Icon(Icons.picture_as_pdf),
              label: Text('Merge Selected (${_selectedMergeDocIds.length})'),
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
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSplitDocId,
            decoration: const InputDecoration(labelText: 'Choose Document', border: OutlineInputBorder()),
            items: widget.savedDocs.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['title']))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSplitDocId = val;
                _selectedSplitPageIndices.clear();
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              itemCount: imgs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
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
                    decoration: BoxDecoration(border: Border.all(color: isChosen ? appPrimaryColor.value : Colors.grey, width: isChosen ? 3 : 1)),
                    child: Image.file(File(imgs[idx]), fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
              onPressed: _executeSplit,
              child: const Text('Extract Selected Pages to PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. DIGITAL SIGNATURE STUDIO
// ============================================================================
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
      await Share.shareXFiles([XFile(file.path)], text: 'My Signature - Bharat Document Scanner AI');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature'),
        actions: [
          IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _points.clear())),
          IconButton(icon: const Icon(Icons.check), onPressed: _saveSignature),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
          onPanEnd: (_) => _points.add(null),
          child: CustomPaint(painter: _SigPainter(_points, _penColor), size: Size.infinite),
        ),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  _SigPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeCap = StrokeCap.round..strokeWidth = 3.5;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// 6. PASSPORT PHOTO STUDIO (8 & 16 Photos Layout)
// ============================================================================
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
    if (res?.images != null && res!.images.isNotEmpty) {
      setState(() => _selectedImagePath = res.images.first);
    }
  }

  Future<void> _generateSheet() async {
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
          return pw.Wrap(
            spacing: 12,
            runSpacing: 16,
            children: List.generate(_photoCount, (i) => pw.Container(width: width, height: height, child: pw.Image(passImage, fit: pw.BoxFit.cover))),
          );
        },
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Passport_Sheet.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Sheet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImagePath != null) Image.file(File(_selectedImagePath!), height: 180) else const Icon(Icons.portrait, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _pickPhoto, child: const Text('Choose Portrait Photo')),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 8, label: Text('8 Photos')),
                ButtonSegment(value: 16, label: Text('16 Photos')),
              ],
              selected: {_photoCount},
              onSelectionChanged: (set) => setState(() => _photoCount = set.first),
            ),
            if (_selectedImagePath != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white), onPressed: _generateSheet, child: Text('Generate $_photoCount-Photo Sheet')),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. UNIVERSAL IMAGE ROTATE (Physical 90°)
// ============================================================================
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imagePath;

  Future<void> _select() async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: true, pageLimit: 1));
    final res = await scanner.scanDocument();
    if (res?.images != null && res!.images.isNotEmpty) setState(() => _imagePath = res.images.first);
  }

  Future<void> _rotate() async {
    if (_imagePath == null) return;
    final bytes = await File(_imagePath!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, img.height.toDouble(), img.width.toDouble()));
    canvas.translate(img.height.toDouble() / 2, img.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(img, Offset(-img.width.toDouble() / 2, -img.height.toDouble() / 2), Paint());

    final outImg = await recorder.endRecording().toImage(img.height, img.width);
    final data = await outImg.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final f = File('${appDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(data.buffer.asUint8List());
      setState(() => _imagePath = f.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Rotate Studio'),
        actions: [
          if (_imagePath != null) IconButton(icon: const Icon(Icons.rotate_right), onPressed: _rotate),
          if (_imagePath != null) IconButton(icon: const Icon(Icons.share), onPressed: () => Share.shareXFiles([XFile(_imagePath!)])),
        ],
      ),
      body: Center(
        child: _imagePath == null ? ElevatedButton(onPressed: _select, child: const Text('Select Image')) : Image.file(File(_imagePath!)),
      ),
    );
  }
}

// ============================================================================
// 8. POWERPOINT STUDIO
// ============================================================================
class PowerPointStudioScreen extends StatefulWidget {
  const PowerPointStudioScreen({super.key});
  @override
  State<PowerPointStudioScreen> createState() => _PowerPointStudioScreenState();
}

class _PowerPointStudioScreenState extends State<PowerPointStudioScreen> {
  final List<Map<String, String>> _slides = [
    {'title': 'Project Intro', 'content': '• Objectives\n• Key Deliverables'},
  ];

  Future<void> _export() async {
    final pdf = pw.Document();
    for (var s in _slides) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 16),
                pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Presentation.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'PowerPoint Slides');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slides Maker'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _export)]),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slides.length,
        itemBuilder: (ctx, i) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Title'), onChanged: (v) => _slides[i]['title'] = v),
                TextFormField(initialValue: _slides[i]['content'], maxLines: 3, decoration: const InputDecoration(labelText: 'Bullets'), onChanged: (v) => _slides[i]['content'] = v),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: appPrimaryColor.value,
        foregroundColor: Colors.white,
        onPressed: () => setState(() => _slides.add({'title': 'New Slide', 'content': '• Point 1\n• Point 2'})),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================================
// 9. TXT & NOTES MAKER
// ============================================================================
class TxtEditorNotesScreen extends StatefulWidget {
  final bool isNotes;
  const TxtEditorNotesScreen({super.key, required this.isNotes});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isNotes) {
      SharedPreferences.getInstance().then((p) {
        setState(() {
          _title.text = p.getString('saved_note_title') ?? '';
          _body.text = p.getString('saved_note_body') ?? '';
        });
      });
    }
  }

  Future<void> _export() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.isNotes) {
      await prefs.setString('saved_note_title', _title.text.trim());
      await prefs.setString('saved_note_body', _body.text.trim());
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${_title.text.isEmpty ? 'Note' : _title.text}.txt");
    await file.writeAsString(_body.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Note');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isNotes ? 'Quick Notes' : 'TXT Editor'), actions: [IconButton(icon: const Icon(Icons.save), onPressed: _export)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'Title...', border: InputBorder.none)),
            const Divider(),
            Expanded(child: TextField(controller: _body, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Start typing...', border: InputBorder.none))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 10. RESUME BUILDER (Full Fields + Clean CV Layout)
// ============================================================================
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Kumar');
  final _phone = TextEditingController(text: '+91 98765 43210');
  final _email = TextEditingController(text: 'rahul.kumar@email.com');
  final _summary = TextEditingController(text: 'Dedicated professional seeking growth opportunities.');
  final _experience = TextEditingController(text: '• 2+ Years experience in Operations & IT.');
  final _education = TextEditingController(text: '• Bachelor of Technology / Graduate');
  final _skills = TextEditingController(text: 'Teamwork, Problem Solving, Communication');

  Future<void> _export() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text('${_phone.text} | ${_email.text}'),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.SizedBox(height: 8),
              pw.Text('Profile Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_summary.text),
              pw.SizedBox(height: 8),
              pw.Text('Work Experience:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_experience.text),
              pw.SizedBox(height: 8),
              pw.Text('Education:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_education.text),
              pw.SizedBox(height: 8),
              pw.Text('Skills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_skills.text),
            ],
          ),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Resume.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Professional Resume');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Summary', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _experience, maxLines: 2, decoration: const InputDecoration(labelText: 'Experience', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _education, maxLines: 2, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)), onPressed: _export, child: const Text('Generate Resume PDF')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 11. INVOICE MAKER (Itemized List + 9%+9% Real GST Tax Calculation)
// ============================================================================
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _client = TextEditingController(text: 'Client Name');
  final _invoiceNum = TextEditingController(text: 'INV-2026-001');
  final _itemName = TextEditingController();
  final _itemPrice = TextEditingController();
  List<Map<String, dynamic>> items = [
    {'name': 'Document Services', 'price': 1200.0},
    {'name': 'Processing Fee', 'price': 300.0},
  ];

  Future<void> _export() async {
    final pdf = pw.Document();
    double sub = items.fold(0.0, (s, i) => s + (i['price'] as double));
    double cgst = sub * 0.09;
    double sgst = sub * 0.09;
    double grandTotal = sub + cgst + sgst;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text('Invoice No: ${_invoiceNum.text} | Client: ${_client.text}'),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Service Description', 'Amount (INR)'],
                data: items.map((e) => [e['name'], 'INR ${e['price']}']).toList(),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.pink),
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
                    pw.Divider(),
                    pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.pink)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Tax_Invoice.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Tax Invoice');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice & GST Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _client, decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _invoiceNum, decoration: const InputDecoration(labelText: 'Invoice Number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _itemPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()))),
                IconButton(
                  icon: Icon(Icons.add_circle, color: appPrimaryColor.value, size: 32),
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
            const SizedBox(height: 10),
            ...items.map((i) => ListTile(
                  title: Text(i['name']),
                  trailing: Text('INR ${i['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
            const SizedBox(height: 16),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)), onPressed: items.isEmpty ? null : _export, child: const Text('Export Invoice PDF')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 12. LETTER TEMPLATES (Formal & Leave Letters)
// ============================================================================
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _ctrl = TextEditingController(
    text: "To,\nThe HR Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nPlease grant me 2 days of leave for urgent work.\n\nThank you.\nSincerely,\n[Your Name]",
  );

  Future<void> _export() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (ctx) => pw.Padding(padding: const pw.EdgeInsets.all(32), child: pw.Text(_ctrl.text, style: const pw.TextStyle(fontSize: 14)))));
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Letter.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Letter Maker'), actions: [IconButton(icon: const Icon(Icons.share), onPressed: _export)]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Leave Letter'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Manager,\nSubject: Leave Request\n\nRespected Sir,\nI request leave for 2 days due to personal reasons.\n\nRegards,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation Letter'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Management,\nSubject: Resignation Letter\n\nPlease accept this letter as formal notification of my resignation.\n\nRegards,\n[Your Name]"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: TextField(controller: _ctrl, maxLines: null, expands: true, decoration: const InputDecoration(border: OutlineInputBorder()))),
          ],
        ),
      ),
    );
  }
}
