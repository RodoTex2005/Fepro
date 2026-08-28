import 'package:flutter/material.dart';
import '/screens/step_by_step_screen.dart';
import 'publish_recipe_screen.dart';

class RecipeScreen extends StatelessWidget {
  final String recipeName;
  final List<String> ingredients;
  final String instructions;

  // Receta completa para poder compartirla en el foro
  final Map<String, dynamic> recipe;

  const RecipeScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
    required this.instructions,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📝 Receta',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFE9783F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.favorite_border,
              color: Colors.white,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '❤️ Receta guardada en favoritos',
                  ),
                  backgroundColor: Color(0xFFE9783F),
                ),
              );
            },
          ),
        ],
      ),

      backgroundColor: const Color(0xFFFFF8F0),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ======================================================
            // NOMBRE DE LA RECETA
            // ======================================================

            Container(
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: const Color(0xFFE9783F),
                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 28,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      recipeName,

                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ======================================================
            // INGREDIENTES
            // ======================================================

            const Text(
              '🥘 Ingredientes:',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC95D2E),
              ),
            ),

            const SizedBox(height: 8),

            ...ingredients.map(
              (ing) => Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Icon(
                      Icons.circle,
                      size: 8,
                      color: Color(0xFFE9783F),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        ing,

                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ======================================================
            // INSTRUCCIONES
            // ======================================================

            const Text(
              '👩‍🍳 Instrucciones:',

              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC95D2E),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(12),

                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),

                child: SingleChildScrollView(
                  child: Text(
                    instructions,

                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ======================================================
            // MODO COCINAR
            // ======================================================

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE9783F),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 14,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),

                icon: const Icon(
                  Icons.chat,
                  color: Colors.white,
                ),

                label: const Text(
                  '👩‍🍳 Modo Cocinar',

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                onPressed: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) =>
                          StepByStepScreen(
                        recipeName:
                            recipeName,

                        ingredients:
                            ingredients,

                        instructions:
                            instructions,

                        // IMPORTANTE:
                        // Pasamos la receta completa
                        // para poder compartirla
                        // al finalizar.
                        recipe:
                            recipe,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

