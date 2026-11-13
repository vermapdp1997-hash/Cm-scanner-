import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
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
final ValueNotifier<Color> appPrimaryColor = ValueNotifier(const Color(0xFFE91E63));
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
      'save_pdf': ['Save PDF', 'PDF सेव करें'],
      'save_jpg': ['Save JPG', 'JPG सेव करें'],
      'share_pdf': ['Share PDF', 'PDF शेयर करें'],
      'share_jpg': ['Share JPG', 'JPG शेयर करें'],
      'delete': ['Delete', 'हटाएं'],
      'no_docs': ['No documents saved yet', 'अभी तक कोई दस्तावेज़ नहीं है'],
      'scan_now': ['Scan Document Now', 'डॉक्यूमेंट स्कैन करें'],
      'select_all': ['Select All', 'सभी चुनें'],
      'choose_folder': ['Save to Folder:', 'फ़ोल्डर चुनें:'],
      'add_more': ['+ Add Pages', '+ और पेज जोड़ें'],
      'add_new_doc': ['Add New Document', 'नया दस्तावेज़ जोड़ें'],
      'choose_options': ['Choose from below options', 'नीचे दिए गए विकल्प चुनें'],
      'from_gallery': ['Import from Gallery', 'गैलरी से चुनें'],
      'from_camera': ['Scan from Camera', 'कैमरे से स्कैन करें'],
      'compress': ['Compress', 'कंप्रेस'],
      'edit_doc': ['Edit Page', 'एडिट करें'],
    };
    return dict[key] != null ? (hi ? dict[key]![1] : dict[key]![0]) : key;
  }
}

// ============================================================================
// REUSABLE LABELED BUTTON WIDGET (NAME BELOW EVERY ICON BUTTON)
// ============================================================================
class LabeledIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const LabeledIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.iconSize = 21,
    this.fontSize = 9.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? Colors.grey
        : (color ?? IconTheme.of(context).color ?? Colors.black87);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: effectiveColor),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRO-LEVEL COMPUTER VISION DOCUMENT & BOOK FILTER PRESETS
// ============================================================================
class DocFilterPreset {
  final String id;
  final String title;
  final IconData icon;
  final Color badgeColor;
  const DocFilterPreset({
    required this.id,
    required this.title,
    required this.icon,
    required this.badgeColor,
  });
}

final List<DocFilterPreset> kDocFilters = [
  const DocFilterPreset(id: 'original', title: 'Original', icon: Icons.image_outlined, badgeColor: Colors.blueGrey),
  const DocFilterPreset(id: 'magic_pro', title: 'Magic Pro', icon: Icons.auto_awesome_rounded, badgeColor: Color(0xFF00B4D8)),
  const DocFilterPreset(id: 'book_ultra', title: 'Book Ultra', icon: Icons.menu_book_rounded, badgeColor: Color(0xFF4CAF50)),
  const DocFilterPreset(id: 'super_bw', title: 'Super B&W', icon: Icons.contrast_rounded, badgeColor: Colors.black87),
  const DocFilterPreset(id: 'deshadow', title: 'De-Shadow', icon: Icons.wb_sunny_outlined, badgeColor: Colors.orange),
  const DocFilterPreset(id: 'ocv_crisp', title: 'Grayscale Pro', icon: Icons.filter_b_and_w_rounded, badgeColor: Colors.grey),
  const DocFilterPreset(id: 'vivid_color', title: 'Vivid Color', icon: Icons.color_lens_outlined, badgeColor: Colors.pink),
  const DocFilterPreset(id: 'eco_ink', title: 'Eco Clean', icon: Icons.eco_outlined, badgeColor: Colors.teal),
];

// ============================================================================
// PRO PIXEL-BY-PIXEL IMAGE ENHANCEMENT ENGINE (RUNS IN ISOLATE FOR 60FPS UI)
// ============================================================================
class ProDocImageProcessor {
  static Future<Uint8List?> decodeImageToRgba(
    String path, {
    int? maxDimension,
    required List<int> outWidthHeight,
  }) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final rawBytes = await file.readAsBytes();

    final firstCodec = await ui.instantiateImageCodec(rawBytes);
    final firstFrame = await firstCodec.getNextFrame();
    final origW = firstFrame.image.width;
    final origH = firstFrame.image.height;

    ui.Image targetImg = firstFrame.image;
    if (maxDimension != null && (origW > maxDimension || origH > maxDimension)) {
      firstFrame.image.dispose();
      final resizedCodec = origW >= origH
          ? await ui.instantiateImageCodec(rawBytes, targetWidth: maxDimension)
          : await ui.instantiateImageCodec(rawBytes, targetHeight: maxDimension);
      final resizedFrame = await resizedCodec.getNextFrame();
      targetImg = resizedFrame.image;
    }

    outWidthHeight[0] = targetImg.width;
    outWidthHeight[1] = targetImg.height;
    final byteData = await targetImg.toByteData(format: ui.ImageByteFormat.rawRgba);
    targetImg.dispose();
    return byteData?.buffer.asUint8List();
  }

  static Future<Uint8List> applyProFilterToRgba({
    required Uint8List rgba,
    required int width,
    required int height,
    required String filterId,
    required double intensity,
  }) async {
    if (filterId == 'original') return rgba;
    return compute(_processRgbaIsolate, {
      'rgba': Uint8List.fromList(rgba),
      'w': width,
      'h': height,
      'filter': filterId,
      'intensity': intensity,
    });
  }

  static Future<Uint8List?> encodeRgbaToPngBytes(Uint8List rgba, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, (uiImg) {
      completer.complete(uiImg);
    });
    final uiImg = await completer.future;
    final data = await uiImg.toByteData(format: ui.ImageByteFormat.png);
    uiImg.dispose();
    return data?.buffer.asUint8List();
  }

  static Future<String> processAndSaveHighRes({
    required String sourcePath,
    required String filterId,
    required double intensity,
    required String outputPath,
  }) async {
    if (filterId == 'original') {
      await File(sourcePath).copy(outputPath);
      return outputPath;
    }
    final wh = [0, 0];
    final rgba = await decodeImageToRgba(sourcePath, maxDimension: 2200, outWidthHeight: wh);
    if (rgba == null) return sourcePath;

    final enhanced = await applyProFilterToRgba(
      rgba: rgba,
      width: wh[0],
      height: wh[1],
      filterId: filterId,
      intensity: intensity,
    );

    final jpgBytes = await compute(_encodeRgbaToJpgIsolate, {
      'rgba': enhanced,
      'w': wh[0],
      'h': wh[1],
      'quality': 93,
    });
    await File(outputPath).writeAsBytes(jpgBytes);
    return outputPath;
  }
}

Uint8List _encodeRgbaToJpgIsolate(Map<String, dynamic> params) {
  final Uint8List rgba = params['rgba'];
  final int w = params['w'];
  final int h = params['h'];
  final int quality = params['quality'];
  final im = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: Uint8List.fromList(rgba).buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}

