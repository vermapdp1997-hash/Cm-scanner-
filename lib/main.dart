import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const BharatScannerApp());
}

class BharatScannerApp extends StatelessWidget {
  const BharatScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFBFBFB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          primary: const Color(0xFF00897B),
          secondary: const Color(0xFF004D40),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------- 1. स्प्लैश स्क्रीन ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    Timer(const Duration(milliseconds: 2000), () {
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
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00897B).withOpacity(0.1),
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 75, color: Color(0xFF00897B)),
              ),
              const SizedBox(height: 20),
              const Text(
                'BHARAT SCANNER',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF00695C), letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              Text('Smart AI Document Studio', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 2. मुख्य डैशबोर्ड ----------------
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
  final TextEditingController _searchController = TextEditingController();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;

  final String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _loadSavedDocs();
    _loadBannerAd();
    _loadInterstitialAd();
    _searchController.addListener(_onSearch);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _testBannerId,
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
      adUnitId: _testInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents');
    if (rawData != null) {
      final List decoded = jsonDecode(rawData);
      setState(() {
        _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _filteredDocs = _savedDocs;
      });
    }
  }

  Future<void> _saveDocToStorage(String title, List<String> paths) async {
    final newDoc = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'images': paths,
      'pages': paths.length,
    };
    _savedDocs.insert(0, newDoc);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    setState(() => _filteredDocs = _savedDocs);
  }

  Future<void> _deleteDoc(String id) async {
    _savedDocs.removeWhere((item) => item['id'] == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents', jsonEncode(_savedDocs));
    setState(() => _filteredDocs = _savedDocs);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocs = _savedDocs.where((doc) {
        return doc['title'].toString().toLowerCase().contains(q);
      }).toList();
    });
  }

  // --- डॉक्यूमेंट स्कैनिंग शुरू करना ---
  Future<void> _startDocScan({bool isIdCard = false, bool isBook = false}) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: isIdCard ? 2 : (isBook ? 40 : 50),
      ),
    );

    try {
      final result = await scanner.scanDocument();
      if (result?.images != null && result!.images.isNotEmpty) {
        String prefix = isIdCard ? "ID_Card_" : (isBook ? "Book_" : "Doc_");
        _showNameDialog(result.images, prefix);
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  void _showNameDialog(List<String> images, String prefix) {
    final nameCtrl = TextEditingController(text: "$prefix${DateFormat('ddMMyy_HHmm').format(DateTime.now())}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.edit, color: Color(0xFF00897B)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveDocToStorage(nameCtrl.text.trim(), images);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- AI OCR (टेक्स्ट एक्सट्रैक्शन) ---
  Future<void> _extractTextWithAI(String imagePath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF00897B))),
    );

    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recognized Text (OCR)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.copy, color: Color(0xFF00897B)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: recognizedText.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                  },
                ),
              ],
            ),
            const Divider(),
            Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: SingleChildScrollView(
                child: Text(
                  recognizedText.text.isEmpty ? "No readable text found." : recognizedText.text,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share Text'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
                onPressed: () => Share.share(recognizedText.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PDF बनाना और शेयर करना ---
  Future<void> _exportPdf(List images, String title) async {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _loadInterstitialAd();
    }

    final pdf = pw.Document();
    for (var path in images) {
      final img = pw.MemoryImage(File(path).readAsBytesSync());
      pdf.addPage(
        pw.Page(
          build: (pw.Context ctx) => pw.Center(child: pw.Image(img)),
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$title.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: '$title - Scanned by Bharat Scanner');
  }

  void _showFeatureNotice(String featureTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureTitle - Opening scan mode...'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
    _startDocScan();
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.person, color: Colors.grey, size: 24),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                ),
              )
            : Text(
                _currentTabIndex == 0 ? 'BHARAT' : 'Shortcuts',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF00796B), letterSpacing: 1.5, fontSize: 22),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black87, size: 26),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentTabIndex == 0
                ? _buildDocsTab()
                : _buildToolsTab(),
          ),
          if (_isBannerLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),

      // Floating Center Camera Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 64,
        width: 64,
        margin: const EdgeInsets.only(top: 15),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00897B).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 0,
          onPressed: () => _startDocScan(),
          child: const Icon(Icons.camera_alt_rounded, size: 30),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Docs Tab
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_rounded,
                      color: _currentTabIndex == 0 ? const Color(0xFF00897B) : Colors.grey.shade500,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Docs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentTabIndex == 0 ? const Color(0xFF00897B) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 48), // Center Camera Gap

              // Tools Tab
              InkWell(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: _currentTabIndex == 1 ? const Color(0xFF00897B) : Colors.grey.shade500,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tools',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _currentTabIndex == 1 ? const Color(0xFF00897B) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- SCREEN 1: DOCS TAB (NO PREMIUM BANNER) ----------------
  Widget _buildDocsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // 1. All Docs Filter & Sorting Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'All docs(${_filteredDocs.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                ),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF00897B)),
              ],
            ),
            Row(
              children: [
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 22, color: Colors.black87),
                  onPressed: () => _startDocScan(),
                ),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  icon: const Icon(Icons.swap_vert_rounded, size: 22, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      _filteredDocs = _filteredDocs.reversed.toList();
                    });
                  },
                ),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  icon: const Icon(Icons.menu_rounded, size: 22, color: Colors.black87),
                  onPressed: () {},
                ),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  icon: const Icon(Icons.checklist_rtl_rounded, size: 22, color: Colors.black87),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Pink Sign-In Reminder Banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sign in to sync and keep files safe.',
                  style: TextStyle(color: Color(0xFFD32F2F), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sign in feature coming soon!')),
                  );
                },
                child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // 3. Document List or Empty View
        if (_filteredDocs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Clean Document Outline
                Container(
                  width: 90,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E6E3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF80CBC4), width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
                  ),
                  child: const Center(
                    child: Icon(Icons.description_outlined, size: 45, color: Color(0xFF00796B)),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  "You don't have any documents yet",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00897B),
                    side: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => _startDocScan(),
                  child: const Text(
                    'Scan new docs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) {
              final doc = _filteredDocs[i];
              final List imgList = doc['images'];
              return Card(
                elevation: 0.8,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imgList.first),
                          width: 60,
                          height: 75,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['title'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${doc['pages']} pages • ${doc['date']}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => _extractTextWithAI(imgList.first),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2F1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF80CBC4)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.text_fields_rounded, size: 14, color: Color(0xFF00796B)),
                                        SizedBox(width: 4),
                                        Text('AI OCR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.share_outlined, color: Color(0xFF00796B), size: 20),
                                  onPressed: () => _exportPdf(imgList, doc['title']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteDoc(doc['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ---------------- SCREEN 2 & 3: TOOLS / SHORTCUTS TAB ----------------
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Scan Section
        _buildSectionHeader('Scan'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(
              title: 'ID Card',
              icon: Icons.badge_outlined,
              iconColor: const Color(0xFF1976D2),
              onTap: () => _startDocScan(isIdCard: true),
            ),
            _buildToolCard(
              title: 'Scan Docs',
              icon: Icons.document_scanner,
              iconColor: const Color(0xFF00897B),
              onTap: () => _startDocScan(),
            ),
            _buildToolCard(
              title: 'Book',
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF388E3C),
              onTap: () => _startDocScan(isBook: true),
            ),
            _buildToolCard(
              title: 'QR Code',
              icon: Icons.qr_code_scanner_rounded,
              iconColor: const Color(0xFF00897B),
              onTap: () => _showFeatureNotice('QR Code Scanner'),
            ),
            _buildToolCard(
              title: 'To Text',
              icon: Icons.text_snippet_outlined,
              iconColor: const Color(0xFF00897B),
              onTap: () {
                if (_savedDocs.isNotEmpty) {
                  _extractTextWithAI(_savedDocs.first['images'][0]);
                } else {
                  _startDocScan();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. Process Files Section
        _buildSectionHeader('Process Files'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(
              title: 'Import Files',
              icon: Icons.folder_open_rounded,
              iconColor: const Color(0xFF0288D1),
              onTap: () => _startDocScan(),
            ),
            _buildToolCard(
              title: 'Collage Images',
              icon: Icons.dashboard_customize_outlined,
              iconColor: const Color(0xFF43A047),
              onTap: () => _showFeatureNotice('Collage Images'),
            ),
            _buildToolCard(
              title: 'PDF Watermark',
              icon: Icons.branding_watermark_outlined,
              iconColor: const Color(0xFF00897B),
              onTap: () => _showFeatureNotice('PDF Watermark'),
            ),
            _buildToolCard(
              title: 'PDF Merge',
              icon: Icons.call_merge_rounded,
              iconColor: const Color(0xFF5E35B1),
              onTap: () => _showFeatureNotice('PDF Merge'),
            ),
            _buildToolCard(
              title: 'Compression',
              icon: Icons.compress_rounded,
              iconColor: const Color(0xFF00897B),
              onTap: () => _showFeatureNotice('PDF Compression'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3. PDF Tools Section
        _buildSectionHeader('PDF Tools'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildToolCard(
              title: 'PDF Signature',
              icon: Icons.draw_rounded,
              iconColor: const Color(0xFF00897B),
              onTap: () => _showFeatureNotice('PDF Signature'),
            ),
            _buildToolCard(
              title: 'PDF Password',
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF00897B),
              onTap: () => _showFeatureNotice('PDF Password'),
            ),
            _buildToolCard(
              title: 'Page Reorder',
              icon: Icons.swap_horiz_rounded,
              iconColor: const Color(0xFF00897B),
              onTap: () => _showFeatureNotice('Page Reorder'),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 78,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withOpacity(0.08),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
