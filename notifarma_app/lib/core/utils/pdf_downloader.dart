import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pdf_downloader_stub.dart'
    if (dart.library.html) 'pdf_downloader_web.dart' as platform_downloader;

class PdfDownloader {
  /// Descarga directamente el archivo binario PDF en Web (creando anchor download)
  /// o lanza la apertura segura en mobile/desktop sin ventanas en blanco.
  static Future<bool> downloadPdfBytes(List<int> bytes, String filename) async {
    try {
      if (kIsWeb) {
        return platform_downloader.savePdfFileWeb(bytes, filename);
      } else {
        final base64String = base64Encode(bytes);
        final dataUri = Uri.parse('data:application/pdf;base64,$base64String');
        return await launchUrl(
          dataUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      return false;
    }
  }
}