Uint8List _processRgbaIsolate(Map<String, dynamic> params) {
  final Uint8List src = params['rgba'];
  final int w = params['w'];
  final int h = params['h'];
  final String filter = params['filter'];
  final double intensity = (params['intensity'] as double).clamp(0.0, 1.0);
  final int total = w * h;
  final Uint8List out = Uint8List.fromList(src);

  if (filter == 'original' || total == 0) return out;

  // ------------------------------------------------------------------------
  // 1. LOCAL PAPER BACKGROUND ESTIMATION (2D BLOCK 90TH-PERCENTILE + SMOOTH)
  // ------------------------------------------------------------------------
  final int gridCols = (filter == 'book_ultra') ? 32 : 24;
  final int gridRows = (filter == 'book_ultra') ? 32 : 24;
  final int gridCount = gridCols * gridRows;
  final Float32List bgR = Float32List(gridCount);
  final Float32List bgG = Float32List(gridCount);
  final Float32List bgB = Float32List(gridCount);

  final Int32List histCount = Int32List(256);
  final Int32List histR = Int32List(256);
  final Int32List histG = Int32List(256);
  final Int32List histB = Int32List(256);

  final int step = (w > 1200 || h > 1200) ? 2 : 1;

  for (int gy = 0; gy < gridRows; gy++) {
    final int y0 = (gy * h) ~/ gridRows;
    final int y1 = ((gy + 1) * h) ~/ gridRows;
    for (int gx = 0; gx < gridCols; gx++) {
      final int x0 = (gx * w) ~/ gridCols;
      final int x1 = ((gx + 1) * w) ~/ gridCols;

      histCount.fillRange(0, 256, 0);
      histR.fillRange(0, 256, 0);
      histG.fillRange(0, 256, 0);
      histB.fillRange(0, 256, 0);

      int samples = 0;
      for (int y = y0; y < y1; y += step) {
        int rowBase = y * w;
        for (int x = x0; x < x1; x += step) {
          final int p = (rowBase + x) * 4;
          final int r = src[p];
          final int g = src[p + 1];
          final int b = src[p + 2];
          final int lum = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
          histCount[lum]++;
          histR[lum] += r;
          histG[lum] += g;
          histB[lum] += b;
          samples++;
        }
      }

      final int gIdx = gy * gridCols + gx;
      if (samples == 0) {
        bgR[gIdx] = 255;
        bgG[gIdx] = 255;
        bgB[gIdx] = 255;
        continue;
      }

      final int targetSamples = max(1, (samples * 0.14).round());
      int acc = 0;
      double sumR = 0, sumG = 0, sumB = 0;
      for (int bin = 255; bin >= 0; bin--) {
        final int c = histCount[bin];
        if (c > 0) {
          sumR += histR[bin];
          sumG += histG[bin];
          sumB += histB[bin];
          acc += c;
          if (acc >= targetSamples) break;
        }
      }
      bgR[gIdx] = (sumR / acc).clamp(32.0, 255.0);
      bgG[gIdx] = (sumG / acc).clamp(32.0, 255.0);
      bgB[gIdx] = (sumB / acc).clamp(32.0, 255.0);
    }
  }

  // Smooth background grid (2 passes of 3x3 box blur) to remove block edges
  final Float32List tmpR = Float32List(gridCount);
  final Float32List tmpG = Float32List(gridCount);
  final Float32List tmpB = Float32List(gridCount);
  for (int pass = 0; pass < 2; pass++) {
    for (int gy = 0; gy < gridRows; gy++) {
      for (int gx = 0; gx < gridCols; gx++) {
        double sr = 0, sg = 0, sb = 0;
        int cnt = 0;
        for (int dy = -1; dy <= 1; dy++) {
          final int ny = (gy + dy).clamp(0, gridRows - 1);
          for (int dx = -1; dx <= 1; dx++) {
            final int nx = (gx + dx).clamp(0, gridCols - 1);
            final int idx = ny * gridCols + nx;
            sr += bgR[idx];
            sg += bgG[idx];
            sb += bgB[idx];
            cnt++;
          }
        }
        final int outIdx = gy * gridCols + gx;
        tmpR[outIdx] = sr / cnt;
        tmpG[outIdx] = sg / cnt;
        tmpB[outIdx] = sb / cnt;
      }
    }
    bgR.setAll(0, tmpR);
    bgG.setAll(0, tmpG);
    bgB.setAll(0, tmpB);
  }

  double sampleGrid(Float32List grid, double gx, double gy) {
    final int x0 = gx.floor().clamp(0, gridCols - 1);
    final int y0 = gy.floor().clamp(0, gridRows - 1);
    final int x1 = (x0 + 1).clamp(0, gridCols - 1);
    final int y1 = (y0 + 1).clamp(0, gridRows - 1);
    final double fx = gx - x0;
    final double fy = gy - y0;
    final double v00 = grid[y0 * gridCols + x0];
    final double v10 = grid[y0 * gridCols + x1];
    final double v01 = grid[y1 * gridCols + x0];
    final double v11 = grid[y1 * gridCols + x1];
    final double top = v00 + (v10 - v00) * fx;
    final double bot = v01 + (v11 - v01) * fx;
    return top + (bot - top) * fy;
  }

  final double cellW = w / gridCols;
  final double cellH = h / gridRows;

  // ------------------------------------------------------------------------
  // 2. FILTER-SPECIFIC PRO ENHANCEMENT
  // ------------------------------------------------------------------------
  if (filter == 'super_bw') {
    // INTEGRAL IMAGE ADAPTIVE SAUVOLA/BRADLEY THRESHOLDING
    final Uint8List normLum = Uint8List(total);
    final int iw = w + 1;
    final Int64List integral = Int64List(iw * (h + 1));

    for (int y = 0; y < h; y++) {
      final double gy = ((y + 0.5) / cellH - 0.5).clamp(0.0, gridRows - 1.0001);
      int rowSum = 0;
      final int rowBase = y * w;
      final int iRowBase = (y + 1) * iw;
      final int iPrevRowBase = y * iw;

      for (int x = 0; x < w; x++) {
        final double gx = ((x + 0.5) / cellW - 0.5).clamp(0.0, gridCols - 1.0001);
        final int p = (rowBase + x) * 4;
        final double lbgR = sampleGrid(bgR, gx, gy);
        final double lbgG = sampleGrid(bgG, gx, gy);
        final double lbgB = sampleGrid(bgB, gx, gy);
        final double lbgLum = 0.299 * lbgR + 0.587 * lbgG + 0.114 * lbgB;
        final double gain = min(255.0 / max(lbgLum, 36.0), 3.2);
        final double rawLum = 0.299 * src[p] + 0.587 * src[p + 1] + 0.114 * src[p + 2];
        final int nLum = (rawLum * gain).round().clamp(0, 255);
        normLum[rowBase + x] = nLum;
        rowSum += nLum;
        integral[iRowBase + x + 1] = integral[iPrevRowBase + x + 1] + rowSum;
      }
    }

    final int rad = max(12, min(w, h) ~/ 32);
    final double kSens = 0.08 + 0.12 * (1.0 - intensity);
    const double band = 14.0;

    for (int y = 0; y < h; y++) {
      final int y1 = max(0, y - rad);
      final int y2 = min(h - 1, y + rad);
      final int rowOff = y * w;
      for (int x = 0; x < w; x++) {
        final int x1 = max(0, x - rad);
        final int x2 = min(w - 1, x + rad);
        final int count = (x2 - x1 + 1) * (y2 - y1 + 1);
        final int sum = integral[(y2 + 1) * iw + (x2 + 1)] -
            integral[y1 * iw + (x2 + 1)] -
            integral[(y2 + 1) * iw + x1] +
            integral[y1 * iw + x1];
        final double localMean = sum / count;
        final int cur = normLum[rowOff + x];

        int bw;
        if (cur > 236) {
          bw = 255;
        } else if (localMean < 28) {
          bw = 12;
        } else {
          final double thresh = localMean * (1.0 - kSens);
          final double t = ((cur - (thresh - band)) / (2.0 * band)).clamp(0.0, 1.0);
          final double smooth = t * t * (3.0 - 2.0 * t);
          bw = (10 + smooth * 245).round().clamp(0, 255);
        }

        final int p = (rowOff + x) * 4;
        out[p] = bw;
        out[p + 1] = bw;
        out[p + 2] = bw;
        out[p + 3] = 255;
      }
    }
    return out;
  }

  // VIVD COLOR HISTOGRAM AUTO-LEVELS CALCULATION
  int lowClip = 8, highClip = 248;
  if (filter == 'vivid_color') {
    final Int32List lumHist = Int32List(256);
    int sampleCount = 0;
    for (int i = 0; i < total; i += 4) {
      final int p = i * 4;
      final int l = ((77 * src[p] + 150 * src[p + 1] + 29 * src[p + 2]) >> 8).clamp(0, 255);
      lumHist[l]++;
      sampleCount++;
    }
    int acc = 0;
    for (int b = 0; b < 256; b++) {
      acc += lumHist[b];
      if (acc >= sampleCount * 0.015) {
        lowClip = b;
        break;
      }
    }
    acc = 0;
    for (int b = 255; b >= 0; b--) {
      acc += lumHist[b];
      if (acc >= sampleCount * 0.015) {
        highClip = b;
        break;
      }
    }
    if (highClip - lowClip < 40) {
      lowClip = 5;
      highClip = 250;
    }
  }

  // PIXEL-BY-PIXEL COLOR + ILLUMINATION NORMALIZATION
  final Uint8List lumCache = Uint8List(total);

  for (int y = 0; y < h; y++) {
    final double gy = ((y + 0.5) / cellH - 0.5).clamp(0.0, gridRows - 1.0001);
    final int rowOff = y * w;
    for (int x = 0; x < w; x++) {
      final double gx = ((x + 0.5) / cellW - 0.5).clamp(0.0, gridCols - 1.0001);
      final int p = (rowOff + x) * 4;
      final double r = src[p].toDouble();
      final double g = src[p + 1].toDouble();
      final double b = src[p + 2].toDouble();

      double nr = r, ng = g, nb = b;

      if (filter == 'vivid_color') {
        final double scale = 255.0 / (highClip - lowClip);
        nr = ((r - lowClip) * scale).clamp(0.0, 255.0);
        ng = ((g - lowClip) * scale).clamp(0.0, 255.0);
        nb = ((b - lowClip) * scale).clamp(0.0, 255.0);
        final double lum = 0.299 * nr + 0.587 * ng + 0.114 * nb;
        final double sat = 1.25 + 0.45 * intensity;
        nr = (lum + (nr - lum) * sat).clamp(0.0, 255.0);
        ng = (lum + (ng - lum) * sat).clamp(0.0, 255.0);
        nb = (lum + (nb - lum) * sat).clamp(0.0, 255.0);
      } else {
        final double lbgR = sampleGrid(bgR, gx, gy);
        final double lbgG = sampleGrid(bgG, gx, gy);
        final double lbgB = sampleGrid(bgB, gx, gy);

        // Cap max amplification so black borders/regions don't blow out into noise
        const double maxGain = 3.8;
        final double gR = min(255.0 / max(lbgR, 30.0), maxGain);
        final double gG = min(255.0 / max(lbgG, 30.0), maxGain);
        final double gB = min(255.0 / max(lbgB, 30.0), maxGain);

        final double normR = (r * gR).clamp(0.0, 255.0);
        final double normG = (g * gG).clamp(0.0, 255.0);
        final double normB = (b * gB).clamp(0.0, 255.0);

        if (filter == 'deshadow') {
          final double blend = 0.55 + 0.40 * intensity;
          nr = r + (normR - r) * blend;
          ng = g + (normG - g) * blend;
          nb = b + (normB - b) * blend;
        } else if (filter == 'magic_pro' || filter == 'book_ultra') {
          final double lum = 0.299 * normR + 0.587 * normG + 0.114 * normB;
          final double paperSnap = (filter == 'book_ultra')
              ? (216.0 - 38.0 * intensity)
              : (222.0 - 34.0 * intensity);

          if (lum >= paperSnap) {
            // Smooth white paper snap
            final double t = ((lum - paperSnap) / max(1.0, 255.0 - paperSnap)).clamp(0.0, 1.0);
            final double whiten = 0.72 + 0.28 * t;
            nr = normR + (255.0 - normR) * whiten;
            ng = normG + (255.0 - normG) * whiten;
            nb = normB + (255.0 - normB) * whiten;
          } else {
            // Deep crisp ink + vivid pen/stamp colors
            final double inkGamma = (filter == 'book_ultra') ? (1.28 + 0.45 * intensity) : (1.18 + 0.35 * intensity);
            final double nLum = (pow(lum / 255.0, inkGamma) * 255.0).clamp(0.0, 255.0);
            final double ratio = lum > 1.0 ? (nLum / lum) : 1.0;
            final double satBoost = (filter == 'magic_pro') ? 1.18 : 1.08;
            nr = (nLum + (normR * ratio - nLum) * satBoost).clamp(0.0, 255.0);
            ng = (nLum + (normG * ratio - nLum) * satBoost).clamp(0.0, 255.0);
            nb = (nLum + (normB * ratio - nLum) * satBoost).clamp(0.0, 255.0);
          }
        } else if (filter == 'ocv_crisp') {
          double lum = 0.299 * normR + 0.587 * normG + 0.114 * normB;
          final double paperSnap = 212.0 - 36.0 * intensity;
          if (lum > paperSnap) {
            lum = 255.0;
          } else {
            lum = (pow(lum / paperSnap, 1.35 + 0.4 * intensity) * 235.0).clamp(0.0, 255.0);
          }
          nr = lum;
          ng = lum;
          nb = lum;
        } else if (filter == 'eco_ink') {
          double lum = 0.299 * normR + 0.587 * normG + 0.114 * normB;
          final double paperSnap = 205.0 - 30.0 * intensity;
          if (lum > paperSnap) {
            nr = 255;
            ng = 255;
            nb = 255;
          } else {
            // Charcoal soft dark ink (saves ink & eye comfort)
            final double soft = 38.0 + (lum / paperSnap) * 165.0;
            nr = soft;
            ng = soft;
            nb = soft;
          }
        }
      }

      final int ri = nr.round().clamp(0, 255);
      final int gi = ng.round().clamp(0, 255);
      final int bi = nb.round().clamp(0, 255);
      out[p] = ri;
      out[p + 1] = gi;
      out[p + 2] = bi;
      out[p + 3] = 255;
      lumCache[rowOff + x] = ((77 * ri + 150 * gi + 29 * bi) >> 8).clamp(0, 255);
    }
  }

  // ------------------------------------------------------------------------
  // 3. LUMINANCE UNSHARP MASK (TEXT EDGE SHARPENING)
  // ------------------------------------------------------------------------
  final double sharpAmt = (filter == 'book_ultra')
      ? (0.55 + 0.55 * intensity)
      : (filter == 'magic_pro' || filter == 'ocv_crisp')
          ? (0.40 + 0.45 * intensity)
          : (filter == 'vivid_color' ? 0.32 : 0.20);

  if (sharpAmt > 0.05 && w > 3 && h > 3) {
    for (int y = 1; y < h - 1; y++) {
      final int r0 = (y - 1) * w;
      final int r1 = y * w;
      final int r2 = (y + 1) * w;
      for (int x = 1; x < w - 1; x++) {
        final int blur = (lumCache[r0 + x - 1] +
                lumCache[r0 + x] +
                lumCache[r0 + x + 1] +
                lumCache[r1 + x - 1] +
                lumCache[r1 + x] +
                lumCache[r1 + x + 1] +
                lumCache[r2 + x - 1] +
                lumCache[r2 + x] +
                lumCache[r2 + x + 1]) ~/
            9;
        final int delta = ((lumCache[r1 + x] - blur) * sharpAmt).round();
        if (delta != 0) {
          final int p = (r1 + x) * 4;
          out[p] = (out[p] + delta).clamp(0, 255);
          out[p + 1] = (out[p + 1] + delta).clamp(0, 255);
          out[p + 2] = (out[p + 2] + delta).clamp(0, 255);
        }
      }
    }
  }

  return out;
}

// ============================================================================
// AI DESKEW ENGINE
// ============================================================================
class AIDeskewEngine {
  static Future<double> detectSkewAngle(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      List<double> angles = [];
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          if (line.cornerPoints.length >= 2) {
            final p1 = line.cornerPoints[0];
            final p2 = line.cornerPoints[1];
            double angleDeg = atan2((p2.y - p1.y).toDouble(), (p2.x - p1.x).toDouble()) * 180 / pi;
            while (angleDeg > 45) angleDeg -= 90;
            while (angleDeg < -45) angleDeg += 90;
            angles.add(angleDeg);
          }
        }
      }
      if (angles.isNotEmpty) {
        angles.sort();
        return angles[angles.length ~/ 2];
      }
    } catch (e) {
      debugPrint("Deskew angle err: $e");
    }
    return 0.0;
  }

  static Future<String> rotateAndDeskewImage(String sourcePath, double angleDegrees) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imgUi = frame.image;

      final angleRad = angleDegrees * pi / 180.0;
      final absCos = cos(angleRad).abs();
      final absSin = sin(angleRad).abs();
      final newW = (imgUi.width * absCos + imgUi.height * absSin).round();
      final newH = (imgUi.width * absSin + imgUi.height * absCos).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()));
      canvas.drawRect(Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()), Paint()..color = Colors.white);
      canvas.translate(newW / 2, newH / 2);
      canvas.rotate(angleRad);
      canvas.drawImage(imgUi, Offset(-imgUi.width / 2, -imgUi.height / 2), Paint());

      final picture = recorder.endRecording();
      final outputImg = await picture.toImage(newW, newH);
      final byteData = await outputImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
        final outF = File('${scansDir.path}/deskew_${DateTime.now().millisecondsSinceEpoch}.png');
        await outF.writeAsBytes(byteData.buffer.asUint8List());
        return outF.path;
      }
    } catch (e) {
      debugPrint("Rotate Deskew err: $e");
    }
    return sourcePath;
  }
}

// ============================================================================
// PHONE STORAGE MANAGER (SAVES JPG TO PICTURES & PDF TO DOWNLOADS)
// ============================================================================
class PhoneStorageManager {
  static Future<Directory> _resolvePublicDir(String primaryPath, String secondaryPath) async {
    for (final path in [primaryPath, secondaryPath]) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) return dir;
        await dir.create(recursive: true);
        if (await dir.exists()) return dir;
      } catch (_) {}
    }
    final ext = await getExternalStorageDirectory();
    final fallback = Directory('${ext?.path ?? (await getApplicationDocumentsDirectory()).path}/BharatScanner');
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return fallback;
  }

  static Future<int> saveImagesToPublicGallery(List<String> imagePaths, String docTitle) async {
    int savedCount = 0;
    try {
      final targetDir = await _resolvePublicDir(
        '/storage/emulated/0/Pictures/BharatScanner',
        '/storage/emulated/0/DCIM/BharatScanner',
      );
      final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      for (int i = 0; i < imagePaths.length; i++) {
        final f = File(imagePaths[i]);
        if (await f.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final dest = File('${targetDir.path}/${safeName}_p${i + 1}_$timestamp.jpg');
          await f.copy(dest.path);
          savedCount++;
        }
      }
    } catch (e) {
      debugPrint("Gallery export error: $e");
    }
    return savedCount;
  }

  static Future<int> saveJpgBytesListToPublicGallery(List<Uint8List> jpgList, String docTitle) async {
    int savedCount = 0;
    try {
      final targetDir = await _resolvePublicDir(
        '/storage/emulated/0/Pictures/BharatScanner',
        '/storage/emulated/0/DCIM/BharatScanner',
      );
      final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      for (int i = 0; i < jpgList.length; i++) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final dest = File('${targetDir.path}/${safeName}_comp_p${i + 1}_$timestamp.jpg');
        await dest.writeAsBytes(jpgList[i]);
        savedCount++;
      }
    } catch (e) {
      debugPrint("Compressed JPG save error: $e");
    }
    return savedCount;
  }

  static Future<String?> savePdfBytesToPublicDownloads(Uint8List pdfBytes, String docTitle) async {
    try {
      final targetDir = await _resolvePublicDir(
        '/storage/emulated/0/Download/BharatScanner',
        '/storage/emulated/0/Documents/BharatScanner',
      );
      final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dest = File('${targetDir.path}/${safeName}_$timestamp.pdf');
      await dest.writeAsBytes(pdfBytes);
      return dest.path;
    } catch (e) {
      debugPrint("PDF save error: $e");
      return null;
    }
  }
}

// ============================================================================
// PRO TARGET COMPRESSION ENGINE (10KB - 5MB ACCURATE PDF & JPG COMPRESSOR)
// ============================================================================
class CompressedBundleResult {
  final File pdfFile;
  final List<File> jpgFiles;
  final double pdfSizeKb;
  final double jpgTotalSizeKb;

  CompressedBundleResult({
    required this.pdfFile,
    required this.jpgFiles,
    required this.pdfSizeKb,
    required this.jpgTotalSizeKb,
  });
}

