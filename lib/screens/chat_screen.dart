import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'step_by_step_screen.dart';
import '/services/deepseek_service.dart';
import '/models/recipe_model.dart';

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
  // SERVICIO DE DEEPSEEK
  // ============================================================

  final DeepSeekService _deepSeekService = DeepSeekService();

  // ============================================================
  // VARIABLES DEL CHAT
  // ============================================================

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  bool _isLoading = false;

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
    super.dispose();
  }

  // ============================================================
  // MENSAJE DE BIENVENIDA
  // ============================================================

  void _addWelcomeMessage() {
    setState(() {
      messages.add({
        'text':
            '¡Hola! 👋 Soy Amelia, tu asistente de cocina. ¿Qué vamos a preparar hoy? 🍳',
        'isUser': false,
        'time': _getCurrentTime(),
      });
    });
  }

  // ============================================================
  // ENVIAR MENSAJE A DEEPSEEK
  // ============================================================

  Future<void> _sendMessage() async {
  final text = _controller.text.trim();

  if (text.isEmpty || _isLoading) return;

  setState(() {
    messages.add({
      'text': text,
      'isUser': true,
      'time': _getCurrentTime(),
    });
    _isLoading = true;
  });

  _controller.clear();

  try {
    final response = await _deepSeekService.sendMessage(
      messages: [
        {'role': 'system', 'content': ameliaPrompt},
        {'role': 'system', 'content': enginePrompt},
        {'role': 'system', 'content': recipePrompt},
        {'role': 'user', 'content': text},
      ],
    );

    debugPrint('========== RESPUESTA DE DEEPSEEK ==========');
    debugPrint(response);
    debugPrint('============================================');

    // ------------------------------------------------------------
    // LIMPIAR POSIBLES BLOQUES DE MARKDOWN
    // ------------------------------------------------------------

    String cleanResponse = response.trim();

    cleanResponse = cleanResponse
        .replaceAll('```json', '')
        .replaceAll('```JSON', '')
        .replaceAll('```', '')
        .trim();

    // ------------------------------------------------------------
    // INTENTAR ENCONTRAR EL JSON
    // ------------------------------------------------------------

    final firstBrace = cleanResponse.indexOf('{');
    final lastBrace = cleanResponse.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1) {
      cleanResponse =
          cleanResponse.substring(firstBrace, lastBrace + 1).trim();
    }

    debugPrint('========== JSON LIMPIO ==========');
    debugPrint(cleanResponse);
    debugPrint('=================================');

    dynamic data;

    try {
      data = jsonDecode(cleanResponse);
    } catch (e) {
      debugPrint('ERROR JSON: $e');
      data = null;
    }

    // ------------------------------------------------------------
    // SI ES UNA RECETA
    // ------------------------------------------------------------

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
                data['ingredients'].map((e) => e.toString()),
              )
            : <String>[],
        'optionalIngredients': data['optionalIngredients'] is List
            ? List<String>.from(
                data['optionalIngredients'].map((e) => e.toString()),
              )
            : <String>[],
        'preparation': data['preparation'] is List
            ? List<String>.from(
                data['preparation'].map((e) => e.toString()),
              )
            : <String>[],
        'advice': data['advice']?.toString() ?? '',
        'finalMessage': data['finalMessage']?.toString() ?? '',
      };

      debugPrint('========== RECETA DETECTADA ==========');
      debugPrint(recipe.toString());
      debugPrint('======================================');

      setState(() {
        // Mensaje final de Amelia
        if ((recipe['finalMessage'] as String).isNotEmpty) {
          messages.add({
            'text': recipe['finalMessage'],
            'isUser': false,
            'time': _getCurrentTime(),
          });
        }

        // Tarjeta visual de receta
        messages.add({
          'text': '',
          'isUser': false,
          'isRecipe': true,
          'time': _getCurrentTime(),
          'recipeData': recipe,
        });
      });
    } else {
      // ----------------------------------------------------------
      // NO ES RECETA
      // ----------------------------------------------------------

      debugPrint('La respuesta NO fue reconocida como receta.');

      setState(() {
        messages.add({
          'text': response,
          'isUser': false,
          'time': _getCurrentTime(),
        });
      });
    }
  } catch (e) {
    debugPrint('Error al procesar respuesta: $e');

    setState(() {
      messages.add({
        'text':
            'Lo siento, tuve un pequeño problema al preparar la respuesta. 😅 ¿Podemos intentarlo de nuevo?',
        'isUser': false,
        'time': _getCurrentTime(),
      });
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  // ============================================================
  // MODO COCINAR
  // ============================================================

void _goToCookingMode(Map<String, dynamic> recipe) {
  final recipeName = recipe['name'] ?? 'Receta';
  final ingredients = List<String>.from(recipe['ingredients'] ?? []);
  final instructions = List<String>.from(recipe['preparation'] ?? []).join('\n');

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
  // GUARDAR RECETA
  // ============================================================

  Future<void> _saveRecipe(Map<String, dynamic> recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString('saved_recipes');

    List<Map<String, dynamic>> savedRecipes = [];

    if (recipesJson != null) {
      savedRecipes = List<Map<String, dynamic>>.from(
        json.decode(recipesJson),
      );
    }

    final exists = savedRecipes.any(
      (r) => r['name'] == recipe['name'],
    );

    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Esta receta ya está en favoritos'),
          backgroundColor: Color(0xFFF39C12),
        ),
      );
      return;
    }

    savedRecipes.add({
      'name': recipe['name'],
      'ingredients': recipe['ingredients'],
      'instructions': recipe['preparation'],
    });

    await prefs.setString(
      'saved_recipes',
      json.encode(savedRecipes),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Receta guardada en favoritos'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  // ============================================================
  // HORA ACTUAL
  // ============================================================

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CÁMARA Y GALERÍA
  // ============================================================

  void _openCamera() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📷 Seguimos trabajando en esto...'),
        backgroundColor: Color(0xFF2ECC71),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _openGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🖼️ Seguimos trabajando en esto...'),
        backgroundColor: Color(0xFF2ECC71),
        duration: Duration(seconds: 1),
      ),
    );
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
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (_isLoading ? 2 : 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const SizedBox(height: 40);
                }

                if (_isLoading && index == messages.length + 1) {
                  return const _TypingBubble();
                }

                final msgIndex = index - 1;

                if (msgIndex >= messages.length) {
                  return const SizedBox.shrink();
                }

                final msg = messages[msgIndex];
                final isRecipe = msg['isRecipe'] ?? false;

                if (isRecipe) {
                  return _RecipeBubble(
                  recipeData: msg['recipeData'],
                  onCook: () => _goToCookingMode(msg['recipeData']),
                  onSave: () => _saveRecipe(msg['recipeData']),
                  time: msg['time'],
                );
                }

                return _ChatBubble(
                  message: msg['text'],
                  isUser: msg['isUser'],
                  time: msg['time'],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
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
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF2ECC71),
                    ),
                    onPressed: _isLoading ? null : _openCamera,
                    iconSize: 24,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.photo,
                      color: Color(0xFF2ECC71),
                    ),
                    onPressed: _isLoading ? null : _openGallery,
                    iconSize: 24,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withOpacity(0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isLoading ? Icons.hourglass_top : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _sendMessage,
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
  final bool isUser;
  final String time;

  const _ChatBubble({
    required this.message,
    required this.isUser,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2ECC71),
              backgroundImage: const AssetImage('assets/amelia.jpg'),
              onBackgroundImageError: (error, stackTrace) {},
              child: const Icon(
                Icons.room_service,
                size: 16,
                color: Colors.white,
              ),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2ECC71) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight:
                      isUser ? Radius.zero : const Radius.circular(16),
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            const CircleAvatar(
              backgroundColor: Color(0xFFFDFBF7),
              radius: 16,
              child: Icon(
                Icons.person,
                size: 16,
                color: Color(0xFF2ECC71),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// INDICADOR "AMELIA ESTÁ ESCRIBIENDO"
// ================================================================

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2ECC71),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Amelia está pensando...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
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
    final ingredients = List<String>.from(recipeData['ingredients'] ?? []);
    final optionalIngredients =
        List<String>.from(recipeData['optionalIngredients'] ?? []);
    final preparation = List<String>.from(recipeData['preparation'] ?? []);

    final name = recipeData['name'] ?? 'Receta';
    final description = recipeData['description'] ?? '';
    final servings = recipeData['servings'];
    final recipeTime = recipeData['time'] ?? '';
    final difficulty = recipeData['difficulty'] ?? '';
    final advice = recipeData['advice'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2ECC71),
            backgroundImage: const AssetImage('assets/amelia.jpg'),
            onBackgroundImageError: (error, stackTrace) {},
            child: const Icon(
              Icons.room_service,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF2ECC71),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🍽️ $name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (servings != null)
                        _InfoChip(
                          icon: Icons.people,
                          text: '$servings porción(es)',
                        ),
                      if (recipeTime.toString().isNotEmpty)
                        _InfoChip(
                          icon: Icons.timer,
                          text: recipeTime,
                        ),
                      if (difficulty.toString().isNotEmpty)
                        _InfoChip(
                          icon: Icons.signal_cellular_alt,
                          text: difficulty,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🥘 Ingredientes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...ingredients.map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF2ECC71),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ingredient,
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (optionalIngredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      '✨ Ingredientes opcionales',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...optionalIngredients.map(
                      (ingredient) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              size: 15,
                              color: Color(0xFFF39C12),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ingredient,
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '👩‍🍳 Preparación',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    preparation.length,
                    (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2ECC71),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                preparation[index],
                                style: const TextStyle(
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
                  if (advice.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '💡 Consejo de Amelia\n$advice',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.chat,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Modo Cocinar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: onCook,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFF39C12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Color(0xFFF39C12),
                            size: 18,
                          ),
                          label: const Text(
                            'Guardar',
                            style: TextStyle(
                              color: Color(0xFFF39C12),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: onSave,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: Colors.grey,
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF27AE60),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF27AE60),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}