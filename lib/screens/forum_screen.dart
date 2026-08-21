import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> recetas = [
    {
      'id': 1,
      'titulo': 'Ensalada Mediterránea',
      'autor': 'María',
      'likes': 32,
      'liked': false,
      'comentarios': 12,
      'fecha': 'Hace 1 hora',
      'descripcion': 'Fresca y saludable, perfecta para el verano 🥗',
      'ingredientes': [
        'Lechuga',
        'Tomate',
        'Pepino',
        'Aceitunas',
        'Queso feta',
        'Aderezo de hierbas',
      ],
      'instrucciones':
          '1. Lava y corta las verduras en trozos.\n'
          '2. Coloca la lechuga como base en un tazón.\n'
          '3. Agrega el tomate, pepino y aceitunas.\n'
          '4. Añade el queso feta desmenuzado.\n'
          '5. Aliña con el aderezo de hierbas al gusto.\n'
          '6. ¡Mezcla y disfruta de esta deliciosa ensalada! 🥗',
      'comentarios_list': [
        {'usuario': 'Ana', 'texto': '¡Se ve deliciosa! 😋'},
        {'usuario': 'Pedro', 'texto': 'La probé y es increíble.'},
      ],
    },
    {
      'id': 2,
      'titulo': 'Pasta al Pesto',
      'autor': 'Carlos',
      'likes': 18,
      'liked': false,
      'comentarios': 7,
      'fecha': 'Hace 3 horas',
      'descripcion': 'Una receta rápida y deliciosa 🌿',
      'ingredientes': [
        'Pasta',
        'Albahaca',
        'Ajo',
        'Aceite de oliva',
        'Queso parmesano',
        'Piñones',
      ],
      'instrucciones':
          '1. Cocina la pasta en agua con sal.\n'
          '2. Prepara el pesto con albahaca, ajo, piñones y aceite.\n'
          '3. Mezcla la pasta con el pesto.\n'
          '4. Añade queso parmesano al gusto.\n'
          '5. ¡Sirve caliente! 🍝',
      'comentarios_list': [
        {'usuario': 'Luis', 'texto': 'Rápida y fácil, me encantó.'},
      ],
    },
    {
      'id': 3,
      'titulo': 'Sopa de Verduras',
      'autor': 'Ana',
      'likes': 45,
      'liked': false,
      'comentarios': 20,
      'fecha': 'Hace 5 horas',
      'descripcion': 'Calientita y nutritiva 🥕',
      'ingredientes': [
        'Zanahoria',
        'Calabacín',
        'Puerro',
        'Apio',
        'Caldo de verduras',
        'Sal y pimienta',
      ],
      'instrucciones':
          '1. Lava y corta todas las verduras.\n'
          '2. Sofríe las verduras en una olla.\n'
          '3. Agrega el caldo de verduras.\n'
          '4. Cocina a fuego lento por 30 minutos.\n'
          '5. ¡Sirve caliente! 🍲',
      'comentarios_list': [
        {'usuario': 'Marta', 'texto': 'Perfecta para el invierno.'},
        {'usuario': 'Jorge', 'texto': 'La mejor sopa que he probado.'},
      ],
    },
  ];

  void _toggleLike(int index) {
    setState(() {
      recetas[index]['liked'] = !recetas[index]['liked'];
      recetas[index]['likes'] += recetas[index]['liked'] ? 1 : -1;
    });
  }

  void _openRecipeDetail(int index) {
    final receta = recetas[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          receta: receta,
          onLike: () => _toggleLike(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: recetas.length,
        itemBuilder: (context, index) {
          final receta = recetas[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openRecipeDetail(index),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF2ECC71),
                          child: Text(
                            receta['autor'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receta['autor'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                receta['fecha'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2ECC71),
                          const Color(0xFF27AE60),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 60,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receta['titulo'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF27AE60),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          receta['descripcion'],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLike(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: receta['liked']
                                      ? const Color(0xFFF39C12).withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      receta['liked']
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: receta['liked']
                                          ? const Color(0xFFF39C12)
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${receta['likes']}',
                                      style: TextStyle(
                                        color: receta['liked']
                                            ? const Color(0xFFF39C12)
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${receta['comentarios']}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📤 Receta compartida'),
                                    backgroundColor: Color(0xFF2ECC71),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===== PANTALLA DE DETALLE DE RECETA =====
class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> receta;
  final VoidCallback onLike;

  const RecipeDetailScreen({
    super.key,
    required this.receta,
    required this.onLike,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, String>> comentarios = [];

  @override
  void initState() {
    super.initState();
    comentarios = List<Map<String, String>>.from(
      widget.receta['comentarios_list'],
    );
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      comentarios.add({'usuario': 'Tú', 'texto': text});
      widget.receta['comentarios'] = comentarios.length;
    });

    _commentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💬 Comentario añadido'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  Future<void> _saveRecipe() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString('saved_recipes');
    List<Map<String, dynamic>> savedRecipes = [];

    if (recipesJson != null) {
      savedRecipes = List<Map<String, dynamic>>.from(json.decode(recipesJson));
    }

    final exists = savedRecipes.any(
      (r) => r['name'] == widget.receta['titulo'],
    );
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
      'name': widget.receta['titulo'],
      'ingredients': widget.receta['ingredientes'],
      'instructions': widget.receta['instrucciones'],
    });

    await prefs.setString('saved_recipes', json.encode(savedRecipes));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Receta guardada en favoritos'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  void _goToCookingMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepByStepScreen(
          recipeName: widget.receta['titulo'],
          ingredients: List<String>.from(widget.receta['ingredientes']),
          instructions: widget.receta['instrucciones'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receta = widget.receta;
    final ingredientes = List<String>.from(receta['ingredientes']);
    final instrucciones = receta['instrucciones'];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RECETAS PARA TI',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        // ===== ICONOS ELIMINADOS DE LA APP BAR =====
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Autor y fecha
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2ECC71),
                  child: Text(
                    receta['autor'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receta['autor'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      receta['fecha'],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              receta['titulo'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              receta['descripcion'],
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Ingredientes
            const Text(
              '🥘 Ingredientes:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            ...ingredientes.map(
              (ing) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF2ECC71)),
                    const SizedBox(width: 8),
                    Text(ing, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instrucciones
            const Text(
              '👩‍🍳 Instrucciones:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                instrucciones,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // ===== BOTONES EN LA PANTALLA =====
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text(
                      'Modo Cocinar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _goToCookingMode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF39C12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Color(0xFFF39C12),
                    ),
                    label: const Text(
                      'Guardar',
                      style: TextStyle(
                        color: Color(0xFFF39C12),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _saveRecipe,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Comentarios
            const Text(
              '💬 Comentarios:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            ...comentarios
                .map(
                  (com) => Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          com['usuario']!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(com['texto']!),
                      ],
                    ),
                  ),
                )
                .toList(),

            // Campo para agregar comentario
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _addComment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ===== PANTALLA DE PASOS (MODO COCINAR) =====
class StepByStepScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;
  final String instructions;

  const StepByStepScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
    required this.instructions,
  });

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  int currentStep = 0;
  late List<String> steps;

  @override
  void initState() {
    super.initState();
    steps = widget.instructions
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '👩‍🍳 Modo Cocinar',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.recipeName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Paso ${currentStep + 1} de ${steps.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: Color(0xFF2ECC71),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    steps[currentStep],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF2ECC71),
                    ),
                    label: Text(
                      'Anterior',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: currentStep > 0
                        ? () {
                            setState(() {
                              currentStep--;
                            });
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: Text(
                      currentStep < steps.length - 1
                          ? 'Siguiente'
                          : '¡Finalizar!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      if (currentStep < steps.length - 1) {
                        setState(() {
                          currentStep++;
                        });
                      } else {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 ¡Receta completada!'),
                            backgroundColor: Color(0xFF2ECC71),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Volver al foro',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
