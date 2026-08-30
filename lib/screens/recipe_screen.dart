import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/screens/step_by_step_screen.dart';

class RecipeScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;
  final String instructions;

  // Receta completa.
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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // PUBLICACIÓN
  // ============================================================

  Map<String, dynamic>? _publication;

  String? _publicationId;

  bool _loadingPublication = false;

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

  final TextEditingController _commentController =
      TextEditingController();

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
  // CARGAR ESTADO DE LA RECETA
  // ============================================================

  Future<void> _loadRecipeState() async {
    await Future.wait([
      _checkIfSaved(),
      _loadPublication(),
    ]);
  }

  // ============================================================
  // COMPROBAR SI ESTÁ PUBLICADA
  // ============================================================

  bool get _isPublished {
    final value = widget.recipe['publicadaEnForo'];

    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  // ============================================================
  // CARGAR PUBLICACIÓN
  // ============================================================

  Future<void> _loadPublication() async {
    if (!_isPublished) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _loadingPublication = true;
    });

    try {
      final user = _auth.currentUser;

      // ========================================================
      // 1. INTENTAR CON publicacionId
      // ========================================================

      final publicationId =
          widget.recipe['publicacionId']?.toString();

      if (publicationId != null &&
          publicationId.isNotEmpty) {
        final publicationDoc = await _firestore
            .collection('publicaciones')
            .doc(publicationId)
            .get();

        if (publicationDoc.exists) {
          _publicationId = publicationDoc.id;
          _publication = publicationDoc.data();

          await _checkLike();

          return;
        }
      }

      // ========================================================
      // 2. BUSCAR POR AUTOR + TÍTULO
      // ========================================================

      if (user != null) {
        final query = await _firestore
            .collection('publicaciones')
            .where(
              'autorUid',
              isEqualTo: user.uid,
            )
            .where(
              'titulo',
              isEqualTo: widget.recipeName,
            )
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;

          _publicationId = doc.id;
          _publication = doc.data();

          await _checkLike();
        }
      }
    } catch (e) {
      debugPrint(
        'ERROR AL CARGAR PUBLICACIÓN: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingPublication = false;
        });
      }
    }
  }

  // ============================================================
  // COMPROBAR LIKE
  // ============================================================

  Future<void> _checkLike() async {
    final user = _auth.currentUser;

    final publicationId = _publicationId;

    if (user == null ||
        publicationId == null ||
        publicationId.isEmpty) {
      return;
    }

    try {
      final likeDoc = await _firestore
          .collection('publicaciones')
          .doc(publicationId)
          .collection('likes')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _hasLiked = likeDoc.exists;
      });
    } catch (e) {
      debugPrint(
        'ERROR AL COMPROBAR LIKE: $e',
      );
    }
  }

  // ============================================================
  // DAR / QUITAR LIKE
  // ============================================================

  Future<void> _toggleLike() async {
    final user = _auth.currentUser;

    final publicationId = _publicationId;

    if (user == null ||
        publicationId == null ||
        publicationId.isEmpty ||
        _loadingLike) {
      return;
    }

    setState(() {
      _loadingLike = true;
    });

    try {
      final publicationRef = _firestore
          .collection('publicaciones')
          .doc(publicationId);

      final likeRef = publicationRef
          .collection('likes')
          .doc(user.uid);

      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // ======================================================
        // QUITAR LIKE
        // ======================================================

        await likeRef.delete();

        await publicationRef.update({
          'likesCount': FieldValue.increment(-1),
        });

        if (!mounted) return;

        setState(() {
          _hasLiked = false;

          if (_publication != null) {
            final current =
                (_publication!['likesCount'] ?? 0) as num;

            _publication!['likesCount'] =
                current > 0 ? current - 1 : 0;
          }
        });
      } else {
        // ======================================================
        // DAR LIKE
        // ======================================================

        await likeRef.set({
          'uid': user.uid,
          'fecha': FieldValue.serverTimestamp(),
        });

        await publicationRef.update({
          'likesCount': FieldValue.increment(1),
        });

        if (!mounted) return;

        setState(() {
          _hasLiked = true;

          if (_publication != null) {
            final current =
                (_publication!['likesCount'] ?? 0) as num;

            _publication!['likesCount'] =
                current + 1;
          }
        });
      }
    } catch (e) {
      debugPrint(
        'ERROR AL ACTUALIZAR LIKE: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo actualizar el like: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLike = false;
        });
      }
    }
  }

  // ============================================================
  // COMPROBAR SI YA ESTÁ GUARDADA
  // ============================================================

  Future<void> _checkIfSaved() async {
    final user = _auth.currentUser;

    final recipeId =
        widget.recipe['recetaId']?.toString() ??
            widget.recipe['id']?.toString();

    if (user == null ||
        recipeId == null ||
        recipeId.isEmpty) {
      return;
    }

    try {
      final query = await _firestore
          .collection('recetas_guardadas')
          .where(
            'uid',
            isEqualTo: user.uid,
          )
          .where(
            'recetaId',
            isEqualTo: recipeId,
          )
          .limit(1)
          .get();

      if (!mounted) return;

      setState(() {
        _isAlreadySaved = query.docs.isNotEmpty;

        if (query.docs.isNotEmpty) {
          _savedRecipeDocumentId =
              query.docs.first.id;
        }
      });
    } catch (e) {
      debugPrint(
        'ERROR AL COMPROBAR RECETA GUARDADA: $e',
      );
    }
  }

  // ============================================================
  // GUARDAR / QUITAR DE FAVORITOS
  // ============================================================

  Future<void> _toggleSaveRecipe() async {
    final user = _auth.currentUser;

    final recipeId =
        widget.recipe['recetaId']?.toString() ??
            widget.recipe['id']?.toString();

    if (user == null) {
      _showMessage(
        '⚠️ Debes iniciar sesión para guardar recetas.',
        const Color(0xFFF39C12),
      );

      return;
    }

    if (recipeId == null ||
        recipeId.isEmpty) {
      _showMessage(
        '❌ La receta no tiene un ID válido.',
        Colors.red,
      );

      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // ========================================================
      // YA ESTÁ GUARDADA → ELIMINAR
      // ========================================================

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
              'recetasGuardadas':
                  FieldValue.increment(-1),
            });
          } catch (e) {
            debugPrint(
              'No se pudo actualizar contador: $e',
            );
          }
        }

        if (!mounted) return;

        setState(() {
          _isAlreadySaved = false;
          _savedRecipeDocumentId = null;
        });

        _showMessage(
          '🗑️ Receta eliminada de favoritos',
          const Color(0xFFE9783F),
        );

        return;
      }

      // ========================================================
      // NO ESTÁ GUARDADA → GUARDAR
      // ========================================================

      final newDoc = await _firestore
          .collection('recetas_guardadas')
          .add({
        'uid': user.uid,
        'recetaId': recipeId,
        'fechaGuardado':
            FieldValue.serverTimestamp(),
      });

      try {
        await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .update({
          'recetasGuardadas':
              FieldValue.increment(1),
        });
      } catch (e) {
        debugPrint(
          'No se pudo actualizar contador: $e',
        );
      }

      if (!mounted) return;

      setState(() {
        _isAlreadySaved = true;
        _savedRecipeDocumentId = newDoc.id;
      });

      _showMessage(
        '❤️ Receta guardada en favoritos',
        const Color(0xFFE9783F),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL GUARDAR RECETA: $e',
      );

      if (!mounted) return;

      _showMessage(
        '❌ No se pudo guardar la receta: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // ENVIAR COMENTARIO
  // ============================================================

  Future<void> _sendComment() async {
    final user = _auth.currentUser;

    final publicationId = _publicationId;

    final text =
        _commentController.text.trim();

    if (user == null) {
      _showMessage(
        '⚠️ Debes iniciar sesión para comentar.',
        const Color(0xFFF39C12),
      );

      return;
    }

    if (publicationId == null ||
        publicationId.isEmpty ||
        text.isEmpty ||
        _sendingComment) {
      return;
    }

    setState(() {
      _sendingComment = true;
    });

    try {
      String userName = 'Usuario';

      try {
        final userDoc = await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();

          userName =
              data?['nombre']?.toString() ??
                  'Usuario';
        }
      } catch (e) {
        debugPrint(
          'No se pudo obtener nombre del usuario: $e',
        );
      }

      final publicationRef =
          _firestore
              .collection('publicaciones')
              .doc(publicationId);

      await publicationRef
          .collection('comentarios')
          .add({
        'uid': user.uid,
        'usuarioNombre': userName,
        'texto': text,
        'fecha': FieldValue.serverTimestamp(),
      });

      await publicationRef.update({
        'comentariosCount':
            FieldValue.increment(1),
      });

      _commentController.clear();

      if (!mounted) return;

      setState(() {
        if (_publication != null) {
          final current =
              (_publication!['comentariosCount'] ?? 0)
                  as num;

          _publication!['comentariosCount'] =
              current + 1;
        }
      });

      FocusScope.of(context).unfocus();

      _showMessage(
        '💬 Comentario publicado',
        const Color(0xFFE9783F),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL PUBLICAR COMENTARIO: $e',
      );

      if (!mounted) return;

      _showMessage(
        '❌ No se pudo publicar el comentario: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingComment = false;
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

  void _showMessage(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // ============================================================
  // FOTO DE LA PUBLICACIÓN
  // ============================================================

  Widget _buildPublicationPhoto() {
    // ==========================================================
    // PRIMERO:
    // Intentamos obtener la foto desde la publicación.
    // ==========================================================

    String? photoUrl =
        _publication?['fotoPlatilloUrl']
            ?.toString();

    // ==========================================================
    // SEGUNDO:
    // Si no está en la publicación, la buscamos directamente
    // en la receta que recibimos desde Historial de Amelia.
    // ==========================================================

    if (photoUrl == null || photoUrl.isEmpty) {
      photoUrl =
          widget.recipe['fotoPlatilloUrl']
              ?.toString();
    }

    // ==========================================================
    // SI NO EXISTE FOTO
    // ==========================================================

    if (photoUrl == null ||
        photoUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'No hay foto del platillo',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // MOSTRAR FOTO
    // ==========================================================

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(16),
      child: Image.network(
        photoUrl,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
        loadingBuilder:
            (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return Container(
            height: 300,
            color: Colors.grey.shade200,
            child: const Center(
              child:
                  CircularProgressIndicator(
                color: Color(0xFFE9783F),
              ),
            ),
          );
        },
        errorBuilder:
            (context, error, stackTrace) {
          debugPrint(
            'ERROR AL CARGAR FOTO DEL PLATILLO: $error',
          );

          return Container(
            height: 300,
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 60,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'No se pudo cargar la foto',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // INFORMACIÓN SOCIAL
  // ============================================================

  Widget _buildSocialSection() {
    if (_publicationId == null) {
      return const SizedBox.shrink();
    }

    final likes =
        _publication?['likesCount'] ?? 0;

    final comments =
        _publication?['comentariosCount'] ?? 0;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Row(
          children: [
            // ==================================================
            // LIKE
            // ==================================================

            InkWell(
              borderRadius:
                  BorderRadius.circular(30),
              onTap:
                  _loadingLike
                      ? null
                      : _toggleLike,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: _hasLiked
                      ? const Color(
                          0xFFFFE8E0,
                        )
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                  border: Border.all(
                    color: _hasLiked
                        ? const Color(
                            0xFFE9783F,
                          )
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      _hasLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          const Color(
                        0xFFE9783F,
                      ),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$likes',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFFC95D2E),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ==================================================
            // COMENTARIOS
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(30),
                border: Border.all(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color:
                        Color(0xFFC95D2E),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$comments',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFFC95D2E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // COMENTARIOS
  // ============================================================

  Widget _buildComments() {
    if (_publicationId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        const Text(
          '💬 Comentarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC95D2E),
          ),
        ),

        const SizedBox(height: 10),

        // ======================================================
        // ESCRIBIR COMENTARIO
        // ======================================================

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller:
                    _commentController,
                minLines: 1,
                maxLines: 4,
                enabled:
                    !_sendingComment,
                decoration:
                    InputDecoration(
                  hintText:
                      'Escribe un comentario...',
                  filled: true,
                  fillColor:
                      Colors.white,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        BorderSide(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        BorderSide(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Container(
              decoration:
                  const BoxDecoration(
                color: Color(0xFFE9783F),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed:
                    _sendingComment
                        ? null
                        : _sendComment,
                icon: _sendingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color:
                            Colors.white,
                      ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ======================================================
        // LISTA DE COMENTARIOS
        // ======================================================

        StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('publicaciones')
              .doc(_publicationId)
              .collection('comentarios')
              .orderBy(
                'fecha',
                descending: true,
              )
              .snapshots(),
          builder:
              (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Padding(
                padding:
                    EdgeInsets.all(20),
                child: Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        Color(0xFFE9783F),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(16),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Text(
                  'No se pudieron cargar los comentarios.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              );
            }

            final docs =
                snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(16),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Text(
                  'Todavía no hay comentarios. '
                  '¡Sé el primero en comentar! 🍳',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              );
            }

            return Column(
              children:
                  docs.map((doc) {
                final data =
                    doc.data();

                final userName =
                    data['usuarioNombre']
                            ?.toString() ??
                        'Usuario';

                final text =
                    data['texto']
                            ?.toString() ??
                        '';

                return Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    boxShadow:
                        const [
                      BoxShadow(
                        color:
                            Colors.black12,
                        blurRadius: 4,
                        offset:
                            Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            Color(0xFFFFE8E0),
                        child: Icon(
                          Icons.person,
                          color:
                              Color(0xFFE9783F),
                          size: 20,
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              userName,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(0xFFC95D2E),
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              text,
                              style:
                                  const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
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
        backgroundColor:
            const Color(0xFFE9783F),
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

      backgroundColor:
          const Color(0xFFFFF8F0),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // FOTO SI ESTÁ PUBLICADA
            //
            // IMPORTANTE:
            // Ya no dependemos de _publication != null.
            // _buildPublicationPhoto() buscará primero la foto
            // en publicaciones y después en widget.recipe.
            // ==================================================

            if (_isPublished &&
                !_loadingPublication) ...[
              _buildPublicationPhoto(),

              _buildSocialSection(),

              const SizedBox(height: 24),
            ],

            // ==================================================
            // NOMBRE
            // ==================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFFE9783F),
                borderRadius:
                    BorderRadius.circular(12),
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
                      style:
                          const TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
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
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFFC95D2E),
              ),
            ),

            const SizedBox(height: 8),

            ...widget.ingredients.map(
              (ing) => Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 4,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 8,
                      color:
                          Color(0xFFE9783F),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        ing,
                        style:
                            const TextStyle(
                          fontSize: 16,
                        ),
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
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFFC95D2E),
              ),
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                boxShadow:
                    const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset:
                        Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.instructions,
                style:
                    const TextStyle(
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
              child:
                  ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFFE9783F,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 14,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                ),
                label: const Text(
                  '👩‍🍳 Modo Cocinar',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed:
                    _openCookingMode,
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // GUARDAR
            // ==================================================

            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                style:
                    OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color:
                        Color(0xFFF39C12),
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 14,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              Color(0xFFF39C12),
                        ),
                      )
                    : Icon(
                        _isAlreadySaved
                            ? Icons.favorite
                            : Icons
                                .favorite_border,
                        color:
                            const Color(
                          0xFFF39C12,
                        ),
                      ),
                label: Text(
                  _isAlreadySaved
                      ? 'Guardada en favoritos'
                      : 'Guardar receta',
                  style:
                      const TextStyle(
                    color:
                        Color(0xFFF39C12),
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                onPressed:
                    _isSaving
                        ? null
                        : _toggleSaveRecipe,
              ),
            ),

            // ==================================================
            // COMENTARIOS SOLO PUBLICADA
            // ==================================================

            if (_isPublished &&
                _publicationId != null)
              _buildComments(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}