Uint8List _compressSingleImageIsolate(Map<String, dynamic> params) {
  final Uint8List rawBytes = params['bytes'];
  final int targetBytes = params['targetBytes'];

  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;

  int maxDim = 1800;
  if (targetBytes < 30 * 1024) {
    maxDim = 620;
  } else if (targetBytes < 80 * 1024) {
    maxDim = 980;
  } else if (targetBytes < 220 * 1024) {
    maxDim = 1380;
  }

  img.Image working = decoded;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    working = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDim)
        : img.copyResize(decoded, height: maxDim);
  }

  int lo = 12, hi = 92;
  Uint8List best = Uint8List.fromList(img.encodeJpg(working, quality: 50));

  for (int iter = 0; iter < 5; iter++) {
    final int mid = (lo + hi) ~/ 2;
    final candidate = Uint8List.fromList(img.encodeJpg(working, quality: mid));
    best = candidate;
    if (candidate.length > targetBytes) {
      hi = mid - 1;
    } else {
      lo = mid + 1;
    }
  }

  // If even at low quality it exceeds targetBytes, scale resolution down once more
  if (best.length > targetBytes && working.width > 320) {
    final scaled = img.copyResize(working, width: (working.width * 0.65).round());
    best = Uint8List.fromList(img.encodeJpg(scaled, quality: 28));
  }

  return best;
}

class ProCompressionEngine {
  static Future<CompressedBundleResult?> compressOrderedPages({
    required List<String> orderedImagePaths,
    required int targetKb,
    required String docTitle,
  }) async {
    if (orderedImagePaths.isEmpty) return null;
    final safeName = docTitle.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final tempDir = await getTemporaryDirectory();
    final int totalTargetBytes = max(10 * 1024, targetKb * 1024);
    final int perPageTargetBytes = max(8 * 1024, (totalTargetBytes * 0.90) ~/ orderedImagePaths.length);

    final pdf = pw.Document();
    final List<File> jpgFiles = [];
    int totalJpgBytes = 0;

    for (int i = 0; i < orderedImagePaths.length; i++) {
      final srcFile = File(orderedImagePaths[i]);
      if (!await srcFile.exists()) continue;
      final rawBytes = await srcFile.readAsBytes();

      final compressedJpg = await compute(_compressSingleImageIsolate, {
        'bytes': rawBytes,
        'targetBytes': perPageTargetBytes,
      });

      final jpgOut = File('${tempDir.path}/${safeName}_comp_p${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await jpgOut.writeAsBytes(compressedJpg);
      jpgFiles.add(jpgOut);
      totalJpgBytes += compressedJpg.length;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(8),
          build: (ctx) => pw.Center(
            child: pw.Image(pw.MemoryImage(compressedJpg), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final pdfBytes = await pdf.save();
    final pdfOut = File('${tempDir.path}/${safeName}_compressed_${targetKb}KB.pdf');
    await pdfOut.writeAsBytes(pdfBytes);

    return CompressedBundleResult(
      pdfFile: pdfOut,
      jpgFiles: jpgFiles,
      pdfSizeKb: pdfBytes.length / 1024.0,
      jpgTotalSizeKb: totalJpgBytes / 1024.0,
    );
  }

  static void showCompressorDialog({
    required BuildContext context,
    required List<String> orderedPaths,
    required String title,
  }) {
    double targetKb = 150;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Compress (${orderedPaths.length} Page${orderedPaths.length > 1 ? 's' : ''})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Target Size:'),
                    Text(
                      targetKb >= 1000 ? '${(targetKb / 1000).toStringAsFixed(1)} MB' : '${targetKb.toInt()} KB',
                      style: TextStyle(fontWeight: FontWeight.bold, color: appPrimaryColor.value, fontSize: 15),
                    ),
                  ],
                ),
                Slider(
                  value: targetKb,
                  min: 10,
                  max: 5000,
                  divisions: 100,
                  activeColor: appPrimaryColor.value,
                  onChanged: (v) => setDialogState(() => targetKb = v),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [20, 50, 100, 200, 500, 1000, 2000].map((preset) {
                    return ActionChip(
                      label: Text(preset >= 1000 ? '${preset ~/ 1000} MB' : '$preset KB', style: const TextStyle(fontSize: 10)),
                      onPressed: () => setDialogState(() => targetKb = preset.toDouble()),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                icon: const Icon(Icons.compress_rounded, size: 18),
                label: const Text('Compress Now'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  _runCompressionWithResultSheet(
                    context: context,
                    orderedPaths: orderedPaths,
                    targetKb: targetKb.toInt(),
                    title: title,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _runCompressionWithResultSheet({
    required BuildContext context,
    required List<String> orderedPaths,
    required int targetKb,
    required String title,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Compressing PDF & JPG...')),
          ],
        ),
      ),
    );

    final bundle = await compressOrderedPages(
      orderedImagePaths: orderedPaths,
      targetKb: targetKb,
      docTitle: title,
    );

    if (context.mounted) Navigator.pop(context);
    if (bundle == null || !context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 42),
              const SizedBox(height: 6),
              const Text('Compression Complete!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'PDF Size: ${bundle.pdfSizeKb.toStringAsFixed(1)} KB  •  JPG Total: ${bundle.jpgTotalSizeKb.toStringAsFixed(1)} KB (${bundle.jpgFiles.length} Pages)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  LabeledIconButton(
                    icon: Icons.download_for_offline_rounded,
                    label: 'Save PDF',
                    color: Colors.redAccent,
                    iconSize: 28,
                    fontSize: 11,
                    onPressed: () async {
                      final pdfBytes = await bundle.pdfFile.readAsBytes();
                      final savedPath = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, '${title}_compressed');
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(savedPath != null ? '✅ Compressed PDF saved to Download/BharatScanner!' : '❌ Failed to save PDF'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      }
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.save_alt_rounded,
                    label: 'Save JPG',
                    color: Colors.teal,
                    iconSize: 28,
                    fontSize: 11,
                    onPressed: () async {
                      final int count = await PhoneStorageManager.saveImagesToPublicGallery(
                        bundle.jpgFiles.map((f) => f.path).toList(),
                        '${title}_compressed',
                      );
                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ $count Compressed JPG(s) saved to Pictures/BharatScanner!'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      }
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Share PDF',
                    color: appPrimaryColor.value,
                    iconSize: 28,
                    fontSize: 11,
                    onPressed: () async {
                      await Share.shareXFiles([XFile(bundle.pdfFile.path)], text: '$title (Compressed PDF)');
                    },
                  ),
                  LabeledIconButton(
                    icon: Icons.image_rounded,
                    label: 'Share JPG',
                    color: Colors.indigo,
                    iconSize: 28,
                    fontSize: 11,
                    onPressed: () async {
                      await Share.shareXFiles(
                        bundle.jpgFiles.map((f) => XFile(f.path)).toList(),
                        text: '$title (Compressed JPG)',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close'),
                onPressed: () => Navigator.pop(sheetCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN FUNCTION & RUN APP
// ============================================================================
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
                  title: 'Bharat Document Scanner PDF AI',
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
// 1. ANIMATED SPLASH SCREEN
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();

    _timer = Timer(const Duration(milliseconds: 2100), () {
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
      backgroundColor: const Color(0xFF0F1E36),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 270,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2B48), Color(0xFF111D31)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFF385785), width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 15)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('BHARAT', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 3.0, color: Color(0xFFF1C40F))),
                const SizedBox(height: 4),
                const Text('DOCUMENT SCANNER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('PDF', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFFE53935))),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('A', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
                    Icon(Icons.star, color: Color(0xFFFFA000), size: 20),
                    Text('i', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFFFA000))),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF26A69A), borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Text('AI DESKEW & PRO CLARITY', style: TextStyle(color: Color(0xFF003830), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MAIN DASHBOARD SCREEN (ORDERED MULTI-DOC SELECT, DIRECT GALLERY, LABELED UI)
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
  final TextEditingController _searchController = TextEditingController();

  // Ordered Document Multi-Selection on Dashboard (Long press on doc card)
  bool _isDocSelectionMode = false;
  final List<String> _selectedDocIdsOrder = [];

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserFolders();
    _loadSavedDocs();
    _loadBannerAd();
    _searchController.addListener(_filterDocs);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-7940311763952252/4182204348',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  Future<void> _loadUserFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? customFolders = prefs.getStringList('custom_user_folders_v3');
    if (customFolders != null && customFolders.isNotEmpty) {
      setState(() {
        _userFolders = ['All', ...customFolders, 'Starred'];
      });
    }
  }

  Future<void> _loadSavedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString('saved_documents_v6');
    if (rawData != null && mounted) {
      try {
        final List decoded = jsonDecode(rawData);
        setState(() {
          _savedDocs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _filterDocs();
        });
      } catch (e) {
        debugPrint("Error loading docs: $e");
      }
    }
  }

  Future<void> _commitDocsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_documents_v6', jsonEncode(_savedDocs));
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
    });
  }

  // DIRECT PHONE GALLERY / STORAGE IMPORT (OPENS GALLERY DIRECTLY, NEVER CAMERA FIRST)
  Future<void> _importFromGalleryDirectly({
    String category = 'General',
    String prefix = 'Gallery',
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> picked = await picker.pickMultiImage();
      if (!mounted || picked.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/scans');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);

      List<String> persistentRawPaths = [];
      for (int i = 0; i < picked.length; i++) {
        final f = File(picked[i].path);
        if (await f.exists()) {
          final time = DateTime.now().millisecondsSinceEpoch;
          final target = await f.copy('${scansDir.path}/gal_${time}_$i.jpg');
          persistentRawPaths.add(target.path);
        }
      }

      if (!mounted || persistentRawPaths.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanFilterReviewScreen(
            rawImagePaths: persistentRawPaths,
            onApplyAndProceed: (filteredImages) {
              if (category == 'Personal' && prefix.contains('ID_Card') && filteredImages.length >= 2) {
                _processIdCardCollage(filteredImages.sublist(0, 2), persistentRawPaths);
              } else {
                _promptSaveDoc(filteredImages, persistentRawPaths, prefix, category);
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Gallery Import Err: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gallery Error: $e')));
      }
    }
  }

  // CAMERA DOCUMENT SCANNER (USES ScannerMode.base SO ALL PRO FILTERS OPEN DIRECTLY AT BOTTOM)
  Future<void> _startDocScan({
    int limit = 50,
    String category = 'General',
    String prefix = 'Doc',
    String defaultFilter = 'magic_pro',
  }) async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.base,
        isGalleryImport: true,
        pageLimit: limit,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      if (!mounted || result.images.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${appDir.path}/scans');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);

      List<String> persistentRawPaths = [];
      for (int i = 0; i < result.images.length; i++) {
        final f = File(result.images[i]);
        if (await f.exists()) {
          final time = DateTime.now().millisecondsSinceEpoch;
          final target = await f.copy('${scansDir.path}/raw_${time}_$i.jpg');
          persistentRawPaths.add(target.path);
        }
      }

      if (!mounted || persistentRawPaths.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanFilterReviewScreen(
            rawImagePaths: persistentRawPaths,
            initialFilterId: defaultFilter,
            onApplyAndProceed: (filteredImages) {
              if (category == 'Personal' && prefix.contains('ID_Card') && filteredImages.length >= 2) {
                _processIdCardCollage(filteredImages.sublist(0, 2), persistentRawPaths);
              } else {
                _promptSaveDoc(filteredImages, persistentRawPaths, prefix, category);
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Scan Err: $e");
    }
  }

  Future<void> _processIdCardCollage(List<String> frontAndBack, List<String> rawImages) async {
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
      final borderPaint = Paint()..color = const Color(0xFFCFD8DC)..style = PaintingStyle.stroke..strokeWidth = 2.0;

      const top1 = 200.0;
      final rect1 = Rect.fromLTWH(left, top1, cardW, cardH);
      canvas.drawImageRect(frontImg, Rect.fromLTWH(0, 0, frontImg.width.toDouble(), frontImg.height.toDouble()), rect1, Paint());
      canvas.drawRect(rect1, borderPaint);

      const top2 = 820.0;
      final rect2 = Rect.fromLTWH(left, top2, cardW, cardH);
      canvas.drawImageRect(backImg, Rect.fromLTWH(0, 0, backImg.width.toDouble(), backImg.height.toDouble()), rect2, Paint());
      canvas.drawRect(rect2, borderPaint);

      final picture = recorder.endRecording();
      final a4CollageImg = await picture.toImage(a4Width.toInt(), a4Height.toInt());
      final byteData = await a4CollageImg.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final collageFile = File('${appDir.path}/id_a4_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await collageFile.writeAsBytes(byteData.buffer.asUint8List());

        final newDoc = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': 'ID_Card_${DateFormat('ddMMM_HHmm').format(DateTime.now())}',
          'category': 'Personal',
          'isFavorite': false,
          'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          'images': [collageFile.path],
          'originalImages': frontAndBack,
          'pages': 1,
        };

        setState(() {
          _savedDocs.insert(0, newDoc);
          _filterDocs();
        });
        await _commitDocsToPrefs();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Front & Back ID Card stitched onto A4 Sheet!')));
      }
    } catch (e) {
      _promptSaveDoc(frontAndBack, rawImages, 'ID_Card', 'Personal');
    }
  }

  void _promptSaveDoc(List<String> enhancedImages, List<String> rawImages, String prefix, String defaultCat) {
    final nameCtrl = TextEditingController(text: "${prefix}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}");
    String chosenFolder = (defaultCat == 'All' || defaultCat == 'Starred') ? 'General' : defaultCat;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Document Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: chosenFolder,
              decoration: const InputDecoration(labelText: 'Folder', border: OutlineInputBorder()),
              items: _userFolders.where((f) => f != 'All' && f != 'Starred').map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) {
                if (val != null) chosenFolder = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save'),
            onPressed: () async {
              Navigator.pop(ctx);
              final newDoc = {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'title': nameCtrl.text.trim().isEmpty ? 'Doc_${DateTime.now().millisecondsSinceEpoch}' : nameCtrl.text.trim(),
                'category': chosenFolder,
                'isFavorite': false,
                'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                'images': List<String>.from(enhancedImages),
                'originalImages': List<String>.from(rawImages),
                'pages': enhancedImages.length,
              };
              setState(() {
                _savedDocs.insert(0, newDoc);
                _filterDocs();
              });
              await _commitDocsToPrefs();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Document Saved with Pro Clarity!')));
            },
          ),
        ],
      ),
    );
  }

  void _createNewFolderDialog() {
    final folderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(controller: folderCtrl, decoration: const InputDecoration(labelText: 'Folder Name', border: OutlineInputBorder())),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            icon: const Icon(Icons.create_new_folder_rounded, size: 16),
            label: const Text('Create'),
            onPressed: () async {
              final name = folderCtrl.text.trim();
              if (name.isNotEmpty && !_userFolders.contains(name)) {
                final prefs = await SharedPreferences.getInstance();
                final currentCustom = _userFolders.where((f) => f != 'All' && f != 'Starred').toList();
                currentCustom.add(name);
                await prefs.setStringList('custom_user_folders_v3', currentCustom);
                setState(() {
                  _userFolders = ['All', ...currentCustom, 'Starred'];
                  _selectedCategory = name;
                });
                _filterDocs();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  // ORDERED MULTI-DOCUMENT HELPERS (FROM DASHBOARD LONG PRESS)
  List<String> _getOrderedImagesFromSelectedDocs() {
    final List<String> orderedPaths = [];
    for (final docId in _selectedDocIdsOrder) {
      final doc = _savedDocs.firstWhere((d) => d['id'] == docId, orElse: () => {});
      if (doc.isNotEmpty && doc['images'] != null) {
        orderedPaths.addAll(List<String>.from(doc['images']));
      }
    }
    return orderedPaths;
  }

  Future<Uint8List> _buildOrderedPdfBytes(List<String> orderedImagePaths) async {
    final pdf = pw.Document();
    for (final path in orderedImagePaths) {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(8),
            build: (ctx) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
          ),
        );
      }
    }
    return pdf.save();
  }

  Future<void> _exportSelectedDocsPdf({required bool saveToPhone}) async {
    final paths = _getOrderedImagesFromSelectedDocs();
    if (paths.isEmpty) return;
    final pdfBytes = await _buildOrderedPdfBytes(paths);
    final name = 'Ordered_Docs_${_selectedDocIdsOrder.length}';
    if (saveToPhone) {
      final savedPath = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(savedPath != null ? '✅ Ordered PDF saved to Download/BharatScanner!' : '❌ Failed to save PDF'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$name.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Ordered PDF (${_selectedDocIdsOrder.length} Documents)');
    }
  }

  Future<void> _exportSelectedDocsJpg({required bool saveToPhone}) async {
    final paths = _getOrderedImagesFromSelectedDocs();
    if (paths.isEmpty) return;
    if (saveToPhone) {
      final count = await PhoneStorageManager.saveImagesToPublicGallery(paths, 'Selected_Docs');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $count Photo(s) saved to Pictures/BharatScanner!'), backgroundColor: Colors.green.shade700),
        );
      }
    } else {
      await Share.shareXFiles(paths.map((p) => XFile(p)).toList(), text: 'Selected Document Pages');
    }
  }

  void _deleteSelectedDocs() {
    if (_selectedDocIdsOrder.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Documents?'),
        content: Text('Delete ${_selectedDocIdsOrder.length} selected document(s)?'),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _savedDocs.removeWhere((d) => _selectedDocIdsOrder.contains(d['id']));
                _selectedDocIdsOrder.clear();
                _isDocSelectionMode = false;
                _filterDocs();
              });
              _commitDocsToPrefs();
            },
          ),
        ],
      ),
    );
  }

