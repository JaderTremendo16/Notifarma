import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'pdf_downloader_stub.dart'
    if (dart.library.html) 'pdf_downloader_web.dart' as platform_downloader;

class PdfDownloader {
  /// Descarga directamente el archivo binario PDF en Web (creando un anchor download)
  /// o guarda el archivo binario en el almacenamiento del dispositivo y lo abre
  /// con la aplicación nativa predeterminada para PDFs (Adobe Reader, Drive Viewer, etc.).
  static Future<bool> downloadPdfBytes(List<int> bytes, String filename) async {
    try {
      if (kIsWeb) {
        return platform_downloader.savePdfFileWeb(bytes, filename);
      } else {
        // En Android, iOS o Desktop: guardar el archivo en el directorio de documentos/temporales
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);

        // Abrir directamente con el visor nativo del dispositivo
        final result = await OpenFilex.open(filePath);
        return result.type == ResultType.done;
      }
    } catch (_) {
      return false;
    }
  }
}
