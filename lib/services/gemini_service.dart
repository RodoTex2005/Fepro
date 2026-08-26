import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '/prompts/ingredient_recognition_prompt.dart';

/// Resultado del reconocimiento de ingredientes:
/// - ingredientes: lista de nombres detectados (puede incluir "(Posible)")
/// - mensaje: pregunta de confirmación para mostrar al usuario
class IngredientRecognitionResult {
  final List<String> ingredientes;
  final String mensaje;

  IngredientRecognitionResult({
    required this.ingredientes,
    required this.mensaje,
  });
}

class GeminiService {
  static const String _modelName = 'gemini-3.6-flash';

  GenerativeModel _buildModel({String modelName = _modelName}) {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY no está configurada. Revisa tu archivo .env en la raíz del proyecto.',
      );
    }

    return GenerativeModel(model: modelName, apiKey: apiKey);
  }

  /// Determina el tipo MIME del archivo de imagen
  String _getMimeType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Envía la imagen + el prompt de reconocimiento a Gemini
  /// y devuelve la lista de ingredientes detectados ya parseada.
  Future<IngredientRecognitionResult> recognizeIngredients(
    File imageFile,
  ) async {
    final imageBytes = await imageFile.readAsBytes();
    final mimeType = _getMimeType(imageFile.path);

    debugPrint('📸 Enviando imagen (${imageBytes.length} bytes, $mimeType) a Gemini ($_modelName)...');

    final content = [
      Content.multi([
        TextPart(ingredientRecognitionPrompt),
        DataPart(mimeType, imageBytes),
      ]),
    ];

    final model = _buildModel(modelName: _modelName);
    final response = await model.generateContent(content);
    final rawText = response.text ?? '';

    debugPrint('🤖 Respuesta de Gemini: $rawText');

    return _parseResponse(rawText);
  }

  /// Limpia y parsea la respuesta de Gemini a un objeto Dart.
  /// Sigue la misma estrategia de limpieza de markdown que usa
  /// el servicio de DeepSeek, para mantener consistencia en el proyecto.
  IngredientRecognitionResult _parseResponse(String rawText) {
    String cleanResponse = rawText.trim();

    cleanResponse = cleanResponse
        .replaceAll('```json', '')
        .replaceAll('```JSON', '')
        .replaceAll('```', '')
        .trim();

    final firstBrace = cleanResponse.indexOf('{');
    final lastBrace = cleanResponse.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1) {
      cleanResponse = cleanResponse.substring(firstBrace, lastBrace + 1).trim();
    }

    try {
      final data = jsonDecode(cleanResponse);

      if (data is Map<String, dynamic>) {
        final ingredientes = data['ingredientes'] is List
            ? List<String>.from(data['ingredientes'].map((e) => e.toString()))
            : <String>[];

        final mensaje =
            data['mensaje']?.toString() ??
            '¿Los ingredientes detectados son correctos?';

        return IngredientRecognitionResult(
          ingredientes: ingredientes,
          mensaje: mensaje,
        );
      }
    } catch (_) {
      // Si el JSON no se pudo parsear, cae al resultado de error de abajo.
    }

    return IngredientRecognitionResult(
      ingredientes: [],
      mensaje:
          'No se pudieron reconocer los ingredientes. Intenta con otra foto.',
    );
  }
}
