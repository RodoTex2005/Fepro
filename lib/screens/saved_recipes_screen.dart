import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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

  Future<void> _loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recipesJson = prefs.getString('saved_recipes');
    if (recipesJson != null) {
      final List<dynamic> decoded = json.decode(recipesJson);
      setState(() {
        savedRecipes = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  Future<void> _removeRecipe(int index) async {
    setState(() {
      savedRecipes.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_recipes', json.encode(savedRecipes));
  }

  void _shareRecipe(Map<String, dynamic> recipe) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📤 Receta copiada al portapapeles: ${recipe['name']}'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📚 Mis Recetas Guardadas',
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
      body: savedRecipes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tienes recetas guardadas',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ve al chat y guarda una receta',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedRecipes.length,
              itemBuilder: (context, index) {
                final recipe = savedRecipes[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.restaurant,
                      color: Color(0xFF2ECC71),
                    ),
                    title: Text(
                      recipe['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${(recipe['ingredients'] as List).length} ingredientes',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Color(0xFF2ECC71),
                          ),
                          onPressed: () => _shareRecipe(recipe),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Eliminar receta'),
                                content: const Text(
                                  '¿Quieres eliminar esta receta de tus favoritos?',
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancelar'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Eliminar'),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeScreen(
                            recipeName: recipe['name'],
                            ingredients: List<String>.from(
                              recipe['ingredients'],
                            ),
                            instructions: recipe['instructions'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
