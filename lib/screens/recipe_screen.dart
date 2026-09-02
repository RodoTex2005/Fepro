import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/screens/step_by_step_screen.dart';
import '../utils/share_utils.dart';

class RecipeScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;
  final String instructions;
  final Map<String, dynamic> recipe;

  const RecipeScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
    required this.instructions,
    required this.recipe,
  });

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // PUBLICACIÓN
  // ============================================================

  Map<String, dynamic>? _publication;
  String? _publicationId;
  bool _loadingPublication = false;

  // ============================================================
  // AUTOR
  // ============================================================

  String _authorName = 'Usuario';
  String? _authorPhotoUrl;
  bool _loadingAuthor = false;

  // ============================================================
  // LIKE
  // ============================================================

  bool _hasLiked = false;
  bool _loadingLike = false;

  // ============================================================
  // GUARDAR
  // ============================================================

  bool _isSaving = false;
  bool _isAlreadySaved = false;
  String? _savedRecipeDocumentId;

  // ============================================================
  // COMENTARIOS
  // ============================================================

  final TextEditingController _commentController = TextEditingController();
  bool _sendingComment = false;

  // ============================================================
  // INICIO
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadRecipeState();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR ESTADO
  // ============================================================

  Future<void> _loadRecipeState() async {
    await Future.wait([
      _checkIfSaved(),
      _loadAuthorData(),
    ]);
  }

  // ============================================================
  // PUBLICADA
  // ============================================================

  bool get _isPublished {
    final value = widget.recipe['publicadaEnForo'];
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  // ============================================================
  // CARGAR DATOS DEL AUTOR
  // ============================================================

  Future<void> _loadAuthorData() async {
    // Primero verificar si ya viene en la receta
    if (widget.recipe['autorNombre'] != null &&
        widget.recipe['autorNombre'].toString().isNotEmpty) {
      setState(() {
        _authorName = widget.recipe['autorNombre'].toString();
        _authorPhotoUrl = widget.recipe['autorFoto']?.toString();
      });
      return;
    }

    // Si no, buscar por uid
    final uid = widget.recipe['uid']?.toString() ??
        widget.recipe['autorUid']?.toString();

    if (uid == null || uid.isEmpty) {
      // Si no hay uid, usar datos de la receta
      setState(() {
        _authorName = widget.recipe['usuario']?.toString() ??
            widget.recipe['nombreUsuario']?.toString() ??
            widget.recipe['nombre']?.toString() ??
            'Usuario';
        _authorPhotoUrl = widget.recipe['fotoPerfil']?.toString();
      });
      return;
    }

    setState(() {
      _loadingAuthor = true;
    });

    try {
      final userDoc = await _firestore
          .collection('usuarios')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final name = data['usuario']?.toString() ??
              data['nombre']?.toString() ??
              'Usuario';
          final photo = data['fotoPerfil']?.toString();

          if (mounted) {
            setState(() {
              if (name.isNotEmpty) _authorName = name;
              if (photo != null && photo.isNotEmpty) {
                _authorPhotoUrl = photo;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('ERROR AL CARGAR DATOS DEL AUTOR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingAuthor = false;
        });
      }
    }
  }

  // ============================================================
  // COMPROBAR GUARDADA
  // ============================================================

  Future<void> _checkIfSaved() async {
    final user = _auth.currentUser;
    final recipeId = widget.recipe['recetaId']?.toString() ??
        widget.recipe['id']?.toString();

    if (user == null || recipeId == null || recipeId.isEmpty) return;

    try {
      final query = await _firestore
          .collection('recetas_guardadas')
          .where('uid', isEqualTo: user.uid)
          .where('recetaId', isEqualTo: recipeId)
          .limit(1)
          .get();

      if (!mounted) return;

      setState(() {
        _isAlreadySaved = query.docs.isNotEmpty;
        if (query.docs.isNotEmpty) {
          _savedRecipeDocumentId = query.docs.first.id;
        }
      });
    } catch (e) {
      debugPrint('ERROR AL COMPROBAR RECETA GUARDADA: $e');
    }
  }

  // ============================================================
  // GUARDAR / QUITAR
  // ============================================================

  Future<void> _toggleSaveRecipe() async {
    final user = _auth.currentUser;
    final recipeId = widget.recipe['recetaId']?.toString() ??
        widget.recipe['id']?.toString();

    if (user == null) {
      _showMessage('⚠️ Debes iniciar sesión para guardar recetas.',
          const Color(0xFFF39C12));
      return;
    }

    if (recipeId == null || recipeId.isEmpty) {
      _showMessage('❌ La receta no tiene un ID válido.', Colors.red);
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isAlreadySaved) {
        if (_savedRecipeDocumentId != null) {
          await _firestore
              .collection('recetas_guardadas')
              .doc(_savedRecipeDocumentId)
              .delete();

          try {
            await _firestore
                .collection('usuarios')
                .doc(user.uid)
                .update({
              'recetasGuardadas': FieldValue.increment(-1),
            });
          } catch (e) {
            debugPrint('No se pudo actualizar contador: $e');
          }
        }

        if (!mounted) return;

        setState(() {
          _isAlreadySaved = false;
          _savedRecipeDocumentId = null;
        });

        _showMessage('🗑️ Receta eliminada de favoritos',
            const Color(0xFFE9783F));
        return;
      }

      final newDoc = await _firestore
          .collection('recetas_guardadas')
          .add({
        'uid': user.uid,
        'recetaId': recipeId,
        'fechaGuardado': FieldValue.serverTimestamp(),
      });

      try {
        await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'recetasGuardadas': FieldValue.increment(1),
        });
      } catch (e) {
        debugPrint('No se pudo actualizar contador: $e');
      }

      if (!mounted) return;

      setState(() {
        _isAlreadySaved = true;
        _savedRecipeDocumentId = newDoc.id;
      });

      _showMessage('❤️ Receta guardada en favoritos',
          const Color(0xFFE9783F));
    } catch (e) {
      debugPrint('ERROR AL GUARDAR RECETA: $e');
      if (!mounted) return;
      _showMessage('❌ No se pudo guardar la receta: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // MODO COCINAR
  // ============================================================

  void _openCookingMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepByStepScreen(
          recipeName: widget.recipeName,
          ingredients: widget.ingredients,
          instructions: widget.instructions,
          recipe: widget.recipe,
        ),
      ),
    );
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildProfileAvatar({
    double radius = 24,
    String? photoUrl,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFFFE8E0),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('ERROR AL CARGAR FOTO DE PERFIL: $exception');
        },
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE8E0),
      child: Icon(
        Icons.person,
        color: const Color(0xFFE9783F),
        size: radius,
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
          '📝 Receta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFE9783F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              ShareUtils.shareRecipe(widget.recipe);
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // AUTOR
            // ==================================================

            if (_authorName.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildProfileAvatar(
                      radius: 24,
                      photoUrl: _authorPhotoUrl,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Publicado por',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _authorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC95D2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isPublished)
                      const Icon(
                        Icons.public,
                        color: Color(0xFFE9783F),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ==================================================
            // NOMBRE
            // ==================================================

            Container(
              width: double.infinity,
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
                      widget.recipeName,
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

            // ==================================================
            // INGREDIENTES
            // ==================================================

            const Text(
              '🥘 Ingredientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC95D2E),
              ),
            ),
            const SizedBox(height: 8),
            ...widget.ingredients.map(
              (ing) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ==================================================
            // INSTRUCCIONES
            // ==================================================

            const Text(
              '👩‍🍳 Instrucciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC95D2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
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
                widget.instructions,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ==================================================
            // MODO COCINAR
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE9783F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.restaurant_menu,
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
                onPressed: _openCookingMode,
              ),
            ),
            const SizedBox(height: 10),

            // ==================================================
            // GUARDAR
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFFF39C12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF39C12),
                        ),
                      )
                    : Icon(
                        _isAlreadySaved
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: const Color(0xFFF39C12),
                      ),
                label: Text(
                  _isAlreadySaved
                      ? 'Guardada en favoritos'
                      : 'Guardar receta',
                  style: const TextStyle(
                    color: Color(0xFFF39C12),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isSaving ? null : _toggleSaveRecipe,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}