  // ADD NEW DOCUMENT BOTTOM SHEET (DIRECT GALLERY & STORAGE IMPORT)
  void _openAddNewDocBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        const Icon(Icons.description_rounded, size: 40, color: Color(0xFF00B4D8)),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add New Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Choose from below options', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    LabeledIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: 'Close',
                      iconSize: 24,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                _buildSheetTile(Icons.photo_library_rounded, const Color(0xFF00B4D8), 'Import from Gallery (Phone Photos)', () {
                  Navigator.pop(ctx);
                  _importFromGalleryDirectly(prefix: 'Gallery');
                }),
                _buildSheetTile(Icons.camera_alt_rounded, const Color(0xFF4A6572), 'Scan from Camera', () {
                  Navigator.pop(ctx);
                  _startDocScan();
                }),
                _buildSheetTile(Icons.folder_open_rounded, const Color(0xFFEF5350), 'Import Images from Phone Storage', () {
                  Navigator.pop(ctx);
                  _importFromGalleryDirectly(prefix: 'Storage_Img');
                }),
                _buildSheetTile(Icons.menu_book_rounded, const Color(0xFF2E7D32), 'Book Page Scan (Book Ultra AI)', () {
                  Navigator.pop(ctx);
                  _startDocScan(prefix: 'Book_Page', defaultFilter: 'book_ultra');
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetTile(IconData icon, Color color, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          Text('Open', style: TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
      onTap: onTap,
    );
  }

  // DUAL FAB PILL WITH LABELED CAMERA & ADD BUTTONS
  Widget _buildDualFabPill() {
    return ValueListenableBuilder<Color>(
      valueListenable: appPrimaryColor,
      builder: (_, color, __) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
                onTap: () => _startDocScan(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_rounded, color: Colors.white, size: 21),
                      Text('Camera', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Container(width: 1.2, height: 28, color: Colors.white38),
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
                onTap: _openAddNewDocBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      Text('Add / Gal', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _extractTextOCR(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;
      if (recognizedText.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No readable text detected.')));
        return;
      }

      final textCtrl = TextEditingController(text: recognizedText.text);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extracted OCR Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  LabeledIconButton(
                    icon: Icons.copy,
                    label: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: textCtrl.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                    },
                  ),
                ],
              ),
              const Divider(),
              TextField(controller: textCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44)),
                icon: const Icon(Icons.share),
                label: const Text('Share Extracted Text'),
                onPressed: () => Share.share(textCtrl.text),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("OCR Err: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildAppDrawer(isDark),
      appBar: AppBar(
        title: _isDocSelectionMode
            ? Text('${_selectedDocIdsOrder.length} Selected (In Order)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
            : (_isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Search documents...', border: InputBorder.none),
                  )
                : const Text('Bharat Document Scanner AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        actions: _isDocSelectionMode
            ? [
                LabeledIconButton(
                  icon: Icons.select_all_rounded,
                  label: 'All',
                  onPressed: () {
                    setState(() {
                      if (_selectedDocIdsOrder.length == _filteredDocs.length) {
                        _selectedDocIdsOrder.clear();
                      } else {
                        for (final doc in _filteredDocs) {
                          if (!_selectedDocIdsOrder.contains(doc['id'])) {
                            _selectedDocIdsOrder.add(doc['id']);
                          }
                        }
                      }
                    });
                  },
                ),
                LabeledIconButton(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onPressed: () => setState(() {
                    _isDocSelectionMode = false;
                    _selectedDocIdsOrder.clear();
                  }),
                ),
              ]
            : [
                LabeledIconButton(
                  icon: _isSearching ? Icons.close : Icons.search_rounded,
                  label: _isSearching ? 'Close' : 'Search',
                  onPressed: () => setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) _searchController.clear();
                  }),
                ),
              ],
      ),
      body: Stack(
        children: [
          _currentTabIndex == 0 ? _buildDocsTab() : _buildToolsTab(),
          if (!_isDocSelectionMode)
            Positioned(
              right: 16,
              bottom: 20,
              child: _buildDualFabPill(),
            ),
        ],
      ),
      floatingActionButtonLocation: _isDocSelectionMode ? null : FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _isDocSelectionMode
          ? null
          : FloatingActionButton(
              elevation: 4,
              shape: const CircleBorder(),
              backgroundColor: appPrimaryColor.value,
              foregroundColor: Colors.white,
              onPressed: () => _startDocScan(),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded, size: 22),
                  Text('Scan', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
      bottomNavigationBar: _isDocSelectionMode
          ? Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: SafeArea(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      LabeledIconButton(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'Share PDF',
                        color: appPrimaryColor.value,
                        onPressed: () => _exportSelectedDocsPdf(saveToPhone: false),
                      ),
                      LabeledIconButton(
                        icon: Icons.download_for_offline_rounded,
                        label: 'Save PDF',
                        color: Colors.redAccent,
                        onPressed: () => _exportSelectedDocsPdf(saveToPhone: true),
                      ),
                      LabeledIconButton(
                        icon: Icons.image_rounded,
                        label: 'Share JPG',
                        color: Colors.indigo,
                        onPressed: () => _exportSelectedDocsJpg(saveToPhone: false),
                      ),
                      LabeledIconButton(
                        icon: Icons.save_alt_rounded,
                        label: 'Save JPG',
                        color: Colors.teal,
                        onPressed: () => _exportSelectedDocsJpg(saveToPhone: true),
                      ),
                      LabeledIconButton(
                        icon: Icons.compress_rounded,
                        label: 'Compress',
                        color: Colors.orange.shade800,
                        onPressed: () {
                          final paths = _getOrderedImagesFromSelectedDocs();
                          if (paths.isNotEmpty) {
                            ProCompressionEngine.showCompressorDialog(
                              context: context,
                              orderedPaths: paths,
                              title: 'Selected_Docs_${_selectedDocIdsOrder.length}',
                            );
                          }
                        },
                      ),
                      LabeledIconButton(
                        icon: Icons.delete_rounded,
                        label: 'Delete',
                        color: Colors.red,
                        onPressed: _deleteSelectedDocs,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BottomAppBar(
                  shape: const CircularNotchedRectangle(),
                  notchMargin: 8,
                  elevation: 10,
                  color: Theme.of(context).cardColor,
                  child: SizedBox(
                    height: 58,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _currentTabIndex = 0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_special_rounded, color: _currentTabIndex == 0 ? appPrimaryColor.value : Colors.grey, size: 24),
                                Text('Documents', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 0 ? appPrimaryColor.value : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                        InkWell(
                          onTap: () => setState(() => _currentTabIndex = 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_mosaic_rounded, color: _currentTabIndex == 1 ? appPrimaryColor.value : Colors.grey, size: 24),
                                Text('Studio Tools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _currentTabIndex == 1 ? appPrimaryColor.value : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isBannerLoaded && _bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.document_scanner_rounded, size: 36, color: Colors.white),
                SizedBox(height: 8),
                Text('BHARAT SCANNER PDF AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Ultra Clarity Book & Studio Edition', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
            onTap: () {
              Navigator.pop(context);
              _openThemeColorPicker();
            },
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Language / भाषा'),
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
        ],
      ),
    );
  }

  void _openThemeColorPicker() {
    final colors = [Colors.pink, Colors.teal, Colors.blue, Colors.deepOrange, Colors.purple, Colors.green, Colors.indigo, Colors.blueGrey];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors
              .map((col) => InkWell(
                    onTap: () async {
                      appPrimaryColor.value = col;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('primary_color_val', col.value);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: CircleAvatar(backgroundColor: col, radius: 20),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: DOCUMENTS TAB (WITH LONG-PRESS ORDERED MULTI-DOC SELECTION)
  // ==========================================================================
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
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._userFolders.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    selectedColor: appPrimaryColor.value,
                    labelStyle: TextStyle(color: isSel ? Colors.white : null, fontSize: 11),
                    onSelected: (val) => setState(() {
                      _selectedCategory = cat;
                      _filterDocs();
                    }),
                  ),
                );
              }),
              ActionChip(
                label: const Text('+ New Folder', style: TextStyle(fontSize: 11)),
                onPressed: _createNewFolderDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documents (${_filteredDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text('Tip: Long press any doc or page to select in order', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            LabeledIconButton(
              icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              label: _isGridView ? 'List View' : 'Grid View',
              iconSize: 20,
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_filteredDocs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No documents saved yet. Tap Camera to Scan!')),
          )
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (ctx, i) => _buildDocGridCard(_filteredDocs[i]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredDocs.length,
            itemBuilder: (ctx, i) => _buildDocListTile(_filteredDocs[i]),
          ),
        const SizedBox(height: 95),
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

  void _toggleDocSelection(String docId) {
    setState(() {
      if (_selectedDocIdsOrder.contains(docId)) {
        _selectedDocIdsOrder.remove(docId);
        if (_selectedDocIdsOrder.isEmpty) _isDocSelectionMode = false;
      } else {
        _isDocSelectionMode = true;
        _selectedDocIdsOrder.add(docId);
      }
    });
  }

  Widget _buildDocListTile(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final bool hasImage = imgs.isNotEmpty && File(imgs.first).existsSync();
    final String docId = doc['id'].toString();
    final int orderIdx = _selectedDocIdsOrder.indexOf(docId);
    final bool isSelected = orderIdx != -1;

    return Card(
      elevation: isSelected ? 2 : 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? appPrimaryColor.value : Colors.transparent, width: isSelected ? 2 : 0),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: hasImage
                  ? Image.file(File(imgs.first), width: 50, height: 60, fit: BoxFit.cover, cacheWidth: 200)
                  : Container(width: 50, height: 60, color: Colors.grey.shade200),
            ),
            if (isSelected)
              Positioned(
                top: 2,
                left: 2,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: appPrimaryColor.value,
                  child: Text('${orderIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        title: Text(doc['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
        subtitle: Text('${doc['pages']} pages • ${doc['category'] ?? 'General'} • ${doc['date']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: _isDocSelectionMode
            ? Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? appPrimaryColor.value : Colors.grey)
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  Text('Open', style: TextStyle(fontSize: 8, color: Colors.grey)),
                ],
              ),
        onLongPress: () => _toggleDocSelection(docId),
        onTap: () {
          if (_isDocSelectionMode) {
            _toggleDocSelection(docId);
          } else {
            _openDocDetail(doc);
          }
        },
      ),
    );
  }

  Widget _buildDocGridCard(Map<String, dynamic> doc) {
    final List imgs = doc['images'] ?? [];
    final bool hasImg = imgs.isNotEmpty && File(imgs.first).existsSync();
    final String docId = doc['id'].toString();
    final int orderIdx = _selectedDocIdsOrder.indexOf(docId);
    final bool isSelected = orderIdx != -1;

    return InkWell(
      onLongPress: () => _toggleDocSelection(docId),
      onTap: () {
        if (_isDocSelectionMode) {
          _toggleDocSelection(docId);
        } else {
          _openDocDetail(doc);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? appPrimaryColor.value : Colors.grey.withOpacity(0.25), width: isSelected ? 2.5 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: hasImg ? Image.file(File(imgs.first), fit: BoxFit.cover, width: double.infinity, cacheWidth: 300) : Container(color: Colors.grey.shade200),
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
            if (_isDocSelectionMode)
              Positioned(
                top: 6,
                right: 6,
                child: isSelected
                    ? CircleAvatar(
                        radius: 13,
                        backgroundColor: appPrimaryColor.value,
                        child: Text('#${orderIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    : const Icon(Icons.circle_outlined, color: Colors.white, size: 26),
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
          onDocUpdated: (updated) {
            setState(() {
              final idx = _savedDocs.indexWhere((d) => d['id'] == updated['id']);
              if (idx != -1) _savedDocs[idx] = updated;
              _filterDocs();
            });
            _commitDocsToPrefs();
          },
          onDelete: () {
            setState(() {
              _savedDocs.removeWhere((d) => d['id'] == doc['id']);
              _filterDocs();
            });
            _commitDocsToPrefs();
          },
          onExtractText: _extractTextOCR,
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 2: ALL STUDIO TOOLS SUITE (WITH DIRECT GALLERY & BOOK ULTRA)
  // ==========================================================================
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Smart AI Scan Modes'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('ID Card Mode', 'Front & Back', Icons.badge_outlined, Colors.blue, () => _startDocScan(limit: 2, category: 'Personal', prefix: 'ID_Card')),
            _buildToolCard('Book Scan', 'Book Ultra AI', Icons.menu_book_rounded, Colors.green, () => _startDocScan(prefix: 'Book_Page', defaultFilter: 'book_ultra')),
            _buildToolCard('AI OCR Text', 'Extract Text', Icons.auto_awesome, Colors.purple, () {
              if (_savedDocs.isNotEmpty && (_savedDocs.first['images'] as List).isNotEmpty) {
                _extractTextOCR(_savedDocs.first['images'][0]);
              } else {
                _startDocScan();
              }
            }),
            _buildToolCard('From Gallery', 'Phone Photos', Icons.photo_library_outlined, const Color(0xFFD81B60), () => _importFromGalleryDirectly(prefix: 'Gallery')),
            _buildToolCard('Target Compress', '10KB - 5MB', Icons.compress_rounded, Colors.teal, () {
              if (_savedDocs.isNotEmpty) {
                _openDocDetail(_savedDocs.first);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please scan or create a document first!')));
              }
            }),
            _buildToolCard('QR & Barcode', 'Generate Code', Icons.qr_code_2_rounded, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrBarcodeStudioScreen()))),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Office & Productivity Suite'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('Resume Maker', 'Pro CV Maker', Icons.assignment_ind_rounded, const Color(0xFF0277BD), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumeBuilderScreen()))),
            _buildToolCard('GST Invoice', 'With Tax Slips', Icons.receipt_long_rounded, const Color(0xFF2E7D32), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceMakerProScreen()))),
            _buildToolCard('Slides Maker', 'PPT Slides', Icons.slideshow_rounded, const Color(0xFFD84315), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PowerPointStudioScreen()))),
            _buildToolCard('Letters', 'Formal Letters', Icons.mail_outline_rounded, const Color(0xFF6A1B9A), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LetterTemplatesScreen()))),
            _buildToolCard('Notes & TXT', 'Text Editor', Icons.edit_note_rounded, const Color(0xFF00796B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxtEditorNotesScreen()))),
            _buildToolCard('Passport Photo', '4/8/16 Prints', Icons.portrait_rounded, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPhotoStudioScreen()))),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Image & PDF Studio'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: [
            _buildToolCard('Digital Sign', 'Transparent PNG', Icons.draw_rounded, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalSignatureScreen()))),
            _buildToolCard('PDF Merge', 'Combine Files', Icons.picture_as_pdf_rounded, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfStudioScreen(savedDocs: _savedDocs)))),
            _buildToolCard('Watermark', 'Stamp Text', Icons.branding_watermark_outlined, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WatermarkToolScreen(savedDocs: _savedDocs)))),
            _buildToolCard('Photo Rotate', '90° Angle', Icons.crop_rotate_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalImageToolScreen()))),
          ],
        ),
        const SizedBox(height: 95),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: appPrimaryColor.value),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildToolCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).cardColor,
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 20, backgroundColor: color.withOpacity(0.12), foregroundColor: color, child: Icon(icon, size: 20)),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(color: Colors.grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. PRO SCAN FILTER & RETOUCH SCREEN (ALL 8 PRO FILTERS SHOWN TOGETHER AT BOTTOM)
// ============================================================================
class ScanFilterReviewScreen extends StatefulWidget {
  final List<String> rawImagePaths;
  final String initialFilterId;
  final Function(List<String> filteredPaths) onApplyAndProceed;

  const ScanFilterReviewScreen({
    super.key,
    required this.rawImagePaths,
    this.initialFilterId = 'magic_pro',
    required this.onApplyAndProceed,
  });

  @override
  State<ScanFilterReviewScreen> createState() => _ScanFilterReviewScreenState();
}

class _ScanFilterReviewScreenState extends State<ScanFilterReviewScreen> {
  int _curPageIndex = 0;
  bool _isSaving = false;
  bool _isRenderingPreview = false;
  bool _showOriginalHold = false;
  double _manualDeskewAngle = 0.0;
  int _activeTopTab = 1; // 0 = Straighten AI, 1 = Filters, 2 = Tilt & Rotate

  late List<String> _workingPaths;
  late Map<int, String> _pageFilterSelections;
  late Map<int, double> _pageFilterIntensities;

  // Cached preview buffers per page for ultra-fast Pro filter switching
  final Map<int, Uint8List> _cachedBasePreviewRgba = {};
  final Map<int, List<int>> _cachedBasePreviewWH = {};
  final Map<int, Uint8List> _renderedPreviewPng = {};
  int _renderRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _workingPaths = List<String>.from(widget.rawImagePaths);
    _pageFilterSelections = {
      for (var i = 0; i < widget.rawImagePaths.length; i++) i: widget.initialFilterId,
    };
    _pageFilterIntensities = {
      for (var i = 0; i < widget.rawImagePaths.length; i++) i: 0.65,
    };
    _renderCurrentPagePreview();
  }

  DocFilterPreset get _currentPreset => kDocFilters.firstWhere(
        (f) => f.id == (_pageFilterSelections[_curPageIndex] ?? 'magic_pro'),
        orElse: () => kDocFilters[1],
      );

  double get _currentIntensity => _pageFilterIntensities[_curPageIndex] ?? 0.65;

  Future<void> _renderCurrentPagePreview() async {
    final int pageIdx = _curPageIndex;
    final int token = ++_renderRequestToken;
    final String filterId = _pageFilterSelections[pageIdx] ?? 'magic_pro';
    final double intensity = _pageFilterIntensities[pageIdx] ?? 0.65;

    if (filterId == 'original') {
      if (mounted) {
        setState(() {
          _renderedPreviewPng.remove(pageIdx);
          _isRenderingPreview = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isRenderingPreview = true);

    if (!_cachedBasePreviewRgba.containsKey(pageIdx)) {
      final wh = [0, 0];
      final rgba = await ProDocImageProcessor.decodeImageToRgba(
        _workingPaths[pageIdx],
        maxDimension: 860,
        outWidthHeight: wh,
      );
      if (rgba != null) {
        _cachedBasePreviewRgba[pageIdx] = rgba;
        _cachedBasePreviewWH[pageIdx] = wh;
      }
    }

    final baseRgba = _cachedBasePreviewRgba[pageIdx];
    final wh = _cachedBasePreviewWH[pageIdx];
    if (baseRgba == null || wh == null) {
      if (mounted) setState(() => _isRenderingPreview = false);
      return;
    }

    final filteredRgba = await ProDocImageProcessor.applyProFilterToRgba(
      rgba: baseRgba,
      width: wh[0],
      height: wh[1],
      filterId: filterId,
      intensity: intensity,
    );

    if (token != _renderRequestToken) return;

    final pngBytes = await ProDocImageProcessor.encodeRgbaToPngBytes(filteredRgba, wh[0], wh[1]);
    if (!mounted || token != _renderRequestToken) return;

    setState(() {
      if (pngBytes != null) _renderedPreviewPng[pageIdx] = pngBytes;
      _isRenderingPreview = false;
    });
  }

  Future<void> _applyAllPagesSameFilter() async {
    final activeFilter = _pageFilterSelections[_curPageIndex] ?? 'magic_pro';
    final activeIntensity = _currentIntensity;
    setState(() {
      for (int i = 0; i < _workingPaths.length; i++) {
        _pageFilterSelections[i] = activeFilter;
        _pageFilterIntensities[i] = activeIntensity;
        _renderedPreviewPng.remove(i);
      }
    });
    _renderCurrentPagePreview();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Applied "${_currentPreset.title}" to ALL ${_workingPaths.length} pages!')),
    );
  }

  Future<void> _runAutoStraightenAI() async {
    setState(() => _isSaving = true);
    final curImg = _workingPaths[_curPageIndex];
    final detectedAngle = await AIDeskewEngine.detectSkewAngle(curImg);

    if (detectedAngle.abs() > 0.4) {
      final straightened = await AIDeskewEngine.rotateAndDeskewImage(curImg, -detectedAngle);
      _cachedBasePreviewRgba.remove(_curPageIndex);
      _renderedPreviewPng.remove(_curPageIndex);
      setState(() {
        _workingPaths[_curPageIndex] = straightened;
        _manualDeskewAngle = 0.0;
        _isSaving = false;
      });
      _renderCurrentPagePreview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✨ AI Straightened by ${detectedAngle.toStringAsFixed(1)}°')));
      }
    } else {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Page is already straight!')));
      }
    }
  }

  Future<void> _rotateCurrentPage90() async {
    setState(() => _isSaving = true);
    final curPath = _workingPaths[_curPageIndex];
    final bytes = await File(curPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imgUi = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgUi.height.toDouble(), imgUi.width.toDouble()));
    canvas.translate(imgUi.height.toDouble() / 2, imgUi.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(imgUi, Offset(-imgUi.width.toDouble() / 2, -imgUi.height.toDouble() / 2), Paint());

    final outImg = await recorder.endRecording().toImage(imgUi.height, imgUi.width);
    final data = await outImg.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final rotatedFile = File('${appDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.png');
      await rotatedFile.writeAsBytes(data.buffer.asUint8List());
      _cachedBasePreviewRgba.remove(_curPageIndex);
      _renderedPreviewPng.remove(_curPageIndex);

      setState(() {
        _workingPaths[_curPageIndex] = rotatedFile.path;
        _isSaving = false;
      });
      _renderCurrentPagePreview();
    } else {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _finishAndExport() async {
    setState(() => _isSaving = true);
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);

    List<String> enhancedPaths = [];
    for (int i = 0; i < _workingPaths.length; i++) {
      String sourceImg = _workingPaths[i];

      if (i == _curPageIndex && _manualDeskewAngle.abs() > 0.5) {
        sourceImg = await AIDeskewEngine.rotateAndDeskewImage(sourceImg, _manualDeskewAngle);
      }

      final filterId = _pageFilterSelections[i] ?? 'magic_pro';
      final intensity = _pageFilterIntensities[i] ?? 0.65;
      final outPath = '${scansDir.path}/pro_${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';

      final savedPath = await ProDocImageProcessor.processAndSaveHighRes(
        sourcePath: sourceImg,
        filterId: filterId,
        intensity: intensity,
        outputPath: outPath,
      );
      enhancedPaths.add(savedPath);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      widget.onApplyAndProceed(enhancedPaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePreset = _currentPreset;
    final curImg = File(_workingPaths[_curPageIndex]);
    final previewBytes = _renderedPreviewPng[_curPageIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF14161B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14161B),
        foregroundColor: Colors.white,
        title: Text('Page ${_curPageIndex + 1}/${_workingPaths.length} • ${activePreset.title}', style: const TextStyle(fontSize: 14)),
        actions: [
          LabeledIconButton(
            icon: Icons.compare_rounded,
            label: 'Original',
            color: _showOriginalHold ? Colors.amber : Colors.white70,
            onPressed: () => setState(() => _showOriginalHold = !_showOriginalHold),
          ),
          LabeledIconButton(
            icon: Icons.done_all_rounded,
            label: 'Apply All',
            color: const Color(0xFF8AB4F8),
            onPressed: _applyAllPagesSameFilter,
          ),
          LabeledIconButton(
            icon: Icons.check_circle_rounded,
            label: 'Save',
            color: Colors.greenAccent,
            iconSize: 23,
            onPressed: _isSaving ? null : _finishAndExport,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('Applying Pro Clarity AI Enhancement...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )
          : Column(
              children: [
                // Top Tool Switcher Pills
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopPill('Straighten AI', Icons.auto_awesome, _activeTopTab == 0, () {
                        setState(() => _activeTopTab = 0);
                        _runAutoStraightenAI();
                      }),
                      const SizedBox(width: 8),
                      _buildTopPill('Pro Filters', Icons.auto_fix_high_rounded, _activeTopTab == 1, () => setState(() => _activeTopTab = 1)),
                      const SizedBox(width: 8),
                      _buildTopPill('Tilt & Rotate', Icons.crop_rotate_rounded, _activeTopTab == 2, () => setState(() => _activeTopTab = 2)),
                    ],
                  ),
                ),

                // Main Document Preview Canvas
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Transform.rotate(
                          angle: _manualDeskewAngle * pi / 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: (_showOriginalHold || activePreset.id == 'original' || previewBytes == null)
                                ? Image.file(curImg, fit: BoxFit.contain)
                                : Image.memory(previewBytes, fit: BoxFit.contain, gaplessPlayback: true),
                          ),
                        ),
                      ),
                      if (_isRenderingPreview)
                        Positioned(
                          top: 10,
                          right: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                                SizedBox(width: 6),
                                Text('Enhancing...', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Tilt / Rotate Controls OR All 8 Pro Filters Panel at Bottom
                if (_activeTopTab == 2)
                  Container(
                    color: const Color(0xFF1F2229),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.straighten, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text('Tilt Angle: ${_manualDeskewAngle.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            const Spacer(),
                            LabeledIconButton(
                              icon: Icons.refresh_rounded,
                              label: 'Reset',
                              color: const Color(0xFF8AB4F8),
                              onPressed: () => setState(() => _manualDeskewAngle = 0.0),
                            ),
                            LabeledIconButton(
                              icon: Icons.rotate_right_rounded,
                              label: 'Rotate 90°',
                              color: Colors.white,
                              onPressed: _rotateCurrentPage90,
                            ),
                          ],
                        ),
                        Slider(
                          value: _manualDeskewAngle,
                          min: -30.0,
                          max: 30.0,
                          activeColor: const Color(0xFF8AB4F8),
                          inactiveColor: Colors.grey.shade800,
                          onChanged: (val) => setState(() => _manualDeskewAngle = val),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF1F2229),
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pro Clarity / Ink Intensity Slider
                        Row(
                          children: [
                            const Text('Clarity:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Slider(
                                value: _currentIntensity,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                activeColor: const Color(0xFF8AB4F8),
                                inactiveColor: Colors.grey.shade700,
                                onChanged: (val) {
                                  setState(() {
                                    _pageFilterIntensities[_curPageIndex] = val;
                                  });
                                },
                                onChangeEnd: (_) => _renderCurrentPagePreview(),
                              ),
                            ),
                            Text('${(_currentIntensity * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),

                        // ALL 8 PRO FILTERS SHOWN TOGETHER AT ONCE IN ONE PLACE (NO SECOND SCREEN)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: kDocFilters.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: 1.65,
                          ),
                          itemBuilder: (ctx, i) {
                            final f = kDocFilters[i];
                            final isSel = activePreset.id == f.id;
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {
                                  _showOriginalHold = false;
                                  _pageFilterSelections[_curPageIndex] = f.id;
                                });
                                _renderCurrentPagePreview();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF2F4770) : const Color(0xFF2A2D36),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF8AB4F8) : Colors.white12,
                                    width: isSel ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(f.icon, color: isSel ? const Color(0xFF8AB4F8) : Colors.white70, size: 17),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSel ? Colors.white : Colors.white70,
                                        fontSize: 9.5,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // Multi-page thumbnail strip at bottom
                if (_workingPaths.length > 1)
                  Container(
                    height: 68,
                    color: const Color(0xFF14161B),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _workingPaths.length,
                      itemBuilder: (ctx, idx) {
                        final isSelectedPage = _curPageIndex == idx;
                        final pageImg = File(_workingPaths[idx]);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _curPageIndex = idx;
                              _showOriginalHold = false;
                            });
                            _renderCurrentPagePreview();
                          },
                          child: Container(
                            width: 50,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelectedPage ? const Color(0xFF8AB4F8) : Colors.grey.shade700,
                                width: isSelectedPage ? 2.5 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(pageImg, fit: BoxFit.cover, cacheWidth: 150),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  left: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(4)),
                                    child: Text('P${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildTopPill(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB0CCF9) : const Color(0xFF26282E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF003062) : Colors.white),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(color: isSelected ? const Color(0xFF003062) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. DOCUMENT DETAIL SCREEN (LONG-PRESS ORDERED PAGE SELECTION + PRO ACTIONS)
// ============================================================================
class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final Function(Map<String, dynamic>) onDocUpdated;
  final VoidCallback onDelete;
  final Function(String) onExtractText;

  const DocumentDetailScreen({
    super.key,
    required this.doc,
    required this.onDocUpdated,
    required this.onDelete,
    required this.onExtractText,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late List<String> _images;
  late List<String> _originalImages;
  late String _title;

  bool _isSelectionMode = false;
  // PRESERVES EXACT TAP/SELECTION ORDER FOR PDF & EXPORTS!
  final List<int> _selectedIndicesOrder = [];

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.doc['images'] ?? []);
    _originalImages = List<String>.from(widget.doc['originalImages'] ?? widget.doc['images'] ?? []);
    _title = widget.doc['title'] ?? 'Document';
  }

  // Returns images strictly in the user's selected order (#1, #2, #3...)
  List<String> get _targetImagesInOrder {
    if (_isSelectionMode && _selectedIndicesOrder.isNotEmpty) {
      return _selectedIndicesOrder.map((i) => _images[i]).toList();
    }
    return _images;
  }

  void _togglePageSelection(int idx) {
    setState(() {
      if (_selectedIndicesOrder.contains(idx)) {
        _selectedIndicesOrder.remove(idx);
        if (_selectedIndicesOrder.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedIndicesOrder.add(idx);
      }
    });
  }

  void _renameDoc() {
    final ctrl = TextEditingController(text: _title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _title = ctrl.text.trim();
                widget.doc['title'] = _title;
              });
              widget.onDocUpdated(widget.doc);
            },
          ),
        ],
      ),
    );
  }

  void _reEditSelectedPages() {
    final List<int> indicesToEdit = _isSelectionMode && _selectedIndicesOrder.isNotEmpty
        ? List<int>.from(_selectedIndicesOrder)
        : List<int>.generate(_images.length, (i) => i);

    final pathsToEdit = indicesToEdit.map((i) => _images[i]).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFilterReviewScreen(
          rawImagePaths: pathsToEdit,
          onApplyAndProceed: (retouchedPaths) {
            setState(() {
              for (int k = 0; k < indicesToEdit.length; k++) {
                _images[indicesToEdit[k]] = retouchedPaths[k];
              }
              widget.doc['images'] = _images;
            });
            widget.onDocUpdated(widget.doc);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Retouched Pages Saved!')));
          },
        ),
      ),
    );
  }

  Future<void> _addMorePagesSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add More Pages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE0F7FA), child: Icon(Icons.photo_library_rounded, color: Color(0xFF00B4D8))),
                title: const Text('Import from Gallery'),
                subtitle: const Text('Open phone gallery directly'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickMultiImage();
                  if (picked.isNotEmpty) {
                    _appendNewImagesThroughFilter(picked.map((x) => x.path).toList());
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFCE4EC), child: Icon(Icons.camera_alt_rounded, color: Colors.pink)),
                title: const Text('Scan from Camera'),
                subtitle: const Text('Capture new pages'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final scanner = DocumentScanner(
                    options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: 20),
                  );
                  try {
                    final res = await scanner.scanDocument();
                    if (res.images.isNotEmpty) {
                      _appendNewImagesThroughFilter(res.images);
                    }
                  } catch (e) {
                    debugPrint("Add page err: $e");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _appendNewImagesThroughFilter(List<String> rawPaths) async {
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!await scansDir.exists()) await scansDir.create(recursive: true);

    List<String> copiedRaw = [];
    for (int i = 0; i < rawPaths.length; i++) {
      final f = File(rawPaths[i]);
      if (await f.exists()) {
        final target = '${scansDir.path}/add_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await f.copy(target);
        copiedRaw.add(target);
      }
    }
    if (!mounted || copiedRaw.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFilterReviewScreen(
          rawImagePaths: copiedRaw,
          onApplyAndProceed: (filteredPaths) {
            setState(() {
              _images.addAll(filteredPaths);
              _originalImages.addAll(copiedRaw);
              widget.doc['images'] = _images;
              widget.doc['originalImages'] = _originalImages;
              widget.doc['pages'] = _images.length;
            });
            widget.onDocUpdated(widget.doc);
          },
        ),
      ),
    );
  }

  Future<Uint8List> _buildOrderedPdfBytes(List<String> orderedImgs) async {
    final pdf = pw.Document();
    for (final path in orderedImgs) {
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(8),
            build: (ctx) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
          ),
        );
      }
    }
    return pdf.save();
  }

  Future<void> _shareOrderedPdf() async {
    final imgs = _targetImagesInOrder;
    if (imgs.isEmpty) return;
    final pdfBytes = await _buildOrderedPdfBytes(imgs);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${_title.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: '$_title (${imgs.length} Pages PDF)');
  }

  Future<void> _saveOrderedPdfToPhone() async {
    final imgs = _targetImagesInOrder;
    if (imgs.isEmpty) return;
    final pdfBytes = await _buildOrderedPdfBytes(imgs);
    final savedPath = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, _title);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath != null ? '✅ PDF (${imgs.length} pages) saved to Download/BharatScanner!' : '❌ Failed to save PDF'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _shareImagesDirectly() async {
    final imgs = _targetImagesInOrder;
    List<XFile> xFiles = imgs.map((p) => XFile(p)).toList();
    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(xFiles, text: '$_title Photos (${imgs.length} Pages)');
    }
  }

  Future<void> _saveJpgToPhone() async {
    final imgs = _targetImagesInOrder;
    if (imgs.isEmpty) return;

    final int count = await PhoneStorageManager.saveImagesToPublicGallery(imgs, _title);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $count photo(s) saved directly to Phone Gallery (Pictures/BharatScanner)!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  void _deleteSelectedPages() {
    if (_selectedIndicesOrder.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pages?'),
        content: Text('Delete ${_selectedIndicesOrder.length} selected page(s)?'),
        actions: [
          TextButton.icon(icon: const Icon(Icons.close, size: 16), label: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () {
              Navigator.pop(ctx);
              final sortedDesc = _selectedIndicesOrder.toList()..sort((a, b) => b.compareTo(a));
              for (var idx in sortedDesc) {
                _images.removeAt(idx);
              }
              if (_images.isEmpty) {
                widget.onDelete();
                Navigator.pop(context);
              } else {
                setState(() {
                  widget.doc['images'] = _images;
                  widget.doc['pages'] = _images.length;
                  _isSelectionMode = false;
                  _selectedIndicesOrder.clear();
                });
                widget.onDocUpdated(widget.doc);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _isSelectionMode ? null : _renameDoc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _isSelectionMode ? '${_selectedIndicesOrder.length} Selected (In Order)' : _title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              if (!_isSelectionMode) ...[const SizedBox(width: 6), const Icon(Icons.edit, size: 14)],
            ],
          ),
        ),
        actions: [
          if (_isSelectionMode) ...[
            LabeledIconButton(
              icon: Icons.select_all_rounded,
              label: 'Select All',
              onPressed: () {
                setState(() {
                  if (_selectedIndicesOrder.length == _images.length) {
                    _selectedIndicesOrder.clear();
                  } else {
                    for (int i = 0; i < _images.length; i++) {
                      if (!_selectedIndicesOrder.contains(i)) {
                        _selectedIndicesOrder.add(i);
                      }
                    }
                  }
                });
              },
            ),
            LabeledIconButton(
              icon: Icons.close_rounded,
              label: 'Done',
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIndicesOrder.clear();
              }),
            ),
          ] else ...[
            LabeledIconButton(
              icon: Icons.auto_fix_high_rounded,
              label: 'Edit All',
              onPressed: _reEditSelectedPages,
            ),
            LabeledIconButton(
              icon: Icons.checklist_rounded,
              label: 'Select',
              onPressed: () => setState(() => _isSelectionMode = true),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_images.length} Pages • Folder: ${widget.doc['category'] ?? 'General'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                      Text(
                        _isSelectionMode
                            ? 'Tap pages in the exact order (#1, #2...) for PDF!'
                            : 'Long press any page to select & order pages',
                        style: TextStyle(fontSize: 10, color: _isSelectionMode ? appPrimaryColor.value : Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appPrimaryColor.value,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: Text(AppLang.tr('add_more'), style: const TextStyle(fontSize: 11)),
                  onPressed: _addMorePagesSheet,
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
                      final int orderPos = _selectedIndicesOrder.indexOf(idx);
                      final bool isSelected = orderPos != -1;
                      final file = File(_images[idx]);

                      return GestureDetector(
                        onLongPress: () => _togglePageSelection(idx),
                        onTap: () {
                          if (_isSelectionMode) {
                            _togglePageSelection(idx);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenPhotoViewer(
                                  images: _images,
                                  originalImages: _originalImages,
                                  initialIndex: idx,
                                  title: _title,
                                  onDocUpdated: () {
                                    setState(() => _images = List<String>.from(widget.doc['images']));
                                    widget.onDocUpdated(widget.doc);
                                  },
                                  onExtractText: widget.onExtractText,
                                  onReEditPage: (pageIdx) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScanFilterReviewScreen(
                                          rawImagePaths: [_images[pageIdx]],
                                          onApplyAndProceed: (retouched) {
                                            setState(() {
                                              _images[pageIdx] = retouched.first;
                                              widget.doc['images'] = _images;
                                            });
                                            widget.onDocUpdated(widget.doc);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? appPrimaryColor.value : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover, cacheWidth: 300)
                                      : Container(color: Colors.grey.shade200),
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
                              if (_isSelectionMode)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: isSelected
                                      ? CircleAvatar(
                                          radius: 12,
                                          backgroundColor: appPrimaryColor.value,
                                          child: Text(
                                            '#${orderPos + 1}',
                                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : const Icon(Icons.circle_outlined, color: Colors.white, size: 24),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                LabeledIconButton(icon: Icons.picture_as_pdf_rounded, label: 'Share PDF', color: appPrimaryColor.value, onPressed: _shareOrderedPdf),
                LabeledIconButton(icon: Icons.download_for_offline_rounded, label: 'Save PDF', color: Colors.redAccent, onPressed: _saveOrderedPdfToPhone),
                LabeledIconButton(icon: Icons.image_rounded, label: 'Share JPG', color: Colors.indigo, onPressed: _shareImagesDirectly),
                LabeledIconButton(icon: Icons.save_alt_rounded, label: 'Save JPG', color: Colors.teal, onPressed: _saveJpgToPhone),
                LabeledIconButton(
                  icon: Icons.compress_rounded,
                  label: 'Compress',
                  color: Colors.orange.shade800,
                  onPressed: () {
                    final ordered = _targetImagesInOrder;
                    if (ordered.isNotEmpty) {
                      ProCompressionEngine.showCompressorDialog(
                        context: context,
                        orderedPaths: ordered,
                        title: _title,
                      );
                    }
                  },
                ),
                LabeledIconButton(icon: Icons.auto_fix_high_rounded, label: 'Edit Page', color: Colors.purple, onPressed: _reEditSelectedPages),
                if (_isSelectionMode && _selectedIndicesOrder.isNotEmpty)
                  LabeledIconButton(icon: Icons.delete_rounded, label: 'Delete', color: Colors.red, onPressed: _deleteSelectedPages),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. FULL SCREEN PHOTO VIEWER (ALL BUTTONS LABELED)
// ============================================================================
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> images;
  final List<String> originalImages;
  final int initialIndex;
  final String title;
  final VoidCallback onDocUpdated;
  final Function(String) onExtractText;
  final Function(int pageIndex) onReEditPage;

  const FullScreenPhotoViewer({
    super.key,
    required this.images,
    required this.originalImages,
    required this.initialIndex,
    required this.title,
    required this.onDocUpdated,
    required this.onExtractText,
    required this.onReEditPage,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Restored Original Camera Photo.')));
    }
  }

  Future<void> _rotatePage() async {
    final curPath = widget.images[_curPage];
    final bytes = await File(curPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imgUi = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgUi.height.toDouble(), imgUi.width.toDouble()));
    canvas.translate(imgUi.height.toDouble() / 2, imgUi.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(imgUi, Offset(-imgUi.width.toDouble() / 2, -imgUi.height.toDouble() / 2), Paint());

    final outImg = await recorder.endRecording().toImage(imgUi.height, imgUi.width);
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
        title: Text('${widget.title} (${_curPage + 1}/${widget.images.length})', style: const TextStyle(fontSize: 13)),
        actions: [
          LabeledIconButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'Edit',
            color: Colors.cyanAccent,
            onPressed: () {
              Navigator.pop(context);
              widget.onReEditPage(_curPage);
            },
          ),
          LabeledIconButton(icon: Icons.rotate_right_rounded, label: 'Rotate', color: Colors.white, onPressed: _rotatePage),
          LabeledIconButton(icon: Icons.restore_rounded, label: 'Reset', color: Colors.orangeAccent, onPressed: _resetImage),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              LabeledIconButton(
                icon: Icons.auto_awesome,
                label: 'OCR Text',
                color: Colors.white,
                onPressed: () {
                  if (widget.images.isNotEmpty) widget.onExtractText(widget.images[_curPage]);
                },
              ),
              LabeledIconButton(
                icon: Icons.compress_rounded,
                label: 'Compress',
                color: Colors.amberAccent,
                onPressed: () {
                  if (widget.images.isNotEmpty) {
                    ProCompressionEngine.showCompressorDialog(
                      context: context,
                      orderedPaths: [widget.images[_curPage]],
                      title: '${widget.title}_p${_curPage + 1}',
                    );
                  }
                },
              ),
              LabeledIconButton(
                icon: Icons.save_alt_rounded,
                label: 'Save JPG',
                color: Colors.tealAccent,
                onPressed: () async {
                  if (widget.images.isNotEmpty) {
                    final cnt = await PhoneStorageManager.saveImagesToPublicGallery([widget.images[_curPage]], widget.title);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $cnt JPG saved to Pictures/BharatScanner!')));
                    }
                  }
                },
              ),
              LabeledIconButton(
                icon: Icons.share_rounded,
                label: 'Share JPG',
                color: Colors.white,
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
// 6. PASSPORT PHOTO STUDIO (DIRECT GALLERY + CAMERA OPTION)
// ============================================================================
class PassportPhotoStudioScreen extends StatefulWidget {
  const PassportPhotoStudioScreen({super.key});
  @override
  State<PassportPhotoStudioScreen> createState() => _PassportPhotoStudioScreenState();
}

class _PassportPhotoStudioScreenState extends State<PassportPhotoStudioScreen> {
  String? _photoPath;
  int _copies = 8;
  String _presetSize = 'Indian Passport (3.5x4.5 cm)';
  String _bgChoice = 'White';

  Future<void> _pickPhotoFromGallery() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) {
      setState(() => _photoPath = x.path);
    }
  }

  Future<void> _scanPhotoCamera() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: 1),
    );
    final res = await scanner.scanDocument();
    if (res.images.isNotEmpty && mounted) {
      setState(() => _photoPath = res.images.first);
    }
  }

  Future<void> _exportPassportSheet() async {
    if (_photoPath == null) return;
    final pdf = pw.Document();
    final imgBytes = await File(_photoPath!).readAsBytes();
    final passImg = pw.MemoryImage(imgBytes);

    double w = 110;
    double h = 145;
    if (_presetSize.contains('US Visa')) {
      w = 140;
      h = 140;
    } else if (_presetSize.contains('PAN Card')) {
      w = 95;
      h = 130;
    } else if (_presetSize.contains('Stamp')) {
      w = 80;
      h = 100;
    }

    PdfColor bgColor = PdfColors.white;
    if (_bgChoice == 'Studio Blue') bgColor = PdfColor.fromInt(0xFFBBDEFB);
    if (_bgChoice == 'Light Grey') bgColor = PdfColor.fromInt(0xFFECEFF1);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Wrap(
            spacing: 16,
            runSpacing: 20,
            children: List.generate(
              _copies,
              (_) => pw.Container(
                width: w,
                height: h,
                color: bgColor,
                padding: const pw.EdgeInsets.all(2),
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                  child: pw.Image(passImg, fit: pw.BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Passport_Sheet_${_copies}_Prints.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Passport Photos Print Sheet');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Studio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: _photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_photoPath!), height: 180, width: 140, fit: BoxFit.cover),
                    )
                  : Container(
                      height: 180,
                      width: 140,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.portrait, size: 60, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('From Gallery'),
                  onPressed: _pickPhotoFromGallery,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera Scan'),
                  onPressed: _scanPhotoCamera,
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _presetSize,
              decoration: const InputDecoration(labelText: 'Standard Photo Size', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Indian Passport (3.5x4.5 cm)', child: Text('Indian Passport (3.5x4.5 cm)')),
                DropdownMenuItem(value: 'PAN Card (2.5x3.5 cm)', child: Text('PAN Card (2.5x3.5 cm)')),
                DropdownMenuItem(value: 'US Visa / OCI (2x2 inch)', child: Text('US Visa / OCI (2x2 inch)')),
                DropdownMenuItem(value: 'Stamp Size (2x2.5 cm)', child: Text('Stamp Size (2x2.5 cm)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _presetSize = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _bgChoice,
              decoration: const InputDecoration(labelText: 'Background Color', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'White', child: Text('Pure White')),
                DropdownMenuItem(value: 'Studio Blue', child: Text('Studio Light Blue')),
                DropdownMenuItem(value: 'Light Grey', child: Text('Light Grey')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _bgChoice = v);
              },
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Number of Copies on A4:', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 8, label: Text('8')),
                ButtonSegment(value: 16, label: Text('16')),
                ButtonSegment(value: 32, label: Text('32')),
              ],
              selected: {_copies},
              onSelectionChanged: (s) => setState(() => _copies = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export Printable A4 Sheet PDF'),
                onPressed: _photoPath == null ? null : _exportPassportSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. DIGITAL SIGNATURE
// ============================================================================
class DigitalSignatureScreen extends StatefulWidget {
  const DigitalSignatureScreen({super.key});
  @override
  State<DigitalSignatureScreen> createState() => _DigitalSignatureScreenState();
}

class _DigitalSignatureScreenState extends State<DigitalSignatureScreen> {
  final List<List<Offset>> _strokes = [];
  Color _inkColor = Colors.black;
  double _strokeWidth = 3.5;

  Future<void> _exportSignaturePng() async {
    if (_strokes.isEmpty) return;

    double minX = 10000, maxX = 0, minY = 10000, maxY = 0;
    for (var stroke in _strokes) {
      for (var p in stroke) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    const pad = 20.0;
    minX = (minX - pad).clamp(0, 5000);
    minY = (minY - pad).clamp(0, 5000);
    final width = (maxX - minX + pad * 2).clamp(60.0, 5000.0);
    final height = (maxY - minY + pad * 2).clamp(60.0, 5000.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.translate(-minX, -minY);

    final paint = Paint()
      ..color = _inkColor
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var stroke in _strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }

    final pic = recorder.endRecording();
    final imgUi = await pic.toImage(width.toInt(), height.toInt());
    final data = await imgUi.toByteData(format: ui.ImageByteFormat.png);

    if (data != null) {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Signature_${DateTime.now().millisecondsSinceEpoch}.png");
      await file.writeAsBytes(data.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My Transparent Signature');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature'),
        actions: [
          LabeledIconButton(
            icon: Icons.undo,
            label: 'Undo',
            onPressed: () {
              if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
            },
          ),
          LabeledIconButton(
            icon: Icons.clear_all,
            label: 'Clear',
            onPressed: () => setState(() => _strokes.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Ink: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ...[Colors.black, const Color(0xFF0D47A1), const Color(0xFFB71C1C), const Color(0xFF1B5E20)].map((c) => GestureDetector(
                  onTap: () => setState(() => _inkColor = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _inkColor == c ? Colors.amber : Colors.transparent, width: 2)),
                  ),
                )),
                const Spacer(),
                const Text('Size: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Slider(
                  value: _strokeWidth,
                  min: 1.5,
                  max: 8.0,
                  onChanged: (v) => setState(() => _strokeWidth = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              child: CustomPaint(
                painter: _SignPainter(_strokes, _inkColor, _strokeWidth),
                size: Size.infinite,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export Transparent PNG Sign'),
                onPressed: _strokes.isEmpty ? null : _exportSignaturePng,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;
  _SignPainter(this.strokes, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// 8. GST TAX INVOICE MAKER
// ============================================================================
class InvoiceMakerProScreen extends StatefulWidget {
  const InvoiceMakerProScreen({super.key});
  @override
  State<InvoiceMakerProScreen> createState() => _InvoiceMakerProScreenState();
}

class _InvoiceMakerProScreenState extends State<InvoiceMakerProScreen> {
  final _sellerCtrl = TextEditingController(text: 'My Business / Shop Name');
  final _clientCtrl = TextEditingController(text: 'Customer / Client Name');
  final _invNumCtrl = TextEditingController(text: 'INV-001');
  final _itemCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  double _gstRate = 0.18;

  final List<Map<String, dynamic>> _items = [
    {'name': 'Professional Consulting', 'price': 1200.0, 'qty': 1},
  ];

  Future<void> _exportInvoicePdf() async {
    final pdf = pw.Document();
    double subtotal = _items.fold(0.0, (s, i) => s + ((i['price'] as double) * (i['qty'] as int)));
    double gstAmount = subtotal * _gstRate;
    double grandTotal = subtotal + gstAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                  pw.Text('Invoice #: ${_invNumCtrl.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text('Seller: ${_sellerCtrl.text}'),
              pw.Text('Billed To: ${_clientCtrl.text}'),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Item / Service', 'Qty', 'Rate (INR)', 'Total (INR)'],
                data: _items
                    .map((it) => [
                          it['name'],
                          '${it['qty']}',
                          '${it['price']}',
                          '${(it['price'] * it['qty']).toStringAsFixed(2)}',
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: INR ${subtotal.toStringAsFixed(2)}'),
                    pw.Text('GST (${(_gstRate * 100).toInt()}%): INR ${gstAmount.toStringAsFixed(2)}'),
                    pw.Divider(),
                    pw.Text('Grand Total: INR ${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
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
    await Share.shareXFiles([XFile(file.path)], text: 'Tax Invoice PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST Tax Invoice Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _sellerCtrl, decoration: const InputDecoration(labelText: 'Seller / Business Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _clientCtrl, decoration: const InputDecoration(labelText: 'Customer / Client Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _invNumCtrl, decoration: const InputDecoration(labelText: 'Invoice Number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: TextField(controller: _itemCtrl, decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(flex: 1, child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()))),
                LabeledIconButton(
                  icon: Icons.add_circle,
                  label: 'Add Item',
                  color: Colors.green,
                  iconSize: 30,
                  onPressed: () {
                    if (_itemCtrl.text.isNotEmpty && _priceCtrl.text.isNotEmpty) {
                      setState(() {
                        _items.add({
                          'name': _itemCtrl.text.trim(),
                          'qty': int.tryParse(_qtyCtrl.text.trim()) ?? 1,
                          'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
                        });
                        _itemCtrl.clear();
                        _priceCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GST Slab Rate:'),
                DropdownButton<double>(
                  value: _gstRate,
                  items: const [
                    DropdownMenuItem(value: 0.0, child: Text('0% Exempt')),
                    DropdownMenuItem(value: 0.05, child: Text('5% GST')),
                    DropdownMenuItem(value: 0.12, child: Text('12% GST')),
                    DropdownMenuItem(value: 0.18, child: Text('18% Standard')),
                    DropdownMenuItem(value: 0.28, child: Text('28% Luxury')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _gstRate = v);
                  },
                ),
              ],
            ),
            const Divider(),
            ..._items.map((it) => ListTile(
                  title: Text(it['name']),
                  subtitle: Text('Qty: ${it['qty']} × INR ${it['price']}'),
                  trailing: Text('INR ${(it['qty'] * it['price']).toStringAsFixed(2)}'),
                )),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export Official Tax Invoice PDF'),
              onPressed: _items.isEmpty ? null : _exportInvoicePdf,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 9. RESUME / CV BUILDER
// ============================================================================
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _name = TextEditingController(text: 'Rahul Sharma');
  final _contact = TextEditingController(text: '+91 98765 43210 | rahul.sharma@email.com | New Delhi');
  final _summary = TextEditingController(text: 'Motivated professional with expertise in operations, documentation, and team leadership.');
  final _experience = TextEditingController(text: '• 3+ Years experience in Team Coordination & IT Documentation.\n• Managed client communications and delivery targets.');
  final _education = TextEditingController(text: '• Bachelor of Science / Graduate (2021)\n• Higher Secondary Certificate (2018)');
  final _skills = TextEditingController(text: 'MS Office, Communication, Team Leadership, Problem Solving');

  Future<void> _exportCv() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_name.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
              pw.Text(_contact.text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 1.5, color: PdfColors.pink),
              pw.SizedBox(height: 8),
              pw.Text('PROFESSIONAL SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_summary.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('WORK EXPERIENCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_experience.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('EDUCATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_education.text, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('KEY SKILLS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text(_skills.text, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Resume_${_name.text.replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Professional Resume');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume / CV Maker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact (Phone, Email, City)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Profile Summary', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _experience, maxLines: 3, decoration: const InputDecoration(labelText: 'Work Experience', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _education, maxLines: 2, decoration: const InputDecoration(labelText: 'Education', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate Resume PDF'),
              onPressed: _exportCv,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 10. POWERPOINT / SLIDES MAKER
// ============================================================================
class PowerPointStudioScreen extends StatefulWidget {
  const PowerPointStudioScreen({super.key});
  @override
  State<PowerPointStudioScreen> createState() => _PowerPointStudioScreenState();
}

class _PowerPointStudioScreenState extends State<PowerPointStudioScreen> {
  final List<Map<String, String>> _slides = [
    {'title': 'Project Overview', 'content': '• Goals and Milestones\n• Target Audience\n• Timeline'},
    {'title': 'Key Execution Steps', 'content': '• Step 1: Research & Discovery\n• Step 2: Implementation\n• Step 3: Launch'},
  ];

  Future<void> _exportDeck() async {
    final pdf = pw.Document();
    for (int i = 0; i < _slides.length; i++) {
      final s = _slides[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.all(36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(s['title'] ?? '', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.pink)),
                    pw.Text('Slide ${i + 1} of ${_slides.length}', style: const pw.TextStyle(color: PdfColors.grey600)),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.pink),
                pw.SizedBox(height: 20),
                pw.Text(s['content'] ?? '', style: const pw.TextStyle(fontSize: 18, lineSpacing: 4)),
              ],
            ),
          ),
        ),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Presentation_Slides.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Presentation Slides');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slides Maker'),
        actions: [LabeledIconButton(icon: Icons.share, label: 'Share PDF', onPressed: _exportDeck)],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _slides.length,
        itemBuilder: (ctx, i) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextFormField(initialValue: _slides[i]['title'], decoration: const InputDecoration(labelText: 'Slide Title'), onChanged: (v) => _slides[i]['title'] = v),
                TextFormField(initialValue: _slides[i]['content'], maxLines: 3, decoration: const InputDecoration(labelText: 'Bullets / Points'), onChanged: (v) => _slides[i]['content'] = v),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: appPrimaryColor.value,
        foregroundColor: Colors.white,
        onPressed: () => setState(() => _slides.add({'title': 'New Slide', 'content': '• Point 1\n• Point 2'})),
        icon: const Icon(Icons.add),
        label: const Text('Add Slide'),
      ),
    );
  }
}

// ============================================================================
// 11. FORMAL LETTER TEMPLATES
// ============================================================================
class LetterTemplatesScreen extends StatefulWidget {
  const LetterTemplatesScreen({super.key});
  @override
  State<LetterTemplatesScreen> createState() => _LetterTemplatesScreenState();
}

class _LetterTemplatesScreenState extends State<LetterTemplatesScreen> {
  final _ctrl = TextEditingController(
    text: "To,\nThe Branch Manager,\nSubject: Application for New Cheque Book\n\nRespected Sir/Madam,\nI hold a savings account in your branch (Account No: XXXXXXXX). I kindly request you to issue a new cheque book for my account.\n\nThanking You,\nYours Sincerely,\n[Your Name]",
  );

  Future<void> _exportLetter() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(36),
          child: pw.Text(_ctrl.text, style: const pw.TextStyle(fontSize: 14, lineSpacing: 4)),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Formal_Letter.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Formal Letter PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letter Maker'),
        actions: [LabeledIconButton(icon: Icons.share, label: 'Share PDF', onPressed: _exportLetter)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Leave Letter'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe HR Manager,\nSubject: Leave Application\n\nRespected Sir/Madam,\nI am writing to formally request 3 days of leave from [Start Date] to [End Date] due to urgent personal reasons.\n\nThank you.\nSincerely,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Resignation'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Management,\nSubject: Notice of Resignation\n\nPlease accept this letter as formal notification that I am resigning from my position as [Designation]. My last working day will be [Date].\n\nRegards,\n[Your Name]"),
                ),
                ActionChip(
                  label: const Text('Bank Manager'),
                  onPressed: () => setState(() => _ctrl.text = "To,\nThe Branch Manager,\nSubject: Request to Update Phone Number\n\nRespected Sir,\nKindly update my mobile number [New Number] in my bank account [Account No].\n\nThanking you,\n[Your Name]"),
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

// ============================================================================
// 12. TXT & NOTES STUDIO
// ============================================================================
class TxtEditorNotesScreen extends StatefulWidget {
  const TxtEditorNotesScreen({super.key});
  @override
  State<TxtEditorNotesScreen> createState() => _TxtEditorNotesScreenState();
}

class _TxtEditorNotesScreenState extends State<TxtEditorNotesScreen> {
  final _titleCtrl = TextEditingController(text: 'Quick Note');
  final _bodyCtrl = TextEditingController();

  Future<void> _exportTxt() async {
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${_titleCtrl.text.replaceAll(' ', '_')}.txt");
    await file.writeAsString(_bodyCtrl.text);
    await Share.shareXFiles([XFile(file.path)], text: 'Exported Note');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes & TXT Studio'),
        actions: [LabeledIconButton(icon: Icons.share, label: 'Share TXT', onPressed: _exportTxt)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Expanded(child: TextField(controller: _bodyCtrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Start writing notes...', border: OutlineInputBorder()))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 13. PDF MERGE STUDIO (PRESERVES SELECTION ORDER)
// ============================================================================
class PdfStudioScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  const PdfStudioScreen({super.key, required this.savedDocs});
  @override
  State<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends State<PdfStudioScreen> {
  final List<String> _selectedIdsOrder = [];

  Future<void> _mergeDocs({required bool saveToPhone}) async {
    if (_selectedIdsOrder.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 documents to merge!')));
      return;
    }
    final pdf = pw.Document();
    for (var id in _selectedIdsOrder) {
      final doc = widget.savedDocs.firstWhere((d) => d['id'] == id);
      final imgs = doc['images'] as List;
      for (var p in imgs) {
        final f = File(p);
        if (await f.exists()) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (ctx) => pw.Center(child: pw.Image(pw.MemoryImage(f.readAsBytesSync()), fit: pw.BoxFit.contain)),
            ),
          );
        }
      }
    }
    final pdfBytes = await pdf.save();
    if (saveToPhone) {
      final saved = await PhoneStorageManager.savePdfBytesToPublicDownloads(pdfBytes, 'Merged_${_selectedIdsOrder.length}_Docs');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(saved != null ? '✅ Merged PDF saved to Download/BharatScanner!' : '❌ Failed to save')),
        );
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Merged_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Merged PDF Document');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge Documents (Ordered)')),
      body: ListView.builder(
        itemCount: widget.savedDocs.length,
        itemBuilder: (ctx, i) {
          final doc = widget.savedDocs[i];
          final orderIdx = _selectedIdsOrder.indexOf(doc['id']);
          final isSel = orderIdx != -1;
          return CheckboxListTile(
            value: isSel,
            secondary: isSel
                ? CircleAvatar(
                    radius: 13,
                    backgroundColor: appPrimaryColor.value,
                    child: Text('#${orderIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                : null,
            title: Text(doc['title']),
            subtitle: Text('${doc['pages']} pages'),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedIdsOrder.add(doc['id']);
                } else {
                  _selectedIdsOrder.remove(doc['id']);
                }
              });
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.download_for_offline_rounded),
                  label: Text('Save PDF (${_selectedIdsOrder.length})'),
                  onPressed: () => _mergeDocs(saveToPhone: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text('Share PDF (${_selectedIdsOrder.length})'),
                  onPressed: () => _mergeDocs(saveToPhone: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 14. WATERMARK STUDIO
// ============================================================================
class WatermarkToolScreen extends StatefulWidget {
  final List<Map<String, dynamic>> savedDocs;
  const WatermarkToolScreen({super.key, required this.savedDocs});
  @override
  State<WatermarkToolScreen> createState() => _WatermarkToolScreenState();
}

class _WatermarkToolScreenState extends State<WatermarkToolScreen> {
  final _wmCtrl = TextEditingController(text: 'CONFIDENTIAL');
  String? _selectedDocId;

  Future<void> _exportWatermarkedPdf() async {
    if (_selectedDocId == null) return;
    final doc = widget.savedDocs.firstWhere((d) => d['id'] == _selectedDocId);
    final imgs = doc['images'] as List;

    final pdf = pw.Document();
    for (var path in imgs) {
      final f = File(path);
      if (await f.exists()) {
        final imgMem = pw.MemoryImage(await f.readAsBytes());
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.Stack(
              children: [
                pw.Center(child: pw.Image(imgMem, fit: pw.BoxFit.contain)),
                pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.6,
                    child: pw.Text(
                      _wmCtrl.text,
                      style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0x35000000)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/${doc['title']}_Watermarked.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Watermarked PDF');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add PDF Watermark')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedDocId,
              hint: const Text('Choose Document'),
              items: widget.savedDocs.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['title']))).toList(),
              onChanged: (v) => setState(() => _selectedDocId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _wmCtrl, decoration: const InputDecoration(labelText: 'Watermark Stamp Text', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.branding_watermark_outlined),
              label: const Text('Apply Stamp & Share PDF'),
              onPressed: _selectedDocId == null ? null : _exportWatermarkedPdf,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 15. UNIVERSAL PHOTO ROTATE (WITH DIRECT GALLERY + LABELED BUTTONS)
// ============================================================================
class UniversalImageToolScreen extends StatefulWidget {
  const UniversalImageToolScreen({super.key});
  @override
  State<UniversalImageToolScreen> createState() => _UniversalImageToolScreenState();
}

class _UniversalImageToolScreenState extends State<UniversalImageToolScreen> {
  String? _imgPath;

  Future<void> _pickImageGallery() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) {
      setState(() => _imgPath = x.path);
    }
  }

  Future<void> _pickImageCamera() async {
    final scanner = DocumentScanner(options: DocumentScannerOptions(documentFormat: DocumentFormat.jpeg, mode: ScannerMode.base, isGalleryImport: true, pageLimit: 1));
    final res = await scanner.scanDocument();
    if (res.images.isNotEmpty && mounted) {
      setState(() => _imgPath = res.images.first);
    }
  }

  Future<void> _rotate90() async {
    if (_imgPath == null) return;
    final bytes = await File(_imgPath!).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imgUi = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgUi.height.toDouble(), imgUi.width.toDouble()));
    canvas.translate(imgUi.height.toDouble() / 2, imgUi.width.toDouble() / 2);
    canvas.rotate(1.5708);
    canvas.drawImage(imgUi, Offset(-imgUi.width.toDouble() / 2, -imgUi.height.toDouble() / 2), Paint());

    final outImg = await recorder.endRecording().toImage(imgUi.height, imgUi.width);
    final data = await outImg.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final f = File('${appDir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(data.buffer.asUint8List());
      setState(() => _imgPath = f.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Rotate Studio'),
        actions: [
          if (_imgPath != null) LabeledIconButton(icon: Icons.rotate_right, label: 'Rotate 90°', onPressed: _rotate90),
          if (_imgPath != null)
            LabeledIconButton(
              icon: Icons.save_alt_rounded,
              label: 'Save JPG',
              onPressed: () async {
                final c = await PhoneStorageManager.saveImagesToPublicGallery([_imgPath!], 'Rotated_Photo');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $c photo saved to Gallery!')));
              },
            ),
          if (_imgPath != null) LabeledIconButton(icon: Icons.share, label: 'Share', onPressed: () => Share.shareXFiles([XFile(_imgPath!)])),
        ],
      ),
      body: Center(
        child: _imgPath == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(icon: const Icon(Icons.photo_library_rounded), label: const Text('Select Photo from Gallery'), onPressed: _pickImageGallery),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(icon: const Icon(Icons.camera_alt_rounded), label: const Text('Scan Photo from Camera'), onPressed: _pickImageCamera),
                ],
              )
            : Image.file(File(_imgPath!)),
      ),
    );
  }
}

// ============================================================================
// 16. QR & BARCODE GENERATOR STUDIO
// ============================================================================
class QrBarcodeStudioScreen extends StatefulWidget {
  const QrBarcodeStudioScreen({super.key});
  @override
  State<QrBarcodeStudioScreen> createState() => _QrBarcodeStudioScreenState();
}

class _QrBarcodeStudioScreenState extends State<QrBarcodeStudioScreen> {
  final _qrTextCtrl = TextEditingController(text: 'https://bharatdocscanner.app');

  Future<void> _shareQrCode() async {
    final text = _qrTextCtrl.text.trim();
    if (text.isEmpty) return;
    await Share.share('QR Data: $text');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR & Barcode Studio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _qrTextCtrl, decoration: const InputDecoration(labelText: 'Enter Text / URL for QR', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
              child: const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor.value, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.share),
              label: const Text('Share QR Data'),
              onPressed: _shareQrCode,
            ),
          ],
        ),
      ),
    );
  }
}
