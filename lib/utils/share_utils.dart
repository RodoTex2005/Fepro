// lib/utils/share_utils.dart
import 'package:share_plus/share_plus.dart';

class ShareUtils {
  static void shareRecipe(Map<String, dynamic> receta) {
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
Compartido desde Fepro 🍳
''';

    Share.share(mensaje);
  }
}