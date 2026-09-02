import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'step_by_step_screen.dart';
import '../utils/share_utils.dart'; // Importación para compartir

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // OBTENER RECETAS PUBLICADAS EN EL FORO
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRecetas() {
    return _firestore
        .collection('recetas')
        .where('publicadaEnForo', isEqualTo: true)
        .orderBy('fechaPublicacionForo', descending: true)
        .snapshots();
  }

  // ============================================================
  // OBTENER DATOS DEL USUARIO
  // ============================================================

  Future<Map<String, String>> _getDatosUsuario(String uid) async {
    try {
      if (uid.isEmpty) {
        return {'nombre': 'Usuario', 'fotoPerfil': ''};
      }

      final documento = await _firestore
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
  // VERIFICAR SI EL USUARIO YA DIO LIKE
  // ============================================================

  Future<bool> _checkIfLiked(String recetaId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final likeDoc = await FirebaseFirestore.instance
          .collection('recetas')
          .doc(recetaId)
          .collection('likes')
          .doc(user.uid)
          .get();

      return likeDoc.exists;
    } catch (e) {
      debugPrint('Error al verificar like: $e');
      return false;
    }
  }

  // ============================================================
  // DAR / QUITAR LIKE DESDE EL FORO
  // ============================================================

  Future<void> _toggleLikeFromForum({
    required String recetaId,
    required String autorUid,
    required int currentLikes,
    required bool isLiked,
    required Function(int, bool) onSuccess,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Debes iniciar sesión para dar like'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final recetaRef = firestore.collection('recetas').doc(recetaId);
      final autorRef = firestore.collection('usuarios').doc(autorUid);
      final likeRef = recetaRef.collection('likes').doc(user.uid);

      final likeSnapshot = await likeRef.get();

      if (likeSnapshot.exists) {
        // Quitar like
        await likeRef.delete();
        await recetaRef.update({'likes': FieldValue.increment(-1)});
        await autorRef.update({'likesRecibidos': FieldValue.increment(-1)});

        final newLikes = currentLikes > 0 ? currentLikes - 1 : 0;
        onSuccess(newLikes, false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💔 Like eliminado'),
            backgroundColor: Color(0xFFF39C12),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        // Dar like
        await likeRef.set({
          'uid': user.uid,
          'fechaLike': FieldValue.serverTimestamp(),
        });
        await recetaRef.update({'likes': FieldValue.increment(1)});
        await autorRef.update({'likesRecibidos': FieldValue.increment(1)});

        onSuccess(currentLikes + 1, true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❤️ Like añadido'),
            backgroundColor: Color(0xFFE9783F),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('ERROR AL DAR LIKE DESDE FORO: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al procesar like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ABRIR DETALLE
  // ============================================================

  void _openRecipeDetail(Map<String, dynamic> receta) {
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
      backgroundColor: const Color(0xFFFFF8F0),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getRecetas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE9783F),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error al cargar las recetas:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final documentos = snapshot.data?.docs ?? [];

          if (documentos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 70,
                    color: Color(0xFFE9783F),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Todavía no hay recetas publicadas.',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Genera una receta con Amelia y publícala en el foro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documentos.length,
            itemBuilder: (context, index) {
              final documento = documentos[index];
              final datos = documento.data();

              final uid = datos['uid']?.toString() ?? '';
              final fecha = _formatFecha(datos['fechaPublicacionForo']);

              final receta = <String, dynamic>{
                'id': documento.id,
                'recetaId': documento.id,
                'uid': uid,
                'titulo': datos['nombre'] ?? 'Receta sin nombre',
                'descripcion': datos['descripcion'] ?? '',
                'ingredientes': datos['ingredients'] is List
                    ? List<String>.from(datos['ingredients'])
                    : <String>[],
                'preparacion': datos['preparation'] is List
                    ? List<String>.from(datos['preparation'])
                    : <String>[],
                'servings': datos['servings'],
                'time': datos['time'] ?? '',
                'difficulty': datos['difficulty'] ?? '',
                'advice': datos['advice'] ?? '',
                'finalMessage': datos['finalMessage'] ?? '',
                'autor': 'Usuario',
                'fecha': fecha,
                'likes': datos['likes'] ?? 0,
                'liked': false,
                'comentarios': datos['comentarios'] ?? 0,
                'fotoPlatilloUrl': datos['fotoPlatilloUrl'] ?? '',
              };

              return FutureBuilder<bool>(
                future: _checkIfLiked(receta['id']),
                builder: (context, likeSnapshot) {
                  final isLiked = likeSnapshot.data ?? false;
                  receta['liked'] = isLiked;

                  return ForumRecipeCard(
                    receta: receta,
                    onTap: () => _openRecipeDetail(receta),
                    onLike: () async {
                      // Obtener el estado actual antes de cambiar
                      final currentLikes = receta['likes'] ?? 0;
                      final currentLiked = receta['liked'] ?? false;

                      await _toggleLikeFromForum(
                        recetaId: receta['id'],
                        autorUid: receta['uid'],
                        currentLikes: currentLikes,
                        isLiked: currentLiked,
                        onSuccess: (newLikes, newLiked) {
                          setState(() {
                            receta['likes'] = newLikes;
                            receta['liked'] = newLiked;
                          });
                        },
                      );
                    },
                    onShare: () {
                      ShareUtils.shareRecipe(receta);
                    },
                  );
                },
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _enviandoComentario = false;
  File? _fotoComentario;

  // ============================================================
  // OBTENER DATOS DEL USUARIO
  // ============================================================

  Future<Map<String, String>> _getDatosUsuario(String uid) async {
    try {
      if (uid.isEmpty) {
        return {'nombre': 'Usuario', 'fotoPerfil': ''};
      }

      final documento = await _firestore
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
  // REFERENCIA A LOS COMENTARIOS
  // ============================================================

  CollectionReference<Map<String, dynamic>> _comentariosRef() {
    final recetaId = widget.receta['id']?.toString() ?? '';
    return _firestore
        .collection('recetas')
        .doc(recetaId)
        .collection('comentarios');
  }

  // ============================================================
  // OBTENER COMENTARIOS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _getComentarios() {
    return _comentariosRef()
        .orderBy('fechaComentario', descending: false)
        .snapshots();
  }

  // ============================================================
  // MOSTRAR EMOJIS
  // ============================================================

  void _mostrarEmojis() {
    final emojis = [
      '😀',
      '😂',
      '😍',
      '🥰',
      '😋',
      '🤤',
      '😎',
      '😭',
      '😡',
      '🤯',
      '❤️',
      '🔥',
      '👏',
      '👍',
      '👎',
      '🙌',
      '💯',
      '✨',
      '🎉',
      '🥳',
      '🍕',
      '🍔',
      '🍗',
      '🌮',
      '🍰',
      '🍪',
      '☕',
      '👩‍🍳',
      '👨‍🍳',
      '🥘',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final textoActual = _commentController.text;
                    _commentController.text = '$textoActual$emoji';
                    _commentController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _commentController.text.length),
                    );
                    Navigator.pop(context);
                  },
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // TOMAR FOTO CON LA CÁMARA
  // ============================================================

  Future<void> _tomarFotoComentario() async {
    try {
      final XFile? imagen = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (imagen == null) return;
      if (!mounted) return;
      setState(() {
        _fotoComentario = File(imagen.path);
      });
    } catch (e) {
      debugPrint('ERROR AL TOMAR FOTO DEL COMENTARIO: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo abrir la cámara: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // QUITAR FOTO SELECCIONADA
  // ============================================================

  void _quitarFotoComentario() {
    setState(() {
      _fotoComentario = null;
    });
  }

  // ============================================================
  // SUBIR FOTO DEL COMENTARIO
  // ============================================================

  Future<String?> _subirFotoComentario(File foto, String comentarioId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final referencia = FirebaseStorage.instance
          .ref()
          .child('comentarios/${widget.receta['id']}/${user.uid}/$comentarioId.jpg');

      await referencia.putFile(foto);
      final url = await referencia.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('ERROR AL SUBIR FOTO DEL COMENTARIO: $e');
      rethrow;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Debes iniciar sesión para dar like'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      final recetaId = widget.receta['id']?.toString();
      if (recetaId == null || recetaId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontró el ID de la receta'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final autorUid = widget.receta['uid']?.toString();
      if (autorUid == null || autorUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontró el autor de la receta'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final recetaRef = _firestore.collection('recetas').doc(recetaId);
      final autorRef = _firestore.collection('usuarios').doc(autorUid);
      final likeRef = recetaRef.collection('likes').doc(user.uid);

      final likeSnapshot = await likeRef.get();

      if (likeSnapshot.exists) {
        await likeRef.delete();
        await recetaRef.update({'likes': FieldValue.increment(-1)});
        await autorRef.update({'likesRecibidos': FieldValue.increment(-1)});

        if (!mounted) return;
        setState(() {
          final likesActuales = (widget.receta['likes'] ?? 0) as num;
          widget.receta['likes'] = likesActuales > 0 ? likesActuales - 1 : 0;
          widget.receta['liked'] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💔 Like eliminado'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      await likeRef.set({
        'uid': user.uid,
        'fechaLike': FieldValue.serverTimestamp(),
      });
      await recetaRef.update({'likes': FieldValue.increment(1)});
      await autorRef.update({'likesRecibidos': FieldValue.increment(1)});

      if (!mounted) return;
      setState(() {
        final likesActuales = (widget.receta['likes'] ?? 0) as num;
        widget.receta['likes'] = likesActuales + 1;
        widget.receta['liked'] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❤️ Like añadido'),
          backgroundColor: Color(0xFFE9783F),
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL DAR LIKE: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo actualizar el like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CARGAR ESTADO DEL LIKE
  // ============================================================

  Future<void> _loadLikeStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final recetaId = widget.receta['id']?.toString();
      if (recetaId == null || recetaId.isEmpty) return;

      final likeSnapshot = await _firestore
          .collection('recetas')
          .doc(recetaId)
          .collection('likes')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      setState(() {
        widget.receta['liked'] = likeSnapshot.exists;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR ESTADO DEL LIKE: $e');
    }
  }

  // ============================================================
  // AGREGAR COMENTARIO
  // ============================================================

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _fotoComentario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('😊 Escribe algo, agrega un emoji o toma una foto'),
          backgroundColor: Color(0xFFF39C12),
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Debes iniciar sesión para comentar'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      final recetaId = widget.receta['id']?.toString();
      if (recetaId == null || recetaId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontró el ID de la receta'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_enviandoComentario) return;

      setState(() {
        _enviandoComentario = true;
      });

      String nombreUsuario = 'Usuario';
      try {
        final usuarioDoc = await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .get();

        if (usuarioDoc.exists) {
          final datos = usuarioDoc.data();
          nombreUsuario = datos?['usuario']?.toString() ??
              datos?['nombre']?.toString() ??
              'Usuario';
        }
      } catch (e) {
        debugPrint('ERROR AL OBTENER NOMBRE PARA COMENTARIO: $e');
      }

      final recetaRef = _firestore.collection('recetas').doc(recetaId);
      final comentarioRef = recetaRef.collection('comentarios').doc();

      await comentarioRef.set({
        'uid': user.uid,
        'usuario': nombreUsuario,
        'texto': text,
        'fotoUrl': '',
        'fechaComentario': FieldValue.serverTimestamp(),
      });

      if (_fotoComentario != null) {
        final fotoUrl = await _subirFotoComentario(_fotoComentario!, comentarioRef.id);
        if (fotoUrl != null && fotoUrl.isNotEmpty) {
          await comentarioRef.update({'fotoUrl': fotoUrl});
        }
      }

      await recetaRef.update({'comentarios': FieldValue.increment(1)});

      _commentController.clear();
      if (!mounted) return;

      setState(() {
        _fotoComentario = null;
        _enviandoComentario = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💬 Comentario añadido'),
          backgroundColor: Color(0xFFE9783F),
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL AGREGAR COMENTARIO: $e');
      if (!mounted) return;
      setState(() {
        _enviandoComentario = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo agregar el comentario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ELIMINAR COMENTARIO
  // ============================================================

  Future<void> _deleteComment(String comentarioId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final recetaId = widget.receta['id']?.toString();
      if (recetaId == null || recetaId.isEmpty) return;

      final comentarioRef = _firestore
          .collection('recetas')
          .doc(recetaId)
          .collection('comentarios')
          .doc(comentarioId);

      final comentario = await comentarioRef.get();
      if (!comentario.exists) return;

      final datos = comentario.data();
      if (datos?['uid']?.toString() != user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Solo puedes eliminar tus propios comentarios'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      final fotoUrl = datos?['fotoUrl']?.toString() ?? '';
      if (fotoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(fotoUrl).delete();
        } catch (e) {
          debugPrint('No se pudo eliminar la foto del Storage: $e');
        }
      }

      await comentarioRef.delete();
      await _firestore.collection('recetas').doc(recetaId).update({
        'comentarios': FieldValue.increment(-1),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Comentario eliminado'),
          backgroundColor: Color(0xFFE9783F),
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL ELIMINAR COMENTARIO: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo eliminar el comentario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CONFIRMAR ELIMINACIÓN
  // ============================================================

  void _confirmDeleteComment(String comentarioId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar comentario'),
          content: const Text('¿Seguro que quieres eliminar este comentario?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteComment(comentarioId);
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Debes iniciar sesión para guardar recetas'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      final recetaId = widget.receta['id'];
      if (recetaId == null || recetaId.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontró el ID de la receta'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final guardadaQuery = await _firestore
          .collection('recetas_guardadas')
          .where('uid', isEqualTo: user.uid)
          .where('recetaId', isEqualTo: recetaId)
          .limit(1)
          .get();

      if (guardadaQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Esta receta ya está en favoritos'),
            backgroundColor: Color(0xFFF39C12),
          ),
        );
        return;
      }

      await _firestore.collection('recetas_guardadas').add({
        'uid': user.uid,
        'recetaId': recetaId,
        'fechaGuardado': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('usuarios').doc(user.uid).update({
        'recetasGuardadas': FieldValue.increment(1),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❤️ Receta guardada en favoritos'),
          backgroundColor: Color(0xFFE9783F),
        ),
      );
    } catch (e) {
      debugPrint('ERROR AL GUARDAR RECETA: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudo guardar la receta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // MODO COCINAR
  // ============================================================

  void _goToCookingMode() {
    final ingredientes = List<String>.from(widget.receta['ingredientes'] ?? []);
    final instrucciones = List<String>.from(widget.receta['preparacion'] ?? []).join('\n');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepByStepScreen(
          recipeName: widget.receta['titulo'] ?? 'Receta',
          ingredients: ingredientes,
          instructions: instrucciones,
          recipe: widget.receta,
        ),
      ),
    );
  }

  // ============================================================
  // INTERFAZ DETALLE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final receta = widget.receta;
    final ingredientes = List<String>.from(receta['ingredientes'] ?? []);
    final instrucciones = List<String>.from(receta['preparacion'] ?? []).join('\n');
    final autorUid = receta['uid']?.toString() ?? '';

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
              ShareUtils.shareRecipe(receta);
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: FutureBuilder<void>(
        future: _loadLikeStatus(),
        builder: (context, likeSnapshot) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // AUTOR
                // ==================================================

                FutureBuilder<Map<String, String>>(
                  future: _getDatosUsuario(autorUid),
                  builder: (context, userSnapshot) {
                    final datosUsuario = userSnapshot.data ?? {
                      'nombre': receta['autor']?.toString() ?? 'Usuario',
                      'fotoPerfil': '',
                    };

                    final nombre = datosUsuario['nombre'] ??
                        receta['autor']?.toString() ??
                        'Usuario';
                    final fotoPerfil = datosUsuario['fotoPerfil'] ?? '';

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFE9783F),
                          backgroundImage: fotoPerfil.isNotEmpty
                              ? NetworkImage(fotoPerfil)
                              : null,
                          onBackgroundImageError: fotoPerfil.isNotEmpty
                              ? (exception, stackTrace) {
                                  debugPrint(
                                    'ERROR AL CARGAR FOTO DE PERFIL DEL DETALLE: $exception',
                                  );
                                }
                              : null,
                          child: fotoPerfil.isEmpty
                              ? Text(
                                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              receta['fecha'] ?? 'Fecha desconocida',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ==================================================
                // FOTO FINAL EN DETALLE
                // ==================================================

                if (receta['fotoPlatilloUrl'].toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      receta['fotoPlatilloUrl'].toString(),
                      width: double.infinity,
                      height: 230,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 230,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 60,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),

                if (receta['fotoPlatilloUrl'].toString().isNotEmpty)
                  const SizedBox(height: 20),

                Text(
                  receta['titulo'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC95D2E),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  receta['descripcion'],
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  '🥘 Ingredientes:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC95D2E),
                  ),
                ),

                const SizedBox(height: 8),

                ...ingredientes.map(
                  (ing) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
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

                const Text(
                  '👩‍🍳 Instrucciones:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC95D2E),
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
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ==================================================
                // BOTONES
                // ==================================================

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE9783F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.restaurant, color: Colors.white),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: receta['liked'] == true
                              ? Colors.red
                              : Colors.white,
                          foregroundColor: receta['liked'] == true
                              ? Colors.white
                              : Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          receta['liked'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: Text(
                          '${receta['likes'] ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _toggleLike,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          Icons.bookmark_border,
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

                const Text(
                  '💬 Comentarios:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC95D2E),
                  ),
                ),

                const SizedBox(height: 8),

                // ==================================================
                // COMENTARIOS
                // ==================================================

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _getComentarios(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Error al cargar comentarios:\n${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE9783F),
                          ),
                        ),
                      );
                    }

                    final comentarios = snapshot.data?.docs ?? [];

                    if (comentarios.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Todavía no hay comentarios.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Column(
                      children: comentarios.map((documento) {
                        final datos = documento.data();
                        final usuario = datos['usuario']?.toString() ?? 'Usuario';
                        final texto = datos['texto']?.toString() ?? '';
                        final fotoUrl = datos['fotoUrl']?.toString() ?? '';
                        final uidComentario = datos['uid']?.toString() ?? '';
                        final fechaComentario = _formatFecha(datos['fechaComentario']);

                        final usuarioActual = FirebaseAuth.instance.currentUser?.uid;
                        final esMio = usuarioActual != null && usuarioActual == uidComentario;

                        return Container(
                          width: double.infinity,
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFE9783F),
                                child: Text(
                                  usuario.isNotEmpty ? usuario[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            usuario,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (esMio)
                                          PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.more_vert,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                            onSelected: (opcion) {
                                              if (opcion == 'eliminar') {
                                                _confirmDeleteComment(documento.id);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem<String>(
                                                value: 'eliminar',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('Eliminar'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    if (fechaComentario != 'Fecha desconocida')
                                      Text(
                                        fechaComentario,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    const SizedBox(height: 5),
                                    if (texto.isNotEmpty)
                                      Text(
                                        texto,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    if (fotoUrl.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) => Dialog(
                                                  backgroundColor: Colors.transparent,
                                                  child: InteractiveViewer(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      child: Image.network(
                                                        fotoUrl,
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (context, error,
                                                            stackTrace) {
                                                          return Container(
                                                            height: 200,
                                                            color: Colors.white,
                                                            child: const Center(
                                                              child: Icon(
                                                                Icons.broken_image,
                                                                size: 50,
                                                                color: Colors.grey,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Image.network(
                                              fotoUrl,
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const SizedBox(
                                                  height: 200,
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      color: Color(0xFFE9783F),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  height: 200,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      size: 50,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
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

                const SizedBox(height: 8),

                // ==================================================
                // VISTA PREVIA DE FOTO
                // ==================================================

                if (_fotoComentario != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
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
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _fotoComentario!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _quitarFotoComentario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ==================================================
                // ESCRIBIR COMENTARIO
                // ==================================================

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Text(
                          '😊',
                          style: TextStyle(fontSize: 26),
                        ),
                        onPressed: _mostrarEmojis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFFC95D2E),
                          size: 25,
                        ),
                        onPressed: _enviandoComentario ? null : _tomarFotoComentario,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Escribe un comentario...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9783F),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _enviandoComentario
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _enviandoComentario ? null : _addComment,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// TARJETA DE RECETA DEL FORO (REUTILIZABLE)
// ================================================================

class ForumRecipeCard extends StatelessWidget {
  final Map<String, dynamic> receta;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;

  const ForumRecipeCard({
    super.key,
    required this.receta,
    required this.onTap,
    this.onLike,
    this.onShare,
  });

  // ============================================================
  // OBTENER DATOS DEL USUARIO
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

  @override
  Widget build(BuildContext context) {
    final uid = receta['uid']?.toString() ?? '';
    final fecha = _formatFecha(
      receta['fechaPublicacionForo'] ?? receta['fechaCreacion'],
    );
    final titulo = receta['titulo']?.toString() ?? receta['name']?.toString() ?? 'Receta sin nombre';
    final descripcion = receta['descripcion']?.toString() ?? receta['description']?.toString() ?? '';
    final fotoPlatillo = receta['fotoPlatilloUrl']?.toString() ?? '';
    final likes = receta['likes'] ?? 0;
    final comentarios = receta['comentarios'] ?? 0;
    final isLiked = receta['liked'] ?? false;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // USUARIO
            // ==================================================

            Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<Map<String, String>>(
                future: _getDatosUsuario(uid),
                builder: (context, userSnapshot) {
                  final datosUsuario = userSnapshot.data ?? {
                    'nombre': receta['autor']?.toString() ?? 'Usuario',
                    'fotoPerfil': '',
                  };

                  final nombre = datosUsuario['nombre'] ?? 'Usuario';
                  final fotoPerfil = datosUsuario['fotoPerfil'] ?? '';

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE9783F),
                        backgroundImage: fotoPerfil.isNotEmpty
                            ? NetworkImage(fotoPerfil)
                            : null,
                        onBackgroundImageError: fotoPerfil.isNotEmpty
                            ? (exception, stackTrace) {
                                debugPrint('ERROR AL CARGAR FOTO DE PERFIL: $exception');
                              }
                            : null,
                        child: fotoPerfil.isEmpty
                            ? Text(
                                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              fecha,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
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

            // ==================================================
            // FOTO FINAL DEL PLATILLO
            // ==================================================

            if (fotoPlatillo.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(
                    fotoPlatillo,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE9783F),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE9783F), Color(0xFFC95D2E)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE9783F), Color(0xFFC95D2E)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.restaurant,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

            // ==================================================
            // INFORMACIÓN DE RECETA
            // ==================================================

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC95D2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (descripcion.isNotEmpty)
                    Text(
                      descripcion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // ==========================================
                      // BOTÓN DE LIKE (INTERACTIVO)
                      // ==========================================

                      StatefulBuilder(
                        builder: (context, setStateCard) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: onLike,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isLiked
                                    ? const Color(0xFFFFE8E0)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isLiked
                                        ? const Color(0xFFE9783F)
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$likes',
                                    style: TextStyle(
                                      color: isLiked
                                          ? const Color(0xFFE9783F)
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 16),

                      // ==========================================
                      // COMENTARIOS
                      // ==========================================

                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$comentarios',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // ==========================================
                      // BOTÓN COMPARTIR
                      // ==========================================

                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: onShare ?? () {
                          ShareUtils.shareRecipe(receta);
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
  }
}