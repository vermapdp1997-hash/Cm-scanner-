import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
// Default Theme Color: Emerald Teal
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFF00796B));
// Language state: false = English, true = Hindi
final ValueNotifier<bool> isHindiLanguage = ValueNotifier(false);

class AppLang {
  static String tr(String key) {
    final bool hi = isHindiLanguage.value;
    final Map<String, List<String>> dict = {
      'home': ['Home', 'होम'],
      'pdf_tools': ['PDF Tools', 'PDF टूल्स'],
      'import_id': ['Import ID Photo', 'आईडी फोटो'],
      'all_docs': ['All docs', 'सभी फाइलें'],
      'recent': ['Recent', 'हाल के'],
      'favourite': ['Favourite', 'पसंदीदा'],
      'business_card': ['Business Card', 'विजिटिंग कार्ड'],
      'folders': ['Folders', 'फ़ोल्डर्स'],
      'add_new_doc': ['Add New Document', 'नया दस्तावेज़ जोड़ें'],
      'choose_options': ['Choose from below options', 'नीचे दिए गए विकल्प चुनें'],
      'from_gallery': ['Import from Gallery', 'गैलरी से चुनें'],
      'from_camera': ['Scan from Camera', 'कैमरे से स्कैन करें'],
      'import_pdf_img': ['Import PDF as Image', 'PDF से इमेज बनाएं'],
      'import_docs': ['Import Documents (PDF, Word & More)', 'दस्तावेज़ इम्पोर्ट करें'],
      'add_more': ['+ Add More Pages', '+ और पेज जोड़ें'],
      'create_folder': ['Create New Folder', 'नया फ़ोल्डर बनाएं'],
      'folder_name': ['Folder Name', 'फ़ोल्डर का नाम'],
      'cancel': ['Cancel', 'रद्द करें'],
      'create': ['Create', 'बनाएं'],
      'save': ['Save', 'सेव करें'],
      'share': ['Share', 'शेयर करें'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents found', 'कोई दस्तावेज़ नहीं मिला'],
      'select_all': ['Select All', 'सभी चुनें'],
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
  } else {
    appPrimaryColor.value = const Color(0xFF00796B); // Default Emerald Teal
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
                  title: 'Bharat Doc Scanner',
                  debugShowCheckedModeBanner: false,
                  themeMode: mode,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    scaffoldBackgroundColor: const Color(0xFFF6F8F8),
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
                    scaffoldBackgroundColor: const Color(0xFF101413),
                    colorSchemeSeed: color,
                    appBarTheme: const AppBarTheme(
                      elevation: 0,
                      backgroundColor: Color(0xFF192220),
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
// 1. SPLASH SCREEN
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 1800), () {
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
      backgroundColor: const Color(0xFF003831),
      body: Center(
        child: FadeTransition(
          opacity: _animController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appPrimaryColor.value,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 54, color: Colors.white),
              ),
              const SizedBox(height: 22),
              const Text(
                'BHARAT DOC SCANNER',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Smart AI Document Suite',
                style: TextStyle(fontSize: 12, color: Color(0xFF80CBC4), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MAIN DASHBOARD SCREEN (Matches Screenshots 1 & 2)
// ============================================================================
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _topTabIndex = 0; // 0 = Home, 1 = PDF Tools, 2 = Import ID Photo
  List<Map<String, dynamic>> _savedDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _userFolders = ['ID Cards', 'New Folder', 'Bills', 'Personal', 'Office'];
  String _activeChip = 'All docs';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Multi-Selection System
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  // AdMob Ad Units (Supports Test Units in Debug to guarantee ads display)
  final String _bannerId = kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-7940311763952252/4182204348';
  final String _interstitialId = kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-7940311763952252/1256658100';

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
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _bannerId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint("Banner Ad Failed to load: $err");
          ad.dispose();
          // Retry loading after 12 seconds
          Future.delayed(const Duration(seconds: 12), () {
            if (mounted) _loadBannerAd();
          });
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
          debugPrint("Interstitial Ad Failed: $err");
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
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v3');
    if (customFolders != null && customFolders.isNotEmpty) {
      setState(() {
        _userFolders = customFolders;
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
            hintText: 'e.g. Invoices, Taxes, Medical...',
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
                final currentCustom = List<String>.from(_userFolders);
                currentCustom.add(name);
                await prefs.setStringList('custom_user_folders_v3', currentCustom);
                setState(() {
                  _userFolders = currentCustom;
                });
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
    final String? rawData = prefs.getString('saved_documents_v5');
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
    await prefs.setString('saved_documents_v5', jsonEncode(_savedDocs));
  }

  void _filterDocs() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final matchesSearch = title.contains(q);
        bool matchesCategory = true;
        if (_activeChip == 'Favourite') {
          matchesCategory = (doc['isFavorite'] == true);
        } else if (_activeChip == 'Recent') {
          matchesCategory = true;
        } else if (_activeChip != 'All docs') {
          matchesCategory = (doc['category'] == _activeChip);
        }
        return matchesSearch && matchesCategory;
      }).toList();

      // Rank order (Newest first)
      _filteredDocs.sort((a, b) => (b['id'] ?? '').toString().compareTo((a['id'] ?? '').toString()));
    });
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

      const cardW = 760.0;
      const cardH = 480.0;
      const left = (a4Width - cardW) / 2;
      final borderPaint = Paint()
        ..color = const Color(0xFFB0BEC5)
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
          text: 'Bharat Doc Scanner • Official Verified ID Layout',
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
      if (mounted) _promptDocNameAndFolder(frontAndBack, prefix, 'ID Cards');
    }
  }

  void _promptDocNameAndFolder(List<String> images, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = defaultCat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final foldersAvailable = List<String>.from(_userFolders);
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
                const Text('Save to Folder:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: foldersAvailable.contains(chosenFolder) ? chosenFolder : foldersAvailable.first,
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

  // ==========================================================================
  // SCREENSHOT 1: "Add New Document" Bottom Sheet Menu
  // ==========================================================================
  void _openAddNewDocumentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.note_add_rounded, color: Colors.cyan, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLang.tr('add_new_doc'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(AppLang.tr('choose_options'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              _buildModalListOption(
                icon: Icons.photo_size_select_actual_rounded,
                iconColor: const Color(0xFF00B0FF),
                title: AppLang.tr('from_gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan(galleryOnly: true);
                },
              ),
              _buildModalListOption(
                icon: Icons.photo_camera_rounded,
                iconColor: const Color(0xFF00796B),
                title: AppLang.tr('from_camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan();
                },
              ),
              _buildModalListOption(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFFF5722),
                title: AppLang.tr('import_pdf_img'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan(galleryOnly: true, prefix: 'PDF_Img');
                },
              ),
              _buildModalListOption(
                icon: Icons.description_rounded,
                iconColor: const Color(0xFFE91E63),
                title: AppLang.tr('import_docs'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startDocScan(galleryOnly: true, prefix: 'Imported');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalListOption({required IconData icon, required Color iconColor, required String title, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  // ==========================================================================
  // SCREENSHOT 2: Dual Pill Button on Bottom Right [ 📷  |  + ]
  // ==========================================================================
  Widget _buildDualFabPill() {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, themeColor, __) {
        return Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor, const Color(0xFF009688)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(26)),
                onTap: () => _startDocScan(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                ),
              ),
              Container(width: 1.2, height: 24, color: Colors.white.withOpacity(0.4)),
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(26)),
                onTap: _openAddNewDocumentSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 1 KB to 5 MB Precise Target Compressor
  void _openCompressionDialog(List<dynamic> images, String title) {
    double targetSizeKb = 350;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: appPrimaryColor.value),
                const SizedBox(width: 8),
                const Text('Smart Target Compressor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set target size limit (1 KB to 5 MB):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Target Limit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: appPrimaryColor.value.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        targetSizeKb >= 1000 ? '${(targetSizeKb / 1000).toStringAsFixed(1)} MB' : '${targetSizeKb.toInt()} KB',
                        style: TextStyle(color: appPrimaryColor.value, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: targetSizeKb,
                  min: 50,
                  max: 5000,
                  divisions: 99,
                  activeColor: appPrimaryColor.value,
                  onChanged: (val) => setDialogState(() => targetSizeKb = val),
                ),
                Wrap(
                  spacing: 6,
                  children: [100, 200, 500, 1000, 2000].map((preset) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(preset >= 1000 ? '${(preset / 1000).toInt()} MB' : '$preset KB', style: const TextStyle(fontSize: 10)),
                      onPressed: () => setDialogState(() => targetSizeKb = preset.toDouble()),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Compress PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportPdfWithTargetSize(images, "${title}_Compressed", targetKb: targetSizeKb.toInt());
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveToDeviceStorage(List images, String title, {int? targetKb}) async {
    try {
      final pdf = await _generatePdfDoc(images, targetKb: targetKb);
      Directory? appDir = await getExternalStorageDirectory();
      appDir ??= await getApplicationDocumentsDirectory();

      final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savePath = "${appDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(savePath);
      await file.writeAsBytes(await pdf.save());

      _showToast('📁 Saved safely: ${file.path}');
      await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Doc Scanner');
    } catch (e) {
      await _exportPdfWithTargetSize(images, title, targetKb: targetKb);
    }
  }

  Future<pw.Document> _generatePdfDoc(List images, {int? targetKb}) async {
    final pdf = pw.Document();
    final double perPageKb = (targetKb != null && images.isNotEmpty) ? (targetKb / images.length) : 800;

    for (var path in images) {
      final f = File(path);
      if (await f.exists()) {
        Uint8List finalBytes;
        final rawBytes = await f.readAsBytes();

        if (perPageKb < 600) {
          int targetW = 1200;
          if (perPageKb < 150) {
            targetW = 750;
          } else if (perPageKb < 300) {
            targetW = 950;
          }

          final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: targetW);
          final frame = await codec.getNextFrame();
          final resizedData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          finalBytes = resizedData != null ? resizedData.buffer.asUint8List() : rawBytes;
        } else {
          finalBytes = rawBytes;
        }

        final img = pw.MemoryImage(finalBytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) {
              return pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain));
            },
          ),
        );
      }
    }
    return pdf;
  }

  Future<void> _exportPdfWithTargetSize(List images, String title, {int? targetKb}) async {
    _showInterstitialAd();
    final pdf = await _generatePdfDoc(images, targetKb: targetKb);
    final dir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File("${dir.path}/$safeName.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Bharat Doc Scanner');
  }

  Future<void> _shareImages(List images, String title) async {
    List<XFile> shareFiles = [];
    for (int i = 0; i < images.length; i++) {
      final f = File(images[i]);
      if (await f.exists()) shareFiles.add(XFile(f.path));
    }
    if (shareFiles.isNotEmpty) {
      await Share.shareXFiles(shareFiles, text: '$title - Bharat Doc Scanner');
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
                    const Text('Extracted OCR Text', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
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
            const SizedBox(height: 12),
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

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: appPrimaryColor.value, duration: const Duration(seconds: 2)),
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
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search documents...', border: InputBorder.none),
              )
            : const Text(
                'Bharat Doc Scanner',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.amber),
            tooltip: 'VIP Features',
            onPressed: () => _showToast('⭐ Bharat Doc Scanner Pro Active'),
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'folder') _createNewFolderDialog();
              if (val == 'lang') {
                isHindiLanguage.value = !isHindiLanguage.value;
                SharedPreferences.getInstance().then((p) => p.setBool('app_language_hindi', isHindiLanguage.value));
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'folder', child: Text(AppLang.tr('create_folder'))),
              PopupMenuItem(value: 'lang', child: Text(isHindiLanguage.value ? 'Switch to English' : 'हिंदी में बदलें')),
            ],
          ),
        ],
      ),
      drawer: _buildAppDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopTabBar(),
              _buildSubChipsRow(),
              Expanded(
                child: _topTabIndex == 0
                    ? _buildHomeDocsList()
                    : (_topTabIndex == 1 ? _buildPdfToolsView() : _buildImportIdView()),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 60,
            child: _buildDualFabPill(),
          ),
        ],
      ),
      bottomNavigationBar: _isBannerLoaded && _bannerAd != null
          ? SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
    );
  }

  Widget _buildTopTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          _buildTopTabItem(0, Icons.home_rounded, AppLang.tr('home')),
          _buildTopTabItem(1, Icons.business_center_rounded, AppLang.tr('pdf_tools')),
          _buildTopTabItem(2, Icons.badge_outlined, AppLang.tr('import_id')),
        ],
      ),
    );
  }

  Widget _buildTopTabItem(int index, IconData icon, String label) {
    final bool isSel = _topTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _topTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSel ? appPrimaryColor.value : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSel ? appPrimaryColor.value : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? appPrimaryColor.value : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubChipsRow() {
    final chips = ['All docs', 'Recent', 'Favourite', 'Business Card', ..._userFolders];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final c = chips[i];
          final isSel = _activeChip == c;
          return ChoiceChip(
            label: Text(c, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
            selected: isSel,
            selectedColor: appPrimaryColor.value,
            onSelected: (val) {
              setState(() {
                _activeChip = c;
                _filterDocs();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildHomeDocsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Folders (${_userFolders.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            IconButton(
              icon: Icon(Icons.create_new_folder_rounded, color: appPrimaryColor.value, size: 22),
              onPressed: _createNewFolderDialog,
            ),
          ],
        ),
        ..._userFolders.map((folderName) {
          final count = _savedDocs.where((d) => d['category'] == folderName).length;
          return _buildFolderCard(folderName, count);
        }),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Documents (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (_filteredDocs.isNotEmpty)
              Text('${_filteredDocs.length} files available', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),

        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(AppLang.tr('no_docs'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Scan Now'),
                    onPressed: () => _startDocScan(),
                  ),
                ],
              ),
            ),
          )
        else
          ..._filteredDocs.map((doc) => _buildDocTile(doc)),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildFolderCard(String folderName, int fileCount) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.folder_rounded, color: Colors.white, size: 24),
        ),
        title: Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Folder • [$fileCount files]', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
        onTap: () {
          setState(() {
            _activeChip = folderName;
            _filterDocs();
          });
        },
      ),
    );
  }

  Widget _buildDocTile(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final bool hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: hasImg ? Image.file(File(imgs.first), width: 48, height: 56, fit: BoxFit.cover) : Container(width: 48, height: 56, color: Colors.grey.shade300),
        ),
        title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
        subtitle: Text('${doc['pages']} pages • ${doc['category'] ?? 'General'} • ${doc['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        onTap: () => _openDocDetail(doc),
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
          onSharePdf: (paths, title) => _exportPdfWithTargetSize(paths, title),
          onShareImages: _shareImages,
          onCompress: (paths, title) => _openCompressionDialog(paths, title),
          onSaveToPhone: _saveToDeviceStorage,
        ),
      ),
    );
  }

  // PDF & Productivity Studio View (All Tools Active)
  Widget _buildPdfToolsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('PDF Tools Suite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.merge_type_rounded, color: Color(0xFF00796B)),
          title: const Text('Merge PDFs'),
          subtitle: const Text('Combine multiple documents into one'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfStudioScreen(savedDocs: _savedDocs, onExportPdf: (p, t) => _exportPdfWithTargetSize(p, t)))),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.tune_rounded, color: Color(0xFF0288D1)),
          title: const Text('Compress PDF (1 KB to 5 MB)'),
          subtitle: const Text('Target limit compressor'),
          onTap: () {
            if (_savedDocs.isNotEmpty) {
              _openCompressionDialog(_savedDocs.first['images'], _savedDocs.first['title']);
            } else {
              _showToast('Please scan a document first.');
            }
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.draw_rounded, color: Color(0xFF7B1FA2)),
          title: const Text('Digital Signature'),
          subtitle: const Text('Sign PNG & Stamp'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.portrait_rounded, color: Color(0xFF1565C0)),
          title: const Text('Passport Photo Sheet'),
          subtitle: const Text('Print 8 or 16 passport photos'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.slideshow_rounded, color: Color(0xFFD84315)),
          title: const Text('PowerPoint Slides Maker'),
          subtitle: const Text('Create & export presentation slides'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF0277BD)),
          title: const Text('Resume / CV Builder'),
          subtitle: const Text('Professional CV maker with PDF export'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.receipt_rounded, color: Color(0xFF2E7D32)),
          title: const Text('Invoice & GST Bill Maker'),
          subtitle: const Text('Auto 9%+9% tax calculations'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.mail_outline_rounded, color: Color(0xFF6A1B9A)),
          title: const Text('Formal Letters & Applications'),
          subtitle: const Text('Templates for leave, resignation & more'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.note_alt_outlined, color: Color(0xFFF57C00)),
          title: const Text('TXT Editor & Quick Notes'),
          subtitle: const Text('Create, edit and share text notes'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen(isNotes: true))),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildImportIdView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_rounded, size: 64, color: appPrimaryColor.value),
          const SizedBox(height: 14),
          const Text('ID Card & Passport Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Scan Front & Back on Single A4 Sheet', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Start ID Card Scan'),
            onPressed: () => _startDocScan(limit: 2, category: 'ID Cards', prefix: 'ID_Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppDrawer() {
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
                Text('BHARAT DOC SCANNER', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Pro AI Scanning Edition', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: const Text('Theme Color'),
            subtitle: const Text('Emerald Teal (Active)'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.translate_rounded),
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
            subtitle: const Text('All files remain secure on your phone'),
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
// 3. DOCUMENT DETAIL SCREEN
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
  late List<String> _images;
  late List<String> _originalImages;
  late String _title;

  bool _isPageSelectionMode = false;
  final List<int> _selectedPageIndicesOrder = [];

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _originalImages = List<String>.from(widget.doc['originalImages'] ?? widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
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
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
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

  Future<void> _addMoreDocuments({bool gallery = false}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.full, isGalleryImport: gallery, pageLimit: 20),
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

  void _deleteSelectedPages() {
    if (_selectedPageIndicesOrder.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Pages?'),
        content: Text('Are you sure you want to delete ${_selectedPageIndicesOrder.length} page(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final sortedIndices = List<int>.from(_selectedPageIndicesOrder)..sort((a, b) => b.compareTo(a));
              for (int idx in sortedIndices) {
                if (idx < _images.length) {
                  final removedPath = _images.removeAt(idx);
                  if (idx < _originalImages.length) _originalImages.removeAt(idx);
                  final f = File(removedPath);
                  if (await f.exists()) await f.delete();
                }
              }

              if (_images.isEmpty) {
                widget.onDelete();
                Navigator.pop(context);
              } else {
                setState(() {
                  widget.doc['images'] = _images;
                  widget.doc['originalImages'] = _originalImages;
                  widget.doc['pages'] = _images.length;
                  _isPageSelectionMode = false;
                  _selectedPageIndicesOrder.clear();
                });
                widget.onDocUpdated(widget.doc);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openFullPhotoViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenPhotoViewer(
          images: _images,
          originalImages: _originalImages,
          initialIndex: initialIndex,
          title: _title,
          onDocUpdated: () {
            setState(() {
              _images = List<String>.from(widget.doc['images']);
            });
            widget.onDocUpdated(widget.doc);
          },
          onExtractText: widget.onExtractText,
        ),
      ),
    );
  }

  void _exportRankOrderedPdf() {
    if (_selectedPageIndicesOrder.isEmpty) return;
    List<String> orderedImgs = _selectedPageIndicesOrder.map((idx) => _images[idx]).toList();
    widget.onSharePdf(orderedImgs, "${_title}_SelectedOrder");
  }

  void _saveRankOrderedPhone() {
    if (_selectedPageIndicesOrder.isEmpty) return;
    List<String> orderedImgs = _selectedPageIndicesOrder.map((idx) => _images[idx]).toList();
    widget.onSaveToPhone(orderedImgs, "${_title}_SelectedOrder");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _renameDoc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 14),
            ],
          ),
        ),
        actions: [
          if (_isPageSelectionMode) ...[
            IconButton(
              tooltip: 'Delete Selected',
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              onPressed: _deleteSelectedPages,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isPageSelectionMode = false;
                _selectedPageIndicesOrder.clear();
              }),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select Pages Order',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => setState(() => _isPageSelectionMode = true),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Delete Document',
              onPressed: () {
                widget.onDelete();
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_images.length} Pages • Folder: ${widget.doc['category'] ?? 'General'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryColor.value,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: Text(AppLang.tr('add_more')),
                  onPressed: () => _addMoreDocuments(),
                ),
              ],
            ),
          ),
          if (_isPageSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              color: appPrimaryColor.value.withOpacity(0.12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selected: ${_selectedPageIndicesOrder.length} page(s) in Rank order', style: TextStyle(color: appPrimaryColor.value, fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: [
                      TextButton(onPressed: _saveRankOrderedPhone, child: const Text('Save PDF')),
                      TextButton(onPressed: _exportRankOrderedPdf, child: const Text('Share PDF')),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text('No pages in this document.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _images.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (ctx, idx) {
                      final rankIndex = _selectedPageIndicesOrder.indexOf(idx);
                      final isChosen = rankIndex != -1;
                      final file = File(_images[idx]);

                      return InkWell(
                        onTap: () {
                          if (_isPageSelectionMode) {
                            setState(() {
                              if (isChosen) {
                                _selectedPageIndicesOrder.remove(idx);
                              } else {
                                _selectedPageIndicesOrder.add(idx);
                              }
                            });
                          } else {
                            _openFullPhotoViewer(idx);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _isPageSelectionMode = true;
                            if (!isChosen) _selectedPageIndicesOrder.add(idx);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChosen ? appPrimaryColor.value : Colors.grey.withOpacity(0.3),
                              width: isChosen ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                  child: Text('P${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (_isPageSelectionMode)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isChosen ? appPrimaryColor.value : Colors.black45,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: Center(
                                      child: isChosen
                                          ? Text('${rankIndex + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionBtn(Icons.download_rounded, 'Save PDF', () => widget.onSaveToPhone(_images, _title)),
              _buildActionBtn(Icons.picture_as_pdf_rounded, 'Share PDF', () => widget.onSharePdf(_images, _title)),
              _buildActionBtn(Icons.image_rounded, 'Share JPG', () => widget.onShareImages(_images, _title)),
              _buildActionBtn(Icons.tune_rounded, 'Compress', () => widget.onCompress(_images, _title)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: appPrimaryColor.value, size: 22),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. FULL SCREEN PHOTO VIEWER
// ============================================================================
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> images;
  final List<String> originalImages;
  final int initialIndex;
  final String title;
  final VoidCallback onDocUpdated;
  final Function(String) onExtractText;

  const FullScreenPhotoViewer({
    super.key,
    required this.images,
    required this.originalImages,
    required this.initialIndex,
    required this.title,
    required this.onDocUpdated,
    required this.onExtractText,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageCtrl;
  late int _curPage;

  @override
  void initState() {
    super.initState();
    _curPage = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  void _resetImage() {
    if (_curPage < widget.originalImages.length) {
      setState(() {
        widget.images[_curPage] = widget.originalImages[_curPage];
      });
      widget.onDocUpdated();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored original unfiltered photo.')));
    }
  }

  Future<void> _applyAdvancedAIFilter(int filterType) async {
    if (widget.images.isEmpty) return;

    ColorFilter? filter;
    switch (filterType) {
      case 1:
        filter = const ColorFilter.matrix([
          1.55, 0.05, 0.05, 0, -32,
          0.05, 1.55, 0.05, 0, -32,
          0.05, 0.05, 1.55, 0, -32,
          0,    0,    0,    1, 0,
        ]);
        break;
      case 2:
        filter = const ColorFilter.matrix([
          2.1, 2.1, 2.1, 0, -280,
          2.1, 2.1, 2.1, 0, -280,
          2.1, 2.1, 2.1, 0, -280,
          0,   0,   0,   1, 0,
        ]);
        break;
      case 3:
        filter = const ColorFilter.matrix([
          1.35, 0,    0,    0, -6,
          0,    1.35, 0,    0, -6,
          0,    0,    1.35, 0, -6,
          0,    0,    0,    1, 0,
        ]);
        break;
      case 4:
        filter = const ColorFilter.matrix([
          1.25, 0,    0,    0, 35,
          0,    1.25, 0,    0, 35,
          0,    0,    1.25, 0, 35,
          0,    0,    0,    1, 0,
        ]);
        break;
      case 5:
        filter = const ColorFilter.matrix([
          0.30, 0.59, 0.11, 0, 0,
          0.30, 0.59, 0.11, 0, 0,
          0.30, 0.59, 0.11, 0, 0,
          0,    0,    0,    1, 0,
        ]);
        break;
    }

    if (filter == null) return;

    final sourcePath = (_curPage < widget.originalImages.length) ? widget.originalImages[_curPage] : widget.images[_curPage];
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
      final newFile = File('${appDir.path}/scans/ai_clean_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await newFile.writeAsBytes(byteData.buffer.asUint8List());

      setState(() {
        widget.images[_curPage] = newFile.path;
      });
      widget.onDocUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ AI Filter Applied. Tap Reset anytime to revert.')));
      }
    }
  }

  Future<void> _rotatePage() async {
    final curPath = widget.images[_curPage];
    final bytes = await File(curPath).readAsBytes();
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
      final f = File('${appDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(data.buffer.asUint8List());

      setState(() {
        widget.images[_curPage] = f.path;
      });
      widget.onDocUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.title} (${_curPage + 1}/${widget.images.length})', style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.rotate_right_rounded), tooltip: 'Rotate 90°', onPressed: _rotatePage),
          IconButton(icon: const Icon(Icons.restore_rounded, color: Colors.orangeAccent), tooltip: 'Reset Filter', onPressed: _resetImage),
          PopupMenuButton<int>(
            tooltip: 'AI Advance Filters',
            icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF80CBC4)),
            onSelected: _applyAdvancedAIFilter,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 1, child: Text('✨ AI Magic Whitener (Clean Paper)')),
              PopupMenuItem(value: 2, child: Text('📄 Super Deep B&W (Deep Black Text)')),
              PopupMenuItem(value: 3, child: Text('🎨 AI Vibrant HD Color (Stamps & Seals)')),
              PopupMenuItem(value: 4, child: Text('☀️ AI Shadow Remover (Lighting Fix)')),
              PopupMenuItem(value: 5, child: Text('🩶 Studio Grayscale Pro')),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _curPage = i),
        itemBuilder: (ctx, i) {
          final file = File(widget.images[i]);
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 5.0,
            child: Center(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : const Text('Image file not found', style: TextStyle(color: Colors.white)),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI OCR Text'),
                onPressed: () {
                  if (widget.images.isNotEmpty) widget.onExtractText(widget.images[_curPage]);
                },
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share Page'),
                onPressed: () {
                  if (widget.images.isNotEmpty) Share.shareXFiles([XFile(widget.images[_curPage])]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. PDF STUDIO (Merge PDFs)
// ============================================================================
class PdfStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  final Function(List, String) onExportPdf;

  const PdfStudioScreen({super.key, required this.savedDocs, required this.onExportPdf});

  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final Set<String> _selectedMergeDocIds = {};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge Documents into PDF')),
      body: widget.savedDocs.isEmpty
          ? const Center(child: Text('No documents scanned yet.'))
          : Column(
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
            ),
    );
  }
}

// ============================================================================
// 6. DIGITAL SIGNATURE SCREEN
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
      await Share.shareXFiles([XFile(file.path)], text: 'My Signature - Bharat Doc Scanner');
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
// 7. PASSPORT PHOTO STUDIO
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
                pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
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
// 10. RESUME BUILDER (Fixed const double.infinity issue)
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
              pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              pw.Text('${_phone.text} | ${_email.text}'),
              pw.Divider(thickness: 1.5, color: PdfColors.teal),
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
            // Corrected minimumSize (Removed illegal const with double.infinity)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appPrimaryColor.value,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _export,
              child: const Text('Generate Resume PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 11. INVOICE MAKER (Fixed const double.infinity issue)
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
              pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              pw.Text('Invoice No: ${_invoiceNum.text} | Client: ${_client.text}'),
              pw.Divider(thickness: 1.5, color: PdfColors.teal),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Service Description', 'Amount (INR)'],
                data: items.map((e) => [e['name'], 'INR ${e['price']}']).toList(),
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
                    pw.Divider(),
                    pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.teal)),
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
            // Corrected minimumSize (Removed illegal const with double.infinity)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appPrimaryColor.value,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: items.isEmpty ? null : _export,
              child: const Text('Export Invoice PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 12. LETTER TEMPLATES
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
