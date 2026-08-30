import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_screen.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  List<Map<String, dynamic>> savedRecipes = [];

  @override
  void initState() {
    super.initState();
    _loadSavedRecipes();
  }

  // ============================================================
  // CARGAR RECETAS GUARDADAS
  // ============================================================

  Future<void> _loadSavedRecipes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('No hay usuario autenticado.');
        return;
      }

      debugPrint(
        'Cargando recetas favoritas de: ${user.uid}',
      );

      final guardadasSnapshot = await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .where('uid', isEqualTo: user.uid)
          .get();

      debugPrint(
        'RECETAS GUARDADAS ENCONTRADAS: '
        '${guardadasSnapshot.docs.length}',
      );

      final List<Map<String, dynamic>> recetas = [];

      for (final doc in guardadasSnapshot.docs) {
        final dataGuardada = doc.data();

        final recetaId = dataGuardada['recetaId'];

        if (recetaId == null) {
          debugPrint(
            'La receta guardada ${doc.id} no tiene recetaId.',
          );
          continue;
        }

        debugPrint(
          'Cargando receta: $recetaId',
        );

        final recetaDoc = await FirebaseFirestore.instance
            .collection('recetas')
            .doc(recetaId)
            .get();

        if (!recetaDoc.exists) {
          debugPrint(
            'La receta $recetaId ya no existe en Firestore.',
          );
          continue;
        }

        final data = recetaDoc.data()!;

        // ========================================================
        // PREPARACIÓN
        // ========================================================

        final preparation = List<String>.from(
          data['preparation'] ?? [],
        );

        // ========================================================
        // INGREDIENTES
        // ========================================================

        final ingredients = List<String>.from(
          data['ingredients'] ?? [],
        );

        // ========================================================
        // CONSERVAR TODOS LOS DATOS ORIGINALES
        // ========================================================

        recetas.add({
          ...data,

          // ======================================================
          // IDS
          // ======================================================

          'id': recetaDoc.id,
          'recetaId': recetaDoc.id,
          'guardadaId': doc.id,

          // ======================================================
          // CAMPOS USADOS POR RecipeScreen
          // ======================================================

          'name': data['nombre'] ?? 'Receta sin nombre',

          'description': data['descripcion'] ?? '',

          'ingredients': ingredients,

          // RecipeScreen y StepByStepScreen trabajan con String.
          'instructions': preparation.join('\n'),
        });

        debugPrint(
          'Receta cargada correctamente: '
          '${data['nombre'] ?? 'Sin nombre'}',
        );
      }

      if (mounted) {
        setState(() {
          savedRecipes = recetas;
        });
      }

      debugPrint(
        'RECETAS FAVORITAS CARGADAS: ${savedRecipes.length}',
      );
    } catch (e) {
      debugPrint(
        'ERROR AL CARGAR RECETAS FAVORITAS: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudieron cargar las recetas: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ELIMINAR RECETA DE FAVORITOS
  // ============================================================

  Future<void> _removeRecipe(int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('No hay usuario autenticado.');
        return;
      }

      final recipe = savedRecipes[index];

      final recipeId = recipe['id'];
      final guardadaId = recipe['guardadaId'];

      if (recipeId == null) {
        debugPrint(
          'La receta no tiene ID de Firestore.',
        );
        return;
      }

      if (guardadaId == null) {
        debugPrint(
          'La relación recetas_guardadas no tiene ID.',
        );
        return;
      }

      debugPrint(
        'Eliminando receta favorita...',
      );

      debugPrint(
        'ID receta: $recipeId',
      );

      debugPrint(
        'ID relación recetas_guardadas: $guardadaId',
      );

      // ========================================================
      // ELIMINAR DOCUMENTO DE recetas_guardadas
      // ========================================================

      await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .doc(guardadaId)
          .delete();

      debugPrint(
        'Documento eliminado de recetas_guardadas correctamente.',
      );

      // ========================================================
      // ACTUALIZAR CONTADOR DEL USUARIO
      // ========================================================

      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'recetasGuardadas': FieldValue.increment(-1),
        });

        debugPrint(
          'Contador recetasGuardadas actualizado.',
        );
      } catch (e) {
        // Si el campo no existe o hay algún problema con el
        // contador, no impedimos que la receta sea eliminada.
        debugPrint(
          'No se pudo actualizar recetasGuardadas: $e',
        );
      }

      // ========================================================
      // ACTUALIZAR LISTA VISUAL
      // ========================================================

      if (!mounted) return;

      setState(() {
        savedRecipes.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🗑️ Receta eliminada de favoritos',
          ),
          backgroundColor: Color(0xFFE9783F),
        ),
      );

      debugPrint(
        'Receta eliminada de favoritos correctamente.',
      );
    } catch (e) {
      debugPrint(
        'ERROR AL ELIMINAR RECETA FAVORITA: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo eliminar la receta: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // COMPARTIR RECETA
  // ============================================================

  void _shareRecipe(Map<String, dynamic> recipe) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📤 Receta copiada al portapapeles: '
          '${recipe['name']}',
        ),
        backgroundColor: const Color(0xFFE9783F),
      ),
    );
  }

  // ============================================================
  // ABRIR RECETA
  // ============================================================

  void _openRecipe(Map<String, dynamic> recipe) {
    final ingredients = List<String>.from(
      recipe['ingredients'] ?? [],
    );

    final instructions = recipe['instructions'] is String
        ? recipe['instructions'] as String
        : List<String>.from(
            recipe['instructions'] ?? [],
          ).join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeScreen(
          recipeName: recipe['name'] ?? 'Receta sin nombre',
          ingredients: ingredients,
          instructions: instructions,

          // Pasamos la receta completa para conservar todos
          // los datos necesarios para Modo Cocinar y publicar.
          recipe: {
            ...recipe,
            'ingredients': ingredients,
            'instructions': instructions,
          },
        ),
      ),
    );
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📚 Mis Recetas Guardadas',
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
      ),

      backgroundColor: const Color(0xFFFFF8F0),

      body: savedRecipes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 16),

                  Text(
                    'No tienes recetas guardadas',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Ve al chat y guarda una receta',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),

              itemCount: savedRecipes.length,

              itemBuilder: (context, index) {
                final recipe = savedRecipes[index];

                final ingredients = List<String>.from(
                  recipe['ingredients'] ?? [],
                );

                return Card(
                  elevation: 4,

                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: ListTile(
                    // ==================================================
                    // ICONO
                    // ==================================================

                    leading: const Icon(
                      Icons.restaurant,
                      color: Color(0xFFE9783F),
                    ),

                    // ==================================================
                    // NOMBRE
                    // ==================================================

                    title: Text(
                      recipe['name'] ?? 'Receta sin nombre',

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // ==================================================
                    // INGREDIENTES
                    // ==================================================

                    subtitle: Text(
                      '${ingredients.length} ingredientes',
                    ),

                    // ==================================================
                    // ACCIONES
                    // ==================================================

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        // ==============================================
                        // COMPARTIR
                        // ==============================================

                        IconButton(
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Color(0xFFE9783F),
                          ),

                          onPressed: () {
                            _shareRecipe(recipe);
                          },
                        ),

                        // ==============================================
                        // ELIMINAR
                        // ==============================================

                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),

                          onPressed: () {
                            showDialog(
                              context: context,

                              builder: (_) => AlertDialog(
                                title: const Text(
                                  'Eliminar receta',
                                ),

                                content: const Text(
                                  '¿Quieres eliminar esta receta de tus favoritos?',
                                ),

                                actions: [
                                  // ==================================
                                  // CANCELAR
                                  // ==================================

                                  TextButton(
                                    child: const Text(
                                      'Cancelar',
                                    ),

                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),

                                  // ==================================
                                  // ELIMINAR
                                  // ==================================

                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),

                                    child: const Text(
                                      'Eliminar',
                                    ),

                                    onPressed: () {
                                      Navigator.pop(context);

                                      _removeRecipe(index);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // ==================================================
                    // ABRIR RECETA
                    // ==================================================

                    onTap: () {
                      _openRecipe(recipe);
                    },
                  ),
                );
              },
            ),
    );
  }
}