import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class ShareUtils {
  static Future<void> shareRecipe(Map<String, dynamic> receta) async {
    final titulo = receta['titulo']?.toString() ??
        receta['nombre']?.toString() ??
        'Receta sin nombre';

    final descripcion = receta['descripcion']?.toString() ?? '';

    final ingredientes = receta['ingredientes'] is List
        ? (receta['ingredientes'] as List).map((i) => '• $i').join('\n')
        : receta['ingredientes']?.toString() ?? '';

    final preparacion = receta['preparacion'] is List
        ? (receta['preparacion'] as List).asMap().entries.map((e) =>
            '${e.key + 1}. ${e.value}').join('\n')
        : receta['preparacion']?.toString() ?? '';

    final mensaje = '''
🍽️ *$titulo*

📝 $descripcion

🥘 Ingredientes:
$ingredientes

👩‍🍳 Preparación:
$preparacion

--- 
Compartido desde RecetIAs 🍳
''';

    // ==========================================================
    // INTENTAR COMPARTIR CON FOTO
    // ==========================================================

    final fotoUrl = receta['fotoPlatilloUrl']?.toString() ?? '';

    if (fotoUrl.isNotEmpty) {
      try {
        // Descargar la imagen
        final response = await http.get(Uri.parse(fotoUrl));
        if (response.statusCode == 200) {
          // Guardar en archivo temporal
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/receta_compartir.jpg';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          // Compartir con foto
          await Share.shareXFiles(
            [XFile(filePath)],
            text: mensaje,
          );
          return;
        } else {
          debugPrint('Error al descargar foto: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error al compartir foto: $e');
        // Si falla, continuar con solo texto
      }
    }

    // Si no hay foto o falló, compartir solo texto
    await Share.share(mensaje);
  }
}