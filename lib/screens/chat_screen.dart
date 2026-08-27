import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'step_by_step_screen.dart';
import '/services/deepseek_service.dart';
import '/services/gemini_service.dart';

import '/prompts/amelia_prompt.dart';
import '/prompts/engine_prompt.dart';
import '/prompts/recipe_prompt.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ============================================================
  // SERVICIOS
  // ============================================================

  final DeepSeekService _deepSeekService = DeepSeekService();
  final GeminiService _geminiService = GeminiService();
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // VARIABLES DEL CHAT
  // ============================================================

  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> messages = [];

  bool _isLoading = false;
  String _loadingText = 'Amelia está pensando...';

  // ============================================================
  // INICIO
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addWelcomeMessage();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textFieldFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // MENSAJE DE BIENVENIDA
  // ============================================================

  void _addWelcomeMessage() {
    setState(() {
      messages.add({
        'text':
            '¡Hola! 👋 Soy Amelia, tu asistente de cocina. ¿Qué vamos a preparar hoy? Puedes escribirme o enviarme una foto de tus ingredientes con la cámara o galería. 🍳📸',
        'isUser': false,
        'time': _getCurrentTime(),
      });
    });

    _scrollToBottom();
  }

  // ============================================================
  // ENVIAR MENSAJE A DEEPSEEK
  // ============================================================

  Future<void> _sendMessage({String? customText}) async {
    final text = (customText ?? _controller.text).trim();

    if (text.isEmpty || _isLoading) return;

    setState(() {
      messages.add({
        'text': text,
        'isUser': true,
        'time': _getCurrentTime(),
      });

      _isLoading = true;
      _loadingText = 'Amelia está pensando...';
    });

    if (customText == null) {
      _controller.clear();
    }

    _scrollToBottom();

    try {
      // ============================================================
      // PREPARAR PROMPTS E HISTORIAL DEL CHAT
      // ============================================================

      final List<Map<String, String>> promptMessages = [
        {
          'role': 'system',
          'content': ameliaPrompt,
        },
        {
          'role': 'system',
          'content': enginePrompt,
        },
        {
          'role': 'system',
          'content': recipePrompt,
        },
      ];

      for (final msg in messages) {
        final msgText = msg['text'] as String?;
        final isUser = msg['isUser'] as bool? ?? false;

        if (msgText != null &&
            msgText.isNotEmpty &&
            msg['isRecipe'] != true) {
          promptMessages.add({
            'role': isUser ? 'user' : 'assistant',
            'content': msgText,
          });
        }
      }

      // ============================================================
      // ENVIAR MENSAJE A DEEPSEEK
      // ============================================================

      final response = await _deepSeekService.sendMessage(
        messages: promptMessages,
      );

      debugPrint('========== RESPUESTA DE DEEPSEEK ==========');
      debugPrint(response);
      debugPrint('============================================');

      // ============================================================
      // LIMPIAR POSIBLES BLOQUES DE MARKDOWN
      // ============================================================

      String cleanResponse = response.trim();

      cleanResponse = cleanResponse
          .replaceAll('```json', '')
          .replaceAll('```JSON', '')
          .replaceAll('```', '')
          .trim();

      // ============================================================
      // ENCONTRAR EL JSON
      // ============================================================

      final firstBrace = cleanResponse.indexOf('{');
      final lastBrace = cleanResponse.lastIndexOf('}');

      if (firstBrace != -1 && lastBrace != -1) {
        cleanResponse =
            cleanResponse.substring(firstBrace, lastBrace + 1).trim();
      }

      debugPrint('========== JSON LIMPIO ==========');
      debugPrint(cleanResponse);
      debugPrint('=================================');

      // ============================================================
      // INTENTAR CONVERTIR A JSON
      // ============================================================

      dynamic data;

      try {
        data = jsonDecode(cleanResponse);
      } catch (e) {
        debugPrint('ERROR JSON: $e');
        data = null;
      }

      // ============================================================
      // SI ES UNA RECETA
      // ============================================================

      if (data is Map<String, dynamic> &&
          data['type']?.toString().toLowerCase() == 'recipe') {
        final recipe = {
          'type': 'recipe',
          'name': data['name']?.toString() ?? 'Receta de Amelia',
          'description': data['description']?.toString() ?? '',
          'servings': data['servings'],
          'time': data['time']?.toString() ?? '',
          'difficulty': data['difficulty']?.toString() ?? '',
          'ingredients': data['ingredients'] is List
              ? List<String>.from(
                  data['ingredients'].map(
                    (e) => e.toString(),
                  ),
                )
              : <String>[],
          'optionalIngredients': data['optionalIngredients'] is List
              ? List<String>.from(
                  data['optionalIngredients'].map(
                    (e) => e.toString(),
                  ),
                )
              : <String>[],
          'preparation': data['preparation'] is List
              ? List<String>.from(
                  data['preparation'].map(
                    (e) => e.toString(),
                  ),
                )
              : <String>[],
          'advice': data['advice']?.toString() ?? '',
          'finalMessage': data['finalMessage']?.toString() ?? '',
        };

        debugPrint('========== RECETA DETECTADA ==========');
        debugPrint(recipe.toString());
        debugPrint('======================================');

        // ============================================================
        // GUARDAR RECETA GENERADA EN FIRESTORE
        // ============================================================

        final recetaId = await _registerGeneratedRecipe(recipe);

        if (recetaId == null) {
          debugPrint(
            '⚠️ No se pudo obtener el ID de la receta.',
          );
        } else {
          debugPrint(
            'ID DIRECTO DE LA RECETA: $recetaId',
          );
        }

        // ============================================================
        // ASOCIAR ID A LA RECETA
        // ============================================================

        recipe['recetaId'] = recetaId;

        debugPrint(
          'Receta preparada para el botón Guardar con ID: '
          '${recipe['recetaId']}',
        );

        // ============================================================
        // MOSTRAR RECETA EN EL CHAT
        // ============================================================

        setState(() {
          if ((recipe['finalMessage'] as String).isNotEmpty) {
            messages.add({
              'text': recipe['finalMessage'],
              'isUser': false,
              'time': _getCurrentTime(),
            });
          }

          messages.add({
            'text': '',
            'isUser': false,
            'isRecipe': true,
            'time': _getCurrentTime(),
            'recipeData': recipe,
          });
        });
      } else {
        // ============================================================
        // NO ES RECETA
        // ============================================================

        debugPrint(
          'La respuesta NO fue reconocida como receta.',
        );

        setState(() {
          messages.add({
            'text': response,
            'isUser': false,
            'time': _getCurrentTime(),
          });
        });
      }
    } catch (e) {
      debugPrint(
        'Error al procesar respuesta: $e',
      );

      setState(() {
        messages.add({
          'text':
              'Lo siento, tuve un pequeño problema al preparar la respuesta. 😅 '
              '¿Podemos intentarlo de nuevo?',
          'isUser': false,
          'time': _getCurrentTime(),
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  // ============================================================
  // MODO COCINAR
  // ============================================================

  void _goToCookingMode(Map<String, dynamic> recipe) {
    final recipeName = recipe['name'] ?? 'Receta';

    final ingredients = List<String>.from(
      recipe['ingredients'] ?? [],
    );

    final instructions =
        List<String>.from(
          recipe['preparation'] ?? [],
        ).join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepByStepScreen(
          recipeName: recipeName,
          ingredients: ingredients,
          instructions: instructions,
        ),
      ),
    );
  }

  // ============================================================
  // REGISTRAR RECETA GENERADA
  // ============================================================

  Future<String?> _registerGeneratedRecipe(
    Map<String, dynamic> recipe,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          'No hay usuario autenticado. No se guardará la receta.',
        );
        return null;
      }

      // ============================================================
      // COLECCIÓN: recetas
      // ============================================================

      final recetaRef =
          await FirebaseFirestore.instance.collection('recetas').add({
        'uid': user.uid,
        'nombre': recipe['name'] ?? 'Receta de Amelia',
        'descripcion': recipe['description'] ?? '',
        'servings': recipe['servings'],
        'time': recipe['time'] ?? '',
        'difficulty': recipe['difficulty'] ?? '',
        'ingredients': List<String>.from(
          recipe['ingredients'] ?? [],
        ),
        'optionalIngredients': List<String>.from(
          recipe['optionalIngredients'] ?? [],
        ),
        'preparation': List<String>.from(
          recipe['preparation'] ?? [],
        ),
        'advice': recipe['advice'] ?? '',
        'finalMessage': recipe['finalMessage'] ?? '',
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'Receta guardada correctamente en Firestore: ${recetaRef.id}',
      );

      // ============================================================
      // ACTUALIZAR CONTADOR DEL USUARIO
      // ============================================================

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'recetasGeneradas': FieldValue.increment(1),
      });

      debugPrint(
        'Contador recetasGeneradas actualizado.',
      );

      return recetaRef.id;
    } catch (e) {
      debugPrint(
        'ERROR AL GUARDAR RECETA GENERADA: $e',
      );

      return null;
    }
  }

  // ============================================================
  // GUARDAR RECETA EN FAVORITOS
  // ============================================================

  Future<void> _saveRecipe(
    Map<String, dynamic> recipe,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          'No hay usuario autenticado.',
        );
        return;
      }

      // ============================================================
      // OBTENER ID DIRECTO DE LA RECETA
      // ============================================================

      final recetaId = recipe['recetaId'];

      if (recetaId == null ||
          recetaId.toString().isEmpty) {
        debugPrint(
          'ERROR: La receta no tiene recetaId.',
        );
        return;
      }

      debugPrint(
        'Guardando receta con ID directo: $recetaId',
      );

      // ============================================================
      // COMPROBAR SI YA ESTÁ GUARDADA
      // ============================================================

      final guardadaQuery = await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .where(
            'uid',
            isEqualTo: user.uid,
          )
          .where(
            'recetaId',
            isEqualTo: recetaId,
          )
          .limit(1)
          .get();

      if (guardadaQuery.docs.isNotEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Esta receta ya está en favoritos',
            ),
            backgroundColor: Color(0xFFF39C12),
          ),
        );

        return;
      }

      // ============================================================
      // GUARDAR RELACIÓN USUARIO → RECETA
      // ============================================================

      await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .add({
        'uid': user.uid,
        'recetaId': recetaId,
        'fechaGuardado': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'Receta guardada en favoritos correctamente.',
      );

      // ============================================================
      // ACTUALIZAR CONTADOR DEL USUARIO
      // ============================================================

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'recetasGuardadas': FieldValue.increment(1),
      });

      debugPrint(
        'Contador recetasGuardadas actualizado.',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❤️ Receta guardada en favoritos',
          ),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL GUARDAR RECETA EN FAVORITOS: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo guardar la receta: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // HORA ACTUAL
  // ============================================================

  String _getCurrentTime() {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CÁMARA, GALERÍA Y RECONOCIMIENTO CON GEMINI
  // ============================================================

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    if (_isLoading) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (picked == null) return;

      final File imageFile = File(picked.path);

      setState(() {
        messages.add({
          'text': '📷 Foto de ingredientes',
          'image': imageFile,
          'isUser': true,
          'time': _getCurrentTime(),
        });

        _isLoading = true;
        _loadingText =
            'Amelia y Gemini están reconociendo los ingredientes...';
      });

      _scrollToBottom();

      final result =
          await _geminiService.recognizeIngredients(imageFile);

      if (!mounted) return;

      if (result.ingredientes.isNotEmpty) {
        final ingredientsList =
            result.ingredientes.map((i) => '• $i').join('\n');

        final ameliaResponse =
            '¡He analizado tu foto con Gemini! 🔍✨\n\n'
            'Detecté estos ingredientes:\n'
            '$ingredientsList\n\n'
            '${result.mensaje} ¿Quieres que preparemos una receta con ellos?';

        setState(() {
          messages.add({
            'text': ameliaResponse,
            'isUser': false,
            'time': _getCurrentTime(),
            'detectedIngredients': result.ingredientes,
            'actionTaken': false,
          });
        });
      } else {
        setState(() {
          messages.add({
            'text': result.mensaje.isNotEmpty
                ? result.mensaje
                : 'No pude reconocer ingredientes con claridad en la imagen. '
                    'Intenta con otra foto con mejor iluminación o ángulo. 📷',
            'isUser': false,
            'time': _getCurrentTime(),
          });
        });
      }
    } catch (e, stack) {
      debugPrint(
        'Error al reconocer ingredientes con Gemini: $e',
      );

      debugPrint(
        'StackTrace: $stack',
      );

      if (!mounted) return;

      String errorMsg =
          'Hubo un inconveniente al procesar la imagen: $e';

      if (e.toString().contains('GEMINI_API_KEY')) {
        errorMsg =
            '⚠️ GEMINI_API_KEY no está configurada en el archivo .env. '
            'Por favor revísala.';
      }

      setState(() {
        messages.add({
          'text': errorMsg,
          'isUser': false,
          'time': _getCurrentTime(),
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  void _openCamera() {
    _pickImage(ImageSource.camera);
  }

  void _openGallery() {
    _pickImage(ImageSource.gallery);
  }

  // ============================================================
  // CONFIRMAR INGREDIENTES DETECTADOS
  // ============================================================

  void _handleConfirmIngredients(
    Map<String, dynamic> msg,
  ) {
    if (msg['actionTaken'] == true) return;

    setState(() {
      msg['actionTaken'] = true;
    });

    _sendMessage(
      customText:
          'Sí, los ingredientes detectados son correctos. '
          'Por favor, prepárame una receta deliciosa con ellos.',
    );
  }

  // ============================================================
  // EDITAR INGREDIENTES DETECTADOS
  // ============================================================

  void _handleEditIngredients(
    Map<String, dynamic> msg,
  ) {
    if (msg['actionTaken'] == true) return;

    setState(() {
      msg['actionTaken'] = true;
    });

    final detected = msg['detectedIngredients'] != null
        ? List<String>.from(
            msg['detectedIngredients'],
          )
        : <String>[];

    final ingredientesStr = detected.join(', ');

    final prefix = ingredientesStr.isNotEmpty
        ? 'Los ingredientes que tengo son: '
            '$ingredientesStr, y también quiero agregar: '
        : 'Además de esos ingredientes, también quiero agregar: ';

    const suffix =
        '. Por favor, prepárame una receta deliciosa con todos ellos.';

    _controller.text = prefix + suffix;

    _controller.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset: prefix.length,
      ),
    );

    _textFieldFocusNode.requestFocus();
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  messages.length +
                  (_isLoading ? 2 : 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const SizedBox(
                    height: 40,
                  );
                }

                if (_isLoading &&
                    index == messages.length + 1) {
                  return _TypingBubble(
                    text: _loadingText,
                  );
                }

                final msgIndex = index - 1;

                if (msgIndex >= messages.length) {
                  return const SizedBox.shrink();
                }

                final msg = messages[msgIndex];

                final isRecipe =
                    msg['isRecipe'] ?? false;

                if (isRecipe) {
                  return _RecipeBubble(
                    recipeData: msg['recipeData'],
                    onCook: () => _goToCookingMode(
                      msg['recipeData'],
                    ),
                    onSave: () => _saveRecipe(
                      msg['recipeData'],
                    ),
                    time: msg['time'],
                  );
                }

                return _ChatBubble(
                  message: msg['text'] ?? '',
                  image: msg['image'],
                  isUser: msg['isUser'] ?? false,
                  time: msg['time'] ?? '',
                  detectedIngredients:
                      msg['detectedIngredients'] != null
                          ? List<String>.from(
                              msg['detectedIngredients'],
                            )
                          : null,
                  actionTaken:
                      msg['actionTaken'] ?? false,
                  onConfirm: () =>
                      _handleConfirmIngredients(msg),
                  onEdit: () =>
                      _handleEditIngredients(msg),
                );
              },
            ),
          ),

          // ======================================================
          // CAJA DE MENSAJES
          // ======================================================

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode:
                          _textFieldFocusNode,
                      enabled: !_isLoading,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Escribe un mensaje...',
                        border:
                            InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      onSubmitted: (_) =>
                          _sendMessage(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ==================================================
                // CÁMARA
                // ==================================================

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF2ECC71),
                    ),
                    tooltip: 'Tomar foto',
                    onPressed: _isLoading
                        ? null
                        : _openCamera,
                    iconSize: 24,
                  ),
                ),

                const SizedBox(width: 4),

                // ==================================================
                // GALERÍA
                // ==================================================

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.photo,
                      color: Color(0xFF2ECC71),
                    ),
                    tooltip: 'Galería',
                    onPressed: _isLoading
                        ? null
                        : _openGallery,
                    iconSize: 24,
                  ),
                ),

                const SizedBox(width: 4),

                // ==================================================
                // ENVIAR
                // ==================================================

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71)
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isLoading
                          ? Icons.hourglass_top
                          : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(),
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BURBUJA NORMAL DEL CHAT
// ================================================================

