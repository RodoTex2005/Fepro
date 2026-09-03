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

  // Número máximo de intentos cuando ocurre un error temporal.
  static const int _maxAttempts = 3;

  GenerativeModel _buildModel({String modelName = _modelName}) {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY no está configurada. '
        'Revisa tu archivo .env en la raíz del proyecto.',
      );
    }

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );
  }

  /// Determina el tipo MIME del archivo de imagen.
  String _getMimeType(String filePath) {
    final lower = filePath.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  /// Envía la imagen + el prompt de reconocimiento a Gemini
  /// y devuelve la lista de ingredientes detectados ya parseada.
  Future<IngredientRecognitionResult> recognizeIngredients(
    File imageFile,
  ) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final mimeType = _getMimeType(imageFile.path);

      debugPrint(
        '📸 Enviando imagen '
        '(${imageBytes.length} bytes, $mimeType) '
        'a Gemini ($_modelName)...',
      );

      final content = [
        Content.multi([
          TextPart(ingredientRecognitionPrompt),
          DataPart(mimeType, imageBytes),
        ]),
      ];

      final model = _buildModel(
        modelName: _modelName,
      );

      // Se utiliza el método con reintentos.
      final response = await _generateWithRetry(
        model,
        content,
      );

      final rawText = response.text ?? '';

      debugPrint('🤖 Respuesta de Gemini: $rawText');

      return _parseResponse(rawText);
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Error al reconocer ingredientes con Gemini: $e',
      );

      debugPrint(
        'StackTrace: $stackTrace',
      );

      return IngredientRecognitionResult(
        ingredientes: [],
        mensaje:
            'No se pudieron reconocer los ingredientes en este momento. '
            'Intenta nuevamente en unos segundos.',
      );
    }
  }

  /// Ejecuta la petición a Gemini con reintentos automáticos.
  ///
  /// Esto ayuda cuando Gemini devuelve errores temporales como:
  /// - 503 UNAVAILABLE
  /// - 429 RESOURCE EXHAUSTED
  ///
  /// Los tiempos de espera son:
  /// - Intento 1 → si falla, espera 2 segundos.
  /// - Intento 2 → si falla, espera 4 segundos.
  /// - Intento 3 → si falla, devuelve el error.
  Future<GenerateContentResponse> _generateWithRetry(
    GenerativeModel model,
    List<Content> content,
  ) async {
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        debugPrint(
          '🤖 Intento $attempt/$_maxAttempts con Gemini...',
        );

        final response = await model.generateContent(content);

        debugPrint(
          '✅ Gemini respondió correctamente en el intento $attempt.',
        );

        return response;
      } catch (e) {
        debugPrint(
          '⚠️ Gemini falló en el intento $attempt: $e',
        );

        final shouldRetry = _isTemporaryError(e);

        // Si no es un error temporal, no tiene sentido
        // volver a mandar la misma petición.
        if (!shouldRetry) {
          debugPrint(
            '🛑 El error no parece temporal. '
            'No se realizará otro intento.',
          );

          rethrow;
        }

        // Si ya llegamos al último intento, devolvemos el error.
        if (attempt == _maxAttempts) {
          debugPrint(
            '❌ Se alcanzó el máximo de $_maxAttempts intentos.',
          );

          rethrow;
        }

        // Espera progresiva:
        // intento 1 → 2 segundos
        // intento 2 → 4 segundos
        final seconds = attempt * 2;

        debugPrint(
          '⏳ Gemini está temporalmente no disponible. '
          'Reintentando en $seconds segundos...',
        );

        await Future.delayed(
          Duration(seconds: seconds),
        );
      }
    }

    // Este punto realmente no debería alcanzarse,
    // pero Dart necesita que el método tenga un retorno.
    throw Exception(
      'No se pudo obtener respuesta de Gemini.',
    );
  }

  /// Determina si el error probablemente sea temporal
  /// y por lo tanto vale la pena volver a intentar.
  bool _isTemporaryError(Object error) {
    final errorString = error.toString().toLowerCase();

    // 503:
    // El servidor/modelo está temporalmente no disponible.
    if (errorString.contains('503') ||
        errorString.contains('unavailable') ||
        errorString.contains('service unavailable')) {
      return true;
    }

    // 429:
    // Demasiadas solicitudes / límite temporal.
    if (errorString.contains('429') ||
        errorString.contains('resource exhausted') ||
        errorString.contains('too many requests')) {
      return true;
    }

    // Errores temporales relacionados con disponibilidad.
    if (errorString.contains('temporarily') ||
        errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return true;
    }

    return false;
  }

  /// Limpia y parsea la respuesta de Gemini a un objeto Dart.
  ///
  /// Sigue la misma estrategia de limpieza de markdown que usa
  /// el servicio de DeepSeek, para mantener consistencia en el proyecto.
  IngredientRecognitionResult _parseResponse(String rawText) {
    String cleanResponse = rawText.trim();

    debugPrint(
      '🧹 Procesando respuesta de Gemini...',
    );

    cleanResponse = cleanResponse
        .replaceAll('```json', '')
        .replaceAll('```JSON', '')
        .replaceAll('```', '')
        .trim();

    final firstBrace = cleanResponse.indexOf('{');
    final lastBrace = cleanResponse.lastIndexOf('}');

    if (firstBrace != -1 &&
        lastBrace != -1 &&
        lastBrace > firstBrace) {
      cleanResponse = cleanResponse
          .substring(firstBrace, lastBrace + 1)
          .trim();
    }

    try {
      final data = jsonDecode(cleanResponse);

      if (data is Map<String, dynamic>) {
        final ingredientes = data['ingredientes'] is List
            ? List<String>.from(
                data['ingredientes'].map(
                  (e) => e.toString(),
                ),
              )
            : <String>[];

        final mensaje =
            data['mensaje']?.toString() ??
            '¿Los ingredientes detectados son correctos?';

        debugPrint(
          '✅ JSON de ingredientes procesado correctamente.',
        );

        debugPrint(
          '🥕 Ingredientes detectados: $ingredientes',
        );

        return IngredientRecognitionResult(
          ingredientes: ingredientes,
          mensaje: mensaje,
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Error al procesar JSON de Gemini: $e',
      );

      debugPrint(
        '📄 Respuesta procesada: $cleanResponse',
      );
    }

    return IngredientRecognitionResult(
      ingredientes: [],
      mensaje:
          'No se pudieron reconocer los ingredientes. '
          'Intenta con otra foto.',
    );
  }
}