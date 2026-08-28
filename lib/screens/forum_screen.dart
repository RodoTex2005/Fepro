import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'step_by_step_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // OBTENER RECETAS PUBLICADAS EN EL FORO
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRecetas() {
    return _firestore
        .collection('recetas')
        .where(
          'publicadaEnForo',
          isEqualTo: true,
        )
        .orderBy(
          'fechaPublicacionForo',
          descending: true,
        )
        .snapshots();
  }

  // ============================================================
  // OBTENER NOMBRE DEL USUARIO
  // ============================================================

  Future<String> _getNombreUsuario(String uid) async {
    try {
      if (uid.isEmpty) {
        return 'Usuario';
      }

      final documento = await _firestore
          .collection('usuarios')
          .doc(uid)
          .get();

      if (documento.exists) {
        final datos = documento.data();

        return datos?['usuario']?.toString() ??
            datos?['nombre']?.toString() ??
            'Usuario';
      }

      return 'Usuario';
    } catch (e) {
      debugPrint(
        'ERROR AL OBTENER NOMBRE DEL USUARIO: $e',
      );

      return 'Usuario';
    }
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  String _formatFecha(dynamic fecha) {
    if (fecha == null) {
      return 'Fecha desconocida';
    }

    DateTime? fechaDateTime;

    if (fecha is Timestamp) {
      fechaDateTime = fecha.toDate();
    } else if (fecha is DateTime) {
      fechaDateTime = fecha;
    }

    if (fechaDateTime == null) {
      return 'Fecha desconocida';
    }

    final dia =
        fechaDateTime.day.toString().padLeft(2, '0');

    final mes =
        fechaDateTime.month.toString().padLeft(2, '0');

    final anio =
        fechaDateTime.year;

    final hora =
        fechaDateTime.hour.toString().padLeft(2, '0');

    final minuto =
        fechaDateTime.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio · $hora:$minuto';
  }

  // ============================================================
  // ABRIR DETALLE
  // ============================================================

  void _openRecipeDetail(
    Map<String, dynamic> receta,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          receta: receta,
          onLike: () {},
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
      backgroundColor:
          const Color(0xFFFFF8F0),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _getRecetas(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2ECC71),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),

                child: Text(
                  'Error al cargar las recetas:\n'
                  '${snapshot.error}',

                  textAlign:
                      TextAlign.center,

                  style:
                      const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          final documentos =
              snapshot.data?.docs ?? [];

          if (documentos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 70,
                    color:
                        Color(0xFF2ECC71),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Todavía no hay recetas publicadas.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Genera una receta con Amelia '
                    'y publícala en el foro.',
                    textAlign:
                        TextAlign.center,

                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(12),

            itemCount:
                documentos.length,

            itemBuilder:
                (context, index) {
              final documento =
                  documentos[index];

              final datos =
                  documento.data();

              final uid =
                  datos['uid']?.toString() ??
                      '';

              final fecha =
                  _formatFecha(
                datos['fechaPublicacionForo'],
              );

              final receta =
                  <String, dynamic>{
                'id': documento.id,

                'uid': uid,

                'titulo':
                    datos['nombre'] ??
                        'Receta sin nombre',

                'descripcion':
                    datos['descripcion'] ??
                        '',

                'ingredientes':
                    datos['ingredients']
                            is List
                        ? List<String>.from(
                            datos['ingredients'],
                          )
                        : <String>[],

                'preparacion':
                    datos['preparation']
                            is List
                        ? List<String>.from(
                            datos['preparation'],
                          )
                        : <String>[],

                'servings':
                    datos['servings'],

                'time':
                    datos['time'] ?? '',

                'difficulty':
                    datos['difficulty'] ??
                        '',

                'advice':
                    datos['advice'] ?? '',

                'finalMessage':
                    datos['finalMessage'] ??
                        '',

                'autor':
                    'Usuario',

                'fecha':
                    fecha,

                'likes':
                    datos['likes'] ?? 0,

                'liked':
                    false,

                'comentarios':
                    datos['comentarios'] ?? 0,
              };

              return Card(
                elevation: 4,

                margin:
                    const EdgeInsets.only(
                  bottom: 16,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),

                  onTap: () =>
                      _openRecipeDetail(
                    receta,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Padding(
                        padding:
                            const EdgeInsets
                                .all(16),

                        child:
                            FutureBuilder<
                                String>(
                          future:
                              _getNombreUsuario(
                            uid,
                          ),

                          builder: (
                            context,
                            userSnapshot,
                          ) {
                            final nombre =
                                userSnapshot
                                        .data ??
                                    'Usuario';

                            receta['autor'] =
                                nombre;

                            return Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      const Color(
                                    0xFF2ECC71,
                                  ),

                                  child:
                                      Text(
                                    nombre
                                            .isNotEmpty
                                        ? nombre[0]
                                            .toUpperCase()
                                        : 'U',

                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [
                                      Text(
                                        nombre,

                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize:
                                              16,
                                        ),
                                      ),

                                      Text(
                                        fecha,

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.grey,
                                          fontSize:
                                              12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      Container(
                        height: 180,

                        decoration:
                            const BoxDecoration(
                          gradient:
                              LinearGradient(
                            colors: [
                              Color(
                                0xFF2ECC71,
                              ),
                              Color(
                                0xFF27AE60,
                              ),
                            ],
                          ),
                        ),

                        child: Center(
                          child: Icon(
                            Icons.restaurant,

                            size: 60,

                            color: Colors
                                .white
                                .withOpacity(
                              0.8,
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .all(16),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Text(
                              receta[
                                  'titulo'],

                              style:
                                  const TextStyle(
                                fontSize:
                                    18,

                                fontWeight:
                                    FontWeight
                                        .bold,

                                color:
                                    Color(
                                  0xFF27AE60,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            if (receta[
                                    'descripcion']
                                .toString()
                                .isNotEmpty)
                              Text(
                                receta[
                                    'descripcion'],

                                maxLines: 3,

                                overflow:
                                    TextOverflow
                                        .ellipsis,

                                style:
                                    const TextStyle(
                                  color:
                                      Colors.grey,

                                  fontSize:
                                      14,

                                  height:
                                      1.4,
                                ),
                              ),

                            const SizedBox(
                              height: 12,
                            ),

                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        12,
                                    vertical:
                                        6,
                                  ),

                                  decoration:
                                      BoxDecoration(
                                    color: Colors
                                        .grey
                                        .withOpacity(
                                      0.1,
                                    ),

                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      20,
                                    ),
                                  ),

                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons
                                            .favorite_border,
                                        color:
                                            Colors.grey,
                                        size:
                                            20,
                                      ),

                                      const SizedBox(
                                        width: 4,
                                      ),

                                      Text(
                                        '${receta['likes']}',

                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.grey,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 16,
                                ),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .chat_bubble_outline,

                                      size:
                                          20,

                                      color:
                                          Colors.grey,
                                    ),

                                    const SizedBox(
                                      width: 4,
                                    ),

                                    Text(
                                      '${receta['comentarios']}',

                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                IconButton(
                                  icon:
                                      const Icon(
                                    Icons
                                        .share_outlined,
                                  ),

                                  onPressed:
                                      () {
                                    ScaffoldMessenger
                                            .of(
                                      context,
                                    )
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text(
                                          '📤 Receta compartida',
                                        ),
                                        backgroundColor:
                                            Color(
                                          0xFF2ECC71,
                                        ),
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
          );
        },
      ),
    );
  }
}

// ================================================================
// PANTALLA DE DETALLE DE RECETA
// ================================================================

class RecipeDetailScreen
    extends StatefulWidget {
  final Map<String, dynamic> receta;

  final VoidCallback onLike;

  const RecipeDetailScreen({
    super.key,
    required this.receta,
    required this.onLike,
  });

  @override
  State<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState
    extends State<RecipeDetailScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController
      _commentController =
      TextEditingController();

  bool _enviandoComentario = false;

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  String _formatFecha(dynamic fecha) {
    if (fecha == null) {
      return 'Fecha desconocida';
    }

    DateTime? fechaDateTime;

    if (fecha is Timestamp) {
      fechaDateTime = fecha.toDate();
    } else if (fecha is DateTime) {
      fechaDateTime = fecha;
    }

    if (fechaDateTime == null) {
      return 'Fecha desconocida';
    }

    final dia =
        fechaDateTime.day.toString().padLeft(2, '0');

    final mes =
        fechaDateTime.month.toString().padLeft(2, '0');

    final anio =
        fechaDateTime.year;

    final hora =
        fechaDateTime.hour.toString().padLeft(2, '0');

    final minuto =
        fechaDateTime.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio · $hora:$minuto';
  }

  // ============================================================
  // REFERENCIA A LOS COMENTARIOS
  // ============================================================

  CollectionReference<Map<String, dynamic>>
      _comentariosRef() {
    final recetaId =
        widget.receta['id']?.toString() ?? '';

    return _firestore
        .collection('recetas')
        .doc(recetaId)
        .collection('comentarios');
  }

  // ============================================================
  // OBTENER COMENTARIOS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _getComentarios() {
    return _comentariosRef()
        .orderBy(
          'fechaComentario',
          descending: false,
        )
        .snapshots();
  }

  @override
  void dispose() {
    _commentController.dispose();

    super.dispose();
  }

  // ============================================================
  // DAR / QUITAR LIKE
  // ============================================================

  Future<void> _toggleLike() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Debes iniciar sesión para dar like',
            ),
            backgroundColor:
                Color(0xFFF39C12),
          ),
        );

        return;
      }

      final recetaId =
          widget.receta['id']?.toString();

      if (recetaId == null ||
          recetaId.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '❌ No se encontró el ID de la receta',
            ),
            backgroundColor:
                Colors.red,
          ),
        );

        return;
      }

      // ==========================================================
      // OBTENER UID DEL AUTOR DE LA RECETA
      // ==========================================================

      final autorUid =
          widget.receta['uid']?.toString();

      if (autorUid == null ||
          autorUid.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '❌ No se encontró el autor de la receta',
            ),
            backgroundColor:
                Colors.red,
          ),
        );

        return;
      }

      final recetaRef = _firestore
          .collection('recetas')
          .doc(recetaId);

      final autorRef = _firestore
          .collection('usuarios')
          .doc(autorUid);

      final likeRef = recetaRef
          .collection('likes')
          .doc(user.uid);

      final likeSnapshot =
          await likeRef.get();

      // ==========================================================
      // QUITAR LIKE
      // ==========================================================

      if (likeSnapshot.exists) {
        await likeRef.delete();

        await recetaRef.update({
          'likes':
              FieldValue.increment(-1),
        });

        // Restar un like recibido al autor
        await autorRef.update({
          'likesRecibidos':
              FieldValue.increment(-1),
        });

        if (!mounted) return;

        setState(() {
          final likesActuales =
              (widget.receta['likes'] ?? 0)
                  as num;

          widget.receta['likes'] =
              likesActuales > 0
                  ? likesActuales - 1
                  : 0;

          widget.receta['liked'] =
              false;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '💔 Like eliminado',
            ),
            backgroundColor:
                Color(0xFFF39C12),
          ),
        );

        return;
      }

      // ==========================================================
      // DAR LIKE
      // ==========================================================

      await likeRef.set({
        'uid': user.uid,
        'fechaLike':
            FieldValue.serverTimestamp(),
      });

      await recetaRef.update({
        'likes':
            FieldValue.increment(1),
      });

      // Sumar un like recibido al autor
      await autorRef.update({
        'likesRecibidos':
            FieldValue.increment(1),
      });

      if (!mounted) return;

      setState(() {
        final likesActuales =
            (widget.receta['likes'] ?? 0)
                as num;

        widget.receta['likes'] =
            likesActuales + 1;

        widget.receta['liked'] =
            true;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '❤️ Like añadido',
          ),
          backgroundColor:
              Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL DAR LIKE: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo actualizar el like: $e',
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CARGAR ESTADO DEL LIKE
  // ============================================================

  Future<void> _loadLikeStatus() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final recetaId =
          widget.receta['id']?.toString();

      if (recetaId == null ||
          recetaId.isEmpty) {
        return;
      }

      final likeSnapshot =
          await _firestore
              .collection('recetas')
              .doc(recetaId)
              .collection('likes')
              .doc(user.uid)
              .get();

      if (!mounted) return;

      setState(() {
        widget.receta['liked'] =
            likeSnapshot.exists;
      });
    } catch (e) {
      debugPrint(
        'ERROR AL CARGAR ESTADO DEL LIKE: $e',
      );
    }
  }

  // ============================================================
  // AGREGAR COMENTARIO
  // ============================================================

  Future<void> _addComment() async {
    final text =
        _commentController.text.trim();

    if (text.isEmpty) {
      return;
    }

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Debes iniciar sesión para comentar',
            ),
            backgroundColor:
                Color(0xFFF39C12),
          ),
        );

        return;
      }

      final recetaId =
          widget.receta['id']?.toString();

      if (recetaId == null ||
          recetaId.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '❌ No se encontró el ID de la receta',
            ),
            backgroundColor:
                Colors.red,
          ),
        );

        return;
      }

      if (_enviandoComentario) {
        return;
      }

      setState(() {
        _enviandoComentario = true;
      });

      String nombreUsuario = 'Usuario';

      try {
        final usuarioDoc =
            await _firestore
                .collection('usuarios')
                .doc(user.uid)
                .get();

        if (usuarioDoc.exists) {
          final datos =
              usuarioDoc.data();

          nombreUsuario =
              datos?['usuario']
                      ?.toString() ??
                  datos?['nombre']
                      ?.toString() ??
                  'Usuario';
        }
      } catch (e) {
        debugPrint(
          'ERROR AL OBTENER NOMBRE PARA COMENTARIO: $e',
        );
      }

      final recetaRef = _firestore
          .collection('recetas')
          .doc(recetaId);

      await recetaRef
          .collection('comentarios')
          .add({
        'uid': user.uid,
        'usuario': nombreUsuario,
        'texto': text,
        'fechaComentario':
            FieldValue.serverTimestamp(),
      });

      await recetaRef.update({
        'comentarios':
            FieldValue.increment(1),
      });

      _commentController.clear();

      if (!mounted) return;

      setState(() {
        _enviandoComentario = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('💬 Comentario añadido'),
          backgroundColor:
              Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL AGREGAR COMENTARIO: $e',
      );

      if (!mounted) return;

      setState(() {
        _enviandoComentario = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo agregar el comentario: $e',
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ELIMINAR COMENTARIO
  // ============================================================

  Future<void> _deleteComment(
    String comentarioId,
  ) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final recetaId =
          widget.receta['id']?.toString();

      if (recetaId == null ||
          recetaId.isEmpty) {
        return;
      }

      final comentarioRef = _firestore
          .collection('recetas')
          .doc(recetaId)
          .collection('comentarios')
          .doc(comentarioId);

      final comentario =
          await comentarioRef.get();

      if (!comentario.exists) {
        return;
      }

      final datos =
          comentario.data();

      if (datos?['uid']?.toString() !=
          user.uid) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Solo puedes eliminar tus propios comentarios',
            ),
            backgroundColor:
                Color(0xFFF39C12),
          ),
        );

        return;
      }

      await comentarioRef.delete();

      await _firestore
          .collection('recetas')
          .doc(recetaId)
          .update({
        'comentarios':
            FieldValue.increment(-1),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('🗑️ Comentario eliminado'),
          backgroundColor:
              Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL ELIMINAR COMENTARIO: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo eliminar el comentario: $e',
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CONFIRMAR ELIMINACIÓN
  // ============================================================

  void _confirmDeleteComment(
    String comentarioId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar comentario',
          ),

          content: const Text(
            '¿Seguro que quieres eliminar este comentario?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child: const Text(
                'Cancelar',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                _deleteComment(
                  comentarioId,
                );
              },

              child: const Text(
                'Eliminar',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // GUARDAR RECETA
  // ============================================================

  Future<void> _saveRecipe() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Debes iniciar sesión para guardar recetas',
            ),
            backgroundColor:
                Color(0xFFF39C12),
          ),
        );

        return;
      }

      final recetaId =
          widget.receta['id'];

      if (recetaId == null ||
          recetaId.toString().isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '❌ No se encontró el ID de la receta',
            ),
            backgroundColor:
                Colors.red,
          ),
        );

        return;
      }

      final guardadaQuery =
          await _firestore
              .collection(
                  'recetas_guardadas')
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

      if (guardadaQuery
          .docs.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Esta receta ya está en favoritos',
            ),
            backgroundColor:
                Color(0xFFF39C12),
          ),
        );

        return;
      }

      await _firestore
          .collection('recetas_guardadas')
          .add({
        'uid': user.uid,
        'recetaId': recetaId,
        'fechaGuardado':
            FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'recetasGuardadas':
            FieldValue.increment(1),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '❤️ Receta guardada en favoritos',
          ),
          backgroundColor:
              Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      debugPrint(
        'ERROR AL GUARDAR RECETA: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo guardar la receta: $e',
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // MODO COCINAR
  // ============================================================

  void _goToCookingMode() {
    final ingredientes =
        List<String>.from(
      widget.receta['ingredientes'] ??
          [],
    );

    final instrucciones =
        List<String>.from(
      widget.receta['preparacion'] ??
          [],
    ).join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StepByStepScreen(
          recipeName:
              widget.receta['titulo'] ??
                  'Receta',

          ingredients:
              ingredientes,

          instructions:
              instrucciones,
          
          // Pasamos la receta completa
          recipe: widget.receta
        ),
      ),
    );
  }

  // ============================================================
  // INTERFAZ DETALLE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final receta =
        widget.receta;

    final ingredientes =
        List<String>.from(
      receta['ingredientes'] ?? [],
    );

    final instrucciones =
        List<String>.from(
      receta['preparacion'] ?? [],
    ).join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RECETAS PARA TI',

          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
            fontSize: 18,
          ),
        ),

        centerTitle: true,

        backgroundColor:
            const Color(0xFF2ECC71),

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

      body: FutureBuilder<void>(
        future: _loadLikeStatus(),

        builder: (
          context,
          likeSnapshot,
        ) {
          return SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          const Color(
                        0xFF2ECC71,
                      ),

                      child: Text(
                        receta['autor']
                                .toString()
                                .isNotEmpty
                            ? receta['autor']
                                .toString()[0]
                                .toUpperCase()
                            : 'U',

                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Text(
                          receta['autor'] ??
                              'Usuario',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        Text(
                          receta['fecha'] ??
                              'Fecha desconocida',

                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                Text(
                  receta['titulo'],

                  style:
                      const TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF27AE60),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  receta['descripcion'],

                  style:
                      const TextStyle(
                    fontSize: 16,
                    color:
                        Colors.grey,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  '🥘 Ingredientes:',

                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF27AE60),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                ...ingredientes.map(
                  (ing) => Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 4,
                    ),

                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color:
                              Color(0xFF2ECC71),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text(
                            ing,

                            style:
                                const TextStyle(
                              fontSize:
                                  16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  '👩‍🍳 Instrucciones:',

                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF27AE60),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .all(16),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),

                    boxShadow: const [
                      BoxShadow(
                        color:
                            Colors.black12,
                        blurRadius: 8,
                        offset:
                            Offset(0, 2),
                      ),
                    ],
                  ),

                  child: Text(
                    instrucciones,

                    style:
                        const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

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
                            vertical:
                                14,
                          ),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),

                        icon:
                            const Icon(
                          Icons.restaurant,
                          color:
                              Colors.white,
                        ),

                        label:
                            const Text(
                          'Modo Cocinar',

                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        onPressed:
                            _goToCookingMode,
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child:
                          ElevatedButton
                              .icon(
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              receta['liked'] ==
                                      true
                                  ? Colors.red
                                  : Colors.white,

                          foregroundColor:
                              receta['liked'] ==
                                      true
                                  ? Colors.white
                                  : Colors.red,

                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical:
                                14,
                          ),

                          elevation: 0,

                          side:
                              const BorderSide(
                            color:
                                Colors.red,
                          ),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),

                        icon:
                            Icon(
                          receta['liked'] ==
                                  true
                              ? Icons.favorite
                              : Icons
                                  .favorite_border,
                        ),

                        label:
                            Text(
                          '${receta['likes'] ?? 0}',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        onPressed:
                            _toggleLike,
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
                            vertical:
                                14,
                          ),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),

                        icon:
                            const Icon(
                          Icons
                              .bookmark_border,
                          color:
                              Color(
                            0xFFF39C12,
                          ),
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

                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        onPressed:
                            _saveRecipe,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  '💬 Comentarios:',

                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF27AE60),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream:
                      _getComentarios(),

                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return Container(
                        padding:
                            const EdgeInsets
                                .all(12),

                        child: Text(
                          'Error al cargar comentarios:\n'
                          '${snapshot.error}',

                          style:
                              const TextStyle(
                            color:
                                Colors.red,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState ==
                            ConnectionState
                                .waiting &&
                        !snapshot.hasData) {
                      return const Padding(
                        padding:
                            EdgeInsets.all(
                          12,
                        ),

                        child:
                            Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                Color(
                              0xFF2ECC71,
                            ),
                          ),
                        ),
                      );
                    }

                    final comentarios =
                        snapshot.data
                                ?.docs ??
                            [];

                    if (comentarios.isEmpty) {
                      return const Padding(
                        padding:
                            EdgeInsets
                                .symmetric(
                          vertical: 12,
                        ),

                        child: Text(
                          'Todavía no hay comentarios.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children:
                          comentarios.map(
                        (documento) {
                          final datos =
                              documento
                                  .data();

                          final usuario =
                              datos['usuario']
                                      ?.toString() ??
                                  'Usuario';

                          final texto =
                              datos['texto']
                                      ?.toString() ??
                                  '';

                          final uidComentario =
                              datos['uid']
                                      ?.toString() ??
                                  '';

                          final fechaComentario =
                              _formatFecha(
                            datos[
                                'fechaComentario'],
                          );

                          final usuarioActual =
                              FirebaseAuth
                                  .instance
                                  .currentUser
                                  ?.uid;

                          final esMio =
                              usuarioActual !=
                                      null &&
                                  usuarioActual ==
                                      uidComentario;

                          return Container(
                            width:
                                double.infinity,

                            padding:
                                const EdgeInsets
                                    .all(
                              12,
                            ),

                            margin:
                                const EdgeInsets
                                    .only(
                              bottom: 8,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),

                              boxShadow: const [
                                BoxShadow(
                                  color:
                                      Colors.black12,
                                  blurRadius:
                                      4,
                                  offset:
                                      Offset(
                                    0,
                                    2,
                                  ),
                                ),
                              ],
                            ),

                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                CircleAvatar(
                                  radius:
                                      20,

                                  backgroundColor:
                                      const Color(
                                    0xFF2ECC71,
                                  ),

                                  child:
                                      Text(
                                    usuario
                                            .isNotEmpty
                                        ? usuario[0]
                                            .toUpperCase()
                                        : 'U',

                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                Text(
                                              usuario,

                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                fontSize:
                                                    15,
                                              ),
                                            ),
                                          ),

                                          if (esMio)
                                            PopupMenuButton<
                                                String>(
                                              padding:
                                                  EdgeInsets.zero,

                                              icon:
                                                  const Icon(
                                                Icons
                                                    .more_vert,
                                                size:
                                                    20,
                                                color:
                                                    Colors.grey,
                                              ),

                                              onSelected:
                                                  (
                                                opcion,
                                              ) {
                                                if (opcion ==
                                                    'eliminar') {
                                                  _confirmDeleteComment(
                                                    documento
                                                        .id,
                                                  );
                                                }
                                              },

                                              itemBuilder:
                                                  (
                                                context,
                                              ) =>
                                                  const [
                                                PopupMenuItem<
                                                    String>(
                                                  value:
                                                      'eliminar',

                                                  child:
                                                      Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .delete_outline,
                                                        color:
                                                            Colors.red,
                                                      ),

                                                      SizedBox(
                                                        width:
                                                            8,
                                                      ),

                                                      Text(
                                                        'Eliminar',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),

                                      if (fechaComentario !=
                                          'Fecha desconocida')
                                        Text(
                                          fechaComentario,

                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.grey,
                                            fontSize:
                                                11,
                                          ),
                                        ),

                                      const SizedBox(
                                        height: 5,
                                      ),

                                      Text(
                                        texto,

                                        style:
                                            const TextStyle(
                                          fontSize:
                                              14,
                                          height:
                                              1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList(),
                    );
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,

                  children: [
                    Expanded(
                      child: TextField(
                        controller:
                            _commentController,

                        minLines: 1,

                        maxLines: 4,

                        textInputAction:
                            TextInputAction
                                .newline,

                        decoration:
                            InputDecoration(
                          hintText:
                              'Escribe un comentario...',

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),

                            borderSide:
                                BorderSide.none,
                          ),

                          filled:
                              true,

                          fillColor:
                              Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Container(
                      decoration:
                          const BoxDecoration(
                        color:
                            Color(
                          0xFF2ECC71,
                        ),

                        shape:
                            BoxShape.circle,
                      ),

                      child:
                          IconButton(
                        icon:
                            _enviandoComentario
                                ? const SizedBox(
                                    width:
                                        20,
                                    height:
                                        20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color:
                                        Colors.white,
                                  ),

                        onPressed:
                            _enviandoComentario
                                ? null
                                : _addComment,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}