class _ChatBubble extends StatelessWidget {
  final String message;
  final File? image;
  final bool isUser;
  final String time;
  final List<String>? detectedIngredients;
  final bool actionTaken;
  final VoidCallback? onConfirm;
  final VoidCallback? onEdit;

  const _ChatBubble({
    required this.message,
    this.image,
    required this.isUser,
    required this.time,
    this.detectedIngredients,
    this.actionTaken = false,
    this.onConfirm,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              if (!isUser)
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      const Color(0xFF2ECC71),
                  backgroundImage:
                      const AssetImage(
                    'assets/amelia.jpg',
                  ),
                  onBackgroundImageError:
                      (error, stackTrace) {},
                  child: const Icon(
                    Icons.room_service,
                    size: 16,
                    color: Colors.white,
                  ),
                ),

              if (!isUser)
                const SizedBox(width: 8),

              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF2ECC71)
                        : Colors.white,
                    borderRadius:
                        BorderRadius.only(
                      topLeft:
                          const Radius.circular(16),
                      topRight:
                          const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : Radius.zero,
                      bottomRight: isUser
                          ? Radius.zero
                          : const Radius.circular(16),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      if (image != null) ...[
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(12),
                          child: Image.file(
                            image!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (message.isNotEmpty &&
                            message !=
                                '📷 Foto de ingredientes')
                          const SizedBox(height: 8),
                      ],

                      if (message.isNotEmpty &&
                          (image == null ||
                              message !=
                                  '📷 Foto de ingredientes'))
                        Align(
                          alignment:
                              Alignment.centerLeft,
                          child: Text(
                            message,
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),

                      const SizedBox(height: 4),

                      Align(
                        alignment:
                            Alignment.bottomRight,
                        child: Text(
                          time,
                          style: TextStyle(
                            color: isUser
                                ? Colors.white70
                                : Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isUser)
                const SizedBox(width: 8),

              if (isUser)
                const CircleAvatar(
                  backgroundColor:
                      Color(0xFFFDFBF7),
                  radius: 16,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: Color(0xFF2ECC71),
                  ),
                ),
            ],
          ),

          // ========================================================
          // BOTONES DE INGREDIENTES
          // ========================================================

          if (detectedIngredients != null &&
              detectedIngredients!.isNotEmpty) ...[
            const SizedBox(height: 8),

            Padding(
              padding:
                  const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: actionTaken
                          ? Colors.grey.shade500
                          : Colors.white,
                    ),
                    label: Text(
                      'Confirmar',
                      style: TextStyle(
                        color: actionTaken
                            ? Colors.grey.shade500
                            : Colors.white,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    backgroundColor: actionTaken
                        ? Colors.grey.shade200
                        : const Color(0xFF2ECC71),
                    onPressed: actionTaken
                        ? null
                        : onConfirm,
                  ),

                  ActionChip(
                    avatar: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: actionTaken
                          ? Colors.grey.shade500
                          : const Color(0xFF27AE60),
                    ),
                    label: Text(
                      'Editar',
                      style: TextStyle(
                        color: actionTaken
                            ? Colors.grey.shade500
                            : const Color(0xFF27AE60),
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: actionTaken
                        ? Colors.grey.shade100
                        : const Color(0xFFE8F8F0),
                    side: BorderSide(
                      color: actionTaken
                          ? Colors.grey.shade300
                          : const Color(0xFF2ECC71),
                    ),
                    onPressed: actionTaken
                        ? null
                        : onEdit,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================================================================
// INDICADOR "AMELIA ESTÁ ESCRIBIENDO"
// ================================================================

class _TypingBubble extends StatelessWidget {
  final String text;

  const _TypingBubble({
    this.text = 'Amelia está pensando...',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 40,
        bottom: 12,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2ECC71),
                ),
              ),

              const SizedBox(width: 10),

              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// BURBUJA DE RECETA
// ================================================================

class _RecipeBubble extends StatelessWidget {
  final Map<String, dynamic> recipeData;
  final VoidCallback onCook;
  final VoidCallback onSave;
  final String time;

  const _RecipeBubble({
    required this.recipeData,
    required this.onCook,
    required this.onSave,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final ingredients =
        List<String>.from(
      recipeData['ingredients'] ?? [],
    );

    final optionalIngredients =
        List<String>.from(
      recipeData['optionalIngredients'] ?? [],
    );

    final preparation =
        List<String>.from(
      recipeData['preparation'] ?? [],
    );

    final name =
        recipeData['name'] ?? 'Receta';

    final description =
        recipeData['description'] ?? '';

    final servings =
        recipeData['servings'];

    final recipeTime =
        recipeData['time'] ?? '';

    final difficulty =
        recipeData['difficulty'] ?? '';

    final advice =
        recipeData['advice'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                const Color(0xFF2ECC71),
            backgroundImage:
                const AssetImage(
              'assets/amelia.jpg',
            ),
            onBackgroundImageError:
                (error, stackTrace) {},
            child: const Icon(
              Icons.room_service,
              size: 16,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color:
                      const Color(0xFF2ECC71),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '🍽️ $name',
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF27AE60),
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color:
                            Colors.black87,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                  ],

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (servings != null)
                        _InfoChip(
                          icon: Icons.people,
                          text:
                              '$servings porción(es)',
                        ),

                      if (recipeTime
                          .toString()
                          .isNotEmpty)
                        _InfoChip(
                          icon: Icons.timer,
                          text:
                              recipeTime,
                        ),

                      if (difficulty
                          .toString()
                          .isNotEmpty)
                        _InfoChip(
                          icon: Icons
                              .signal_cellular_alt,
                          text:
                              difficulty,
                        ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    '🥘 Ingredientes',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                      color:
                          Color(0xFF27AE60),
                    ),
                  ),

                  const SizedBox(height: 6),

                  ...ingredients.map(
                    (ingredient) =>
                        Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 3,
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color:
                                Color(0xFF2ECC71),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              ingredient,
                              style:
                                  const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (optionalIngredients
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),

                    const Text(
                      '✨ Ingredientes opcionales',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 4),

                    ...optionalIngredients
                        .map(
                      (ingredient) =>
                          Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 2,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Icon(
                              Icons
                                  .add_circle_outline,
                              size: 15,
                              color:
                                  Color(0xFFF39C12),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                ingredient,
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    '👩‍🍳 Preparación',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                      color:
                          Color(0xFF27AE60),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  ...List.generate(
                    preparation.length,
                    (index) {
                      return Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          bottom: 8,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration:
                                  const BoxDecoration(
                                color: Color(
                                  0xFF2ECC71,
                                ),
                                shape:
                                    BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child: Text(
                                preparation[
                                    index],
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (advice
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets
                              .all(12),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFFFF8E7,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: Text(
                        '💡 Consejo de Amelia\n'
                        '$advice',
                        style:
                            const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // BOTONES
                  // ==================================================

                  Row(
                    children: [
                      Expanded(
                        child:
                            ElevatedButton
                                .icon(
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF2ECC71,
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 10,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                          ),
                          icon:
                              const Icon(
                            Icons.chat,
                            color:
                                Colors.white,
                            size: 18,
                          ),
                          label:
                              const Text(
                            'Modo Cocinar',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          onPressed:
                              onCook,
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child:
                            OutlinedButton
                                .icon(
                          style:
                              OutlinedButton
                                  .styleFrom(
                            side:
                                const BorderSide(
                              color:
                                  Color(
                                0xFFF39C12,
                              ),
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 10,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                          ),
                          icon:
                              const Icon(
                            Icons
                                .favorite_border,
                            color:
                                Color(
                              0xFFF39C12,
                            ),
                            size: 18,
                          ),
                          label:
                              const Text(
                            'Guardar',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFFF39C12,
                              ),
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          onPressed:
                              onSave,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: Text(
                      time,
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO CHIP
// ================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF1F8F4),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                const Color(0xFF27AE60),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style:
                const TextStyle(
              fontSize: 12,
              color:
                  Color(0xFF27AE60),
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}