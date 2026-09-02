import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_screen.dart';
import '../utils/share_utils.dart';
import 'profile_screen.dart'; // 👈 IMPORTAR ForumRecipeCard

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
  // OBTENER DATOS DEL USUARIO POR UID
  // ============================================================

  Future<Map<String, String>> _getDatosUsuario(String uid) async {
    try {
      if (uid.isEmpty) {
        return {'nombre': 'Usuario', 'fotoPerfil': ''};
      }

      final documento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (documento.exists) {
        final datos = documento.data();
        return {
          'nombre': datos?['usuario']?.toString() ??
              datos?['nombre']?.toString() ??
              'Usuario',
          'fotoPerfil': datos?['fotoPerfil']?.toString() ?? '',
        };
      }

      return {'nombre': 'Usuario', 'fotoPerfil': ''};
    } catch (e) {
      debugPrint('ERROR AL OBTENER DATOS DEL USUARIO: $e');
      return {'nombre': 'Usuario', 'fotoPerfil': ''};
    }
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return 'Fecha desconocida';

    DateTime? fechaDateTime;
    if (fecha is Timestamp) {
      fechaDateTime = fecha.toDate();
    } else if (fecha is DateTime) {
      fechaDateTime = fecha;
    }

    if (fechaDateTime == null) return 'Fecha desconocida';

    final dia = fechaDateTime.day.toString().padLeft(2, '0');
    final mes = fechaDateTime.month.toString().padLeft(2, '0');
    final anio = fechaDateTime.year;
    final hora = fechaDateTime.hour.toString().padLeft(2, '0');
    final minuto = fechaDateTime.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio · $hora:$minuto';
  }

  // ============================================================
  // VERIFICAR SI ESTÁ PUBLICADA (VERSIÓN ROBUSTA)
  // ============================================================

  bool _isPublicada(dynamic valorPublicada, Map<String, dynamic> data) {
    // 1. Verificar por publicadaEnForo
    bool publicada = false;

    if (valorPublicada != null) {
      if (valorPublicada is bool) {
        publicada = valorPublicada;
      } else if (valorPublicada is String) {
        publicada = valorPublicada.toLowerCase() == 'true' ||
            valorPublicada.toLowerCase() == '1';
      } else if (valorPublicada is num) {
        publicada = valorPublicada == 1;
      }
    }

    // 2. Si tiene publicacionId, también está publicada
    if (!publicada) {
      final publicacionId = data['publicacionId']?.toString();
      if (publicacionId != null && publicacionId.isNotEmpty) {
        publicada = true;
      }
    }

    return publicada;
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

      debugPrint('Cargando recetas favoritas de: ${user.uid}');

      final guardadasSnapshot = await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .where('uid', isEqualTo: user.uid)
          .get();

      debugPrint('RECETAS GUARDADAS ENCONTRADAS: ${guardadasSnapshot.docs.length}');

      final List<Map<String, dynamic>> recetas = [];

      for (final doc in guardadasSnapshot.docs) {
        final dataGuardada = doc.data();
        final recetaId = dataGuardada['recetaId'];

        if (recetaId == null) {
          debugPrint('La receta guardada ${doc.id} no tiene recetaId.');
          continue;
        }

        debugPrint('Cargando receta: $recetaId');

        final recetaDoc = await FirebaseFirestore.instance
            .collection('recetas')
            .doc(recetaId)
            .get();

        if (!recetaDoc.exists) {
          debugPrint('La receta $recetaId ya no existe en Firestore.');
          continue;
        }

        final data = recetaDoc.data()!;

        // ========================================================
        // OBTENER DATOS DEL AUTOR
        // ========================================================

        final autorUid = data['uid']?.toString() ?? '';
        String nombreAutor = 'Usuario';
        String fotoAutor = '';

        if (autorUid.isNotEmpty) {
          final datosAutor = await _getDatosUsuario(autorUid);
          nombreAutor = datosAutor['nombre'] ?? 'Usuario';
          fotoAutor = datosAutor['fotoPerfil'] ?? '';
        }

        // ========================================================
        // VERIFICAR SI ESTÁ PUBLICADA (VERSIÓN ROBUSTA)
        // ========================================================

        final publicada = _isPublicada(data['publicadaEnForo'], data);

        // ========================================================
        // PREPARACIÓN
        // ========================================================

        final preparation = List<String>.from(data['preparation'] ?? []);

        // ========================================================
        // INGREDIENTES
        // ========================================================

        final ingredients = List<String>.from(data['ingredients'] ?? []);

        // ========================================================
        // FECHA DE PUBLICACIÓN
        // ========================================================

        final fechaPublicacion = data['fechaPublicacionForo'] ??
            data['fechaCreacion'];

        final fechaFormateada = _formatFecha(fechaPublicacion);

        // ========================================================
        // CONSERVAR TODOS LOS DATOS ORIGINALES
        // ========================================================

        recetas.add({
          ...data,
          'id': recetaDoc.id,
          'recetaId': recetaDoc.id,
          'guardadaId': doc.id,
          'name': data['nombre'] ?? 'Receta sin nombre',
          'titulo': data['nombre'] ?? 'Receta sin nombre',
          'description': data['descripcion'] ?? '',
          'descripcion': data['descripcion'] ?? '',
          'ingredients': ingredients,
          'ingredientes': ingredients,
          'instructions': preparation.join('\n'),
          'preparacion': preparation,
          'autorNombre': nombreAutor,
          'autorFoto': fotoAutor,
          'autorUid': autorUid,
          'publicadaEnForo': publicada,
          'fecha': fechaFormateada,
          'fechaPublicacionForo': fechaPublicacion,
          'likes': data['likes'] ?? 0,
          'comentarios': data['comentarios'] ?? 0,
          'fotoPlatilloUrl': data['fotoPlatilloUrl'] ?? '',
        });

        debugPrint('Receta cargada: ${data['nombre'] ?? 'Sin nombre'} - Publicada: $publicada');
      }

      if (mounted) {
        setState(() {
          savedRecipes = recetas;
        });
      }

      debugPrint('RECETAS FAVORITAS CARGADAS: ${savedRecipes.length}');
    } catch (e) {
      debugPrint('ERROR AL CARGAR RECETAS FAVORITAS: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudieron cargar las recetas: $e'),
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

      if (recipeId == null || guardadaId == null) {
        debugPrint('La receta no tiene ID válido.');
        return;
      }

      debugPrint('Eliminando receta favorita...');
      debugPrint('ID receta: $recipeId');
      debugPrint('ID relación recetas_guardadas: $guardadaId');

      await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .doc(guardadaId)
          .delete();

      debugPrint('Documento eliminado de recetas_guardadas correctamente.');

      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'recetasGuardadas': FieldValue.increment(-1),
        });
        debugPrint('Contador recetasGuardadas actualizado.');
      } catch (e) {
        debugPrint('No se pudo actualizar recetasGuardadas: $e');
      }

      if (!mounted) return;

      setState(() {
        savedRecipes.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Receta eliminada de favoritos'),
          backgroundColor: Color(0xFFE9783F),
        ),
      );

      debugPrint('Receta eliminada de favoritos correctamente.');
    } catch (e) {
      debugPrint('ERROR AL ELIMINAR RECETA FAVORITA: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo eliminar la receta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ABRIR RECETA
  // ============================================================

  void _openRecipe(Map<String, dynamic> recipe) {
    final ingredients = List<String>.from(recipe['ingredients'] ?? []);
    final instructions = recipe['instructions'] is String
        ? recipe['instructions'] as String
        : List<String>.from(recipe['instructions'] ?? []).join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeScreen(
          recipeName: recipe['name'] ?? 'Receta sin nombre',
          ingredients: ingredients,
          instructions: instructions,
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
  // TARJETA DE RECETA PRIVADA (SIMPLE)
  // ============================================================

  Widget _buildPrivateCard(Map<String, dynamic> recipe) {
    final nombreAutor = recipe['autorNombre'] ?? 'Usuario';
    final fotoAutor = recipe['autorFoto'] ?? '';
    final ingredients = List<String>.from(recipe['ingredients'] ?? []);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // ==================================================
          // CABECERA CON AUTOR
          // ==================================================

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE9783F),
                  backgroundImage: fotoAutor.isNotEmpty
                      ? NetworkImage(fotoAutor)
                      : null,
                  child: fotoAutor.isEmpty
                      ? Text(
                          nombreAutor.isNotEmpty
                              ? nombreAutor[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreAutor,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Publicó esta receta',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Etiqueta de "Privada"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Privada',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ==================================================
          // CONTENIDO
          // ==================================================

          ListTile(
            leading: const Icon(
              Icons.restaurant,
              color: Color(0xFFE9783F),
            ),
            title: Text(
              recipe['name'] ?? 'Receta sin nombre',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${ingredients.length} ingredientes',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFFE9783F),
                  ),
                  onPressed: () {
                    ShareUtils.shareRecipe(recipe);
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    final index = savedRecipes.indexOf(recipe);
                    if (index != -1) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar de favoritos'),
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
                                final idx = savedRecipes.indexOf(recipe);
                                if (idx != -1) _removeRecipe(idx);
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            onTap: () => _openRecipe(recipe),
          ),
        ],
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
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFE9783F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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

                // ==================================================
                // VERIFICAR SI ESTÁ PUBLICADA (USANDO LA MISMA FUNCIÓN)
                // ==================================================

                final publicada = _isPublicada(recipe['publicadaEnForo'], recipe);

                debugPrint('🔍 Favoritos: ${recipe['name']} - Publicada: $publicada');

                // ==================================================
                // SI ESTÁ PUBLICADA → USAR ForumRecipeCard (DESDE profile_screen.dart)
                // ==================================================

                if (publicada) {
                  return ForumRecipeCard(
                    receta: recipe,
                    onTap: () => _openRecipe(recipe),
                  );
                }

                // ==================================================
                // SI ES PRIVADA → FORMATO SIMPLE
                // ==================================================

                return _buildPrivateCard(recipe);
              },
            ),
    );
  }
}