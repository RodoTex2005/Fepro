import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'step_by_step_screen.dart'; // <-- NUEVO IMPORT
import '../services/deepseek_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
final DeepSeekService _deepSeekService = DeepSeekService();

final List<Map<String, String>> _conversation = [
  {
    'role': 'system',
    'content': '''
Eres Amelia, la asistente de cocina de Recetias.

Eres empática, amable, cercana, paciente, creativa y motivadora.

Tu objetivo es ayudar al usuario a cocinar y disfrutar el proceso.

Habla de forma natural y cálida, como una amiga que sabe cocinar.

Si el usuario tiene pocos ingredientes, busca alternativas
realistas utilizando lo que tenga disponible.

Nunca juzgues al usuario por sus conocimientos de cocina.

Si solicita una receta, proporciona una receta clara y útil.

Si solamente quiere conversar, conversa naturalmente.

Responde siempre en español.
'''
  },
];
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? _currentRecipe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addWelcomeMessage();
    });
  }

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

  Future<void> _sendMessage() async {
  final text = _controller.text.trim();

  if (text.isEmpty) return;

  setState(() {
    messages.add({
      'text': text,
      'isUser': true,
      'time': _getCurrentTime(),
    });
  });

  _controller.clear();

  _conversation.add({
    'role': 'user',
    'content': text,
  });

  try {
    final response = await _deepSeekService.sendMessage(
      messages: _conversation,
    );

    _conversation.add({
      'role': 'assistant',
      'content': response,
    });

    if (!mounted) return;

    setState(() {
      messages.add({
        'text': response,
        'isUser': false,
        'time': _getCurrentTime(),
      });
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      messages.add({
        'text':
            '😔 Uy, parece que tuve un problema al conectarme. Inténtalo nuevamente.',
        'isUser': false,
        'time': _getCurrentTime(),
      });
    });

    debugPrint('Error DeepSeek: $e');
  }
}

  void _showRecipeInChat() {
    if (_currentRecipe == null) return;

    final recipe = _currentRecipe!;
    final String recipeText =
        '''
🍳 **${recipe['name']}**

🥘 **Ingredientes:**
${(recipe['ingredients'] as List).map((e) => '• $e').join('\n')}

👩‍🍳 **Instrucciones:**
${recipe['instructions']}
    ''';

    setState(() {
      messages.add({
        'text': recipeText,
        'isUser': false,
        'isRecipe': true,
        'time': _getCurrentTime(),
        'recipeData': recipe,
      });
    });
  }

  String _getAIResponse(String userText) {
    final lowerText = userText.toLowerCase();

    if (lowerText.contains('jamón') && lowerText.contains('huevo')) {
      return '🍳 ¡Excelente elección! Aquí tienes la receta completa de Jamón con Huevo:';
    }

    if (lowerText.contains('jamón') || lowerText.contains('huevo')) {
      return '🥚 ¿Jamón y huevo? ¡Perfecto! Aquí tienes la receta completa:';
    }

    if (lowerText.contains('hola') ||
        lowerText.contains('buenas') ||
        lowerText.contains('hey')) {
      return '¡Hola! 👋 ¿Qué te gustaría cocinar hoy? Dime "jamón y huevo" para una receta fácil.';
    }

    if (lowerText.contains('ayuda') || lowerText.contains('cómo')) {
      return '😊 Claro, ¡estoy aquí para ayudarte! Puedes decirme qué ingredientes tienes y te daré una receta. Por ejemplo: "jamón y huevo"';
    }

    return '🤔 ¡Interesante! ¿Quieres que te ayude a preparar algo con esos ingredientes? Dime "jamón y huevo" para una receta fácil.';
  }

  bool _isRecipeRequest(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('jamón') || lowerText.contains('huevo');
  }

  void _goToCookingMode(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepByStepScreen(
          recipeName: recipe['name'],
          ingredients: List<String>.from(recipe['ingredients']),
          instructions: recipe['instructions'],
        ),
      ),
    );
  }

  Future<void> _saveRecipe(Map<String, dynamic> recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString('saved_recipes');
    List<Map<String, dynamic>> savedRecipes = [];

    if (recipesJson != null) {
      savedRecipes = List<Map<String, dynamic>>.from(json.decode(recipesJson));
    }

    final exists = savedRecipes.any((r) => r['name'] == recipe['name']);
    if (exists) {
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
      'instructions': recipe['instructions'],
    });

    await prefs.setString('saved_recipes', json.encode(savedRecipes));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Receta guardada en favoritos'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const SizedBox(height: 40);
                }

                final msgIndex = index - 1;
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
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
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
                    onPressed: _openCamera,
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
                    icon: const Icon(Icons.photo, color: Color(0xFF2ECC71)),
                    onPressed: _openGallery,
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
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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

// ===== BURBUJA DE CHAT NORMAL =====
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
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
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
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
              child: Icon(Icons.person, size: 16, color: Color(0xFF2ECC71)),
            ),
        ],
      ),
    );
  }
}

// ===== BURBUJA DE RECETA =====
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
    final ingredients = List<String>.from(recipeData['ingredients']);
    final instructions = recipeData['instructions'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
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
                border: Border.all(color: const Color(0xFF2ECC71), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipeData['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF27AE60),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    '🥘 Ingredientes:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  ...ingredients.map(
                    (ing) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF2ECC71),
                          ),
                          const SizedBox(width: 8),
                          Text(ing, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    '👩‍🍳 Instrucciones:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instructions,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),

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
                            side: const BorderSide(color: Color(0xFFF39C12)),
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
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    textAlign: TextAlign.end,
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
