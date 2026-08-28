import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PublishRecipeScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  // Si es true, primero muestra la invitación
  // "¿Te gustaría compartir tu resultado?"
  final bool showShareInvitation;

  const PublishRecipeScreen({
    super.key,
    required this.recipe,
    this.showShareInvitation = false,
  });

  @override
  State<PublishRecipeScreen> createState() =>
      _PublishRecipeScreenState();
}

class _PublishRecipeScreenState
    extends State<PublishRecipeScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _finalDishImage;
  bool _isPublishing = false;

  // Controla si ya se mostró la invitación
  // y se puede tomar la foto.
  late bool _showCameraSection;

  @override
  void initState() {
    super.initState();

    _showCameraSection =
        !widget.showShareInvitation;
  }

  // ============================================================
  // ABRIR CÁMARA
  // ============================================================

  Future<void> _openCamera() async {
    if (_isPublishing) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _finalDishImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir la cámara: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ABRIR GALERÍA
  // ============================================================

  Future<void> _openGallery() async {
    if (_isPublishing) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _finalDishImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir la galería: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CONTINUAR A LA PUBLICACIÓN
  // ============================================================

  void _continueToPublish() {
    if (_isPublishing) return;

    setState(() {
      _showCameraSection = true;
    });
  }

  // ============================================================
  // PUBLICAR
  // ============================================================

  Future<void> _publishRecipe() async {
    // ----------------------------------------------------------
    // COMPROBAR QUE HAYA FOTO
    // ----------------------------------------------------------

    if (_finalDishImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '📸 Primero toma una foto o elige una imagen de tu platillo final.',
          ),
          backgroundColor: Color(0xFFF39C12),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // COMPROBAR USUARIO
    // ----------------------------------------------------------

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Debes iniciar sesión para publicar.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // OBTENER ID DE RECETA
    // ----------------------------------------------------------

    final recetaId = widget.recipe['recetaId'] ??
    widget.recipe['id'];

    if (recetaId == null ||
        recetaId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ No se encontró el ID de la receta.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      // --------------------------------------------------------
      // REFERENCIA A LA RECETA
      // --------------------------------------------------------

      final recetaRef = FirebaseFirestore.instance
          .collection('recetas')
          .doc(recetaId.toString());

      // --------------------------------------------------------
      // COMPROBAR QUE LA RECETA EXISTA
      // --------------------------------------------------------

      final recetaSnapshot = await recetaRef.get();

      if (!recetaSnapshot.exists) {
        throw Exception(
          'La receta no existe en Firestore.',
        );
      }

      final datos = recetaSnapshot.data();

      // --------------------------------------------------------
      // COMPROBAR SI YA ESTÁ PUBLICADA
      // --------------------------------------------------------

      if (datos?['publicadaEnForo'] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Esta receta ya está publicada en el foro.',
            ),
            backgroundColor: Color(0xFFF39C12),
          ),
        );

        Navigator.pop(context);
        return;
      }

      // --------------------------------------------------------
      // RUTA DE LA FOTO EN FIREBASE STORAGE
      // --------------------------------------------------------

      final storagePath =
          'platillos/${user.uid}/${recetaId.toString()}.jpg';

      final storageRef =
          FirebaseStorage.instance
              .ref()
              .child(storagePath);

      debugPrint(
        'SUBIENDO FOTO A STORAGE: $storagePath',
      );

      // --------------------------------------------------------
      // SUBIR FOTO
      // --------------------------------------------------------

      await storageRef.putFile(
        _finalDishImage!,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      debugPrint(
        'FOTO SUBIDA CORRECTAMENTE A STORAGE',
      );

      // --------------------------------------------------------
      // OBTENER URL DE LA FOTO
      // --------------------------------------------------------

      final fotoPlatilloUrl =
          await storageRef.getDownloadURL();

      debugPrint(
        'URL DE LA FOTO: $fotoPlatilloUrl',
      );

      // --------------------------------------------------------
      // ACTUALIZAR RECETA EN FIRESTORE
      // --------------------------------------------------------

      await recetaRef.update({
        'fotoPlatilloUrl': fotoPlatilloUrl,
        'publicadaEnForo': true,
        'fechaPublicacionForo':
            FieldValue.serverTimestamp(),
        'likes': 0,
        'comentarios': 0,
      });

      debugPrint(
        'RECETA ACTUALIZADA EN FIRESTORE',
      );

      // --------------------------------------------------------
      // PUBLICACIÓN EXITOSA
      // --------------------------------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '📝 ¡Receta publicada correctamente!',
          ),
          backgroundColor: Color(0xFFC95D2E),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      // --------------------------------------------------------
      // ERROR
      // --------------------------------------------------------

      debugPrint(
        'ERROR AL PUBLICAR RECETA: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ No se pudo publicar la receta: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  // ============================================================
  // PANTALLA DE INVITACIÓN
  // ============================================================

  Widget _buildShareInvitation() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ----------------------------------------------------
            // ICONO / CELEBRACIÓN
            // ----------------------------------------------------

            Container(
              width: 110,
              height: 110,

              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F0),
                shape: BoxShape.circle,
              ),

              child: const Center(
                child: Text(
                  '🎉',
                  style: TextStyle(
                    fontSize: 60,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ----------------------------------------------------
            // TÍTULO
            // ----------------------------------------------------

            const Text(
              '¡Lo lograste!',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC95D2E),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Tu platillo está listo 🍽️',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 28),

            // ----------------------------------------------------
            // PREGUNTA
            // ----------------------------------------------------

            const Text(
              '¿Te gustaría compartir\ntu resultado?',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              '📸 Toma una foto de tu platillo\ny compártelo con la comunidad.',
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            // ----------------------------------------------------
            // INCENTIVO
            // ----------------------------------------------------

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(16),

                border: Border.all(
                  color: const Color(0xFFE9783F),
                  width: 1.5,
                ),
              ),

              child: const Column(
                children: [
                  Text(
                    '⭐',
                    style: TextStyle(
                      fontSize: 30,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    'Podrías aparecer entre las\n'
                    'recetas destacadas de la semana.',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC95D2E),
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    '❤️ Recibe likes y descubre qué opinan '
                    'otros usuarios sobre tu platillo.',
                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ----------------------------------------------------
            // COMPARTIR
            // ----------------------------------------------------

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFE9783F),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),

                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),

                label: const Text(
                  'Compartir mi resultado',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                onPressed: _continueToPublish,
              ),
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------
            // AHORA NO
            // ----------------------------------------------------

            SizedBox(
              width: double.infinity,

              child: TextButton(
                onPressed:
                    _isPublishing
                        ? null
                        : () =>
                            Navigator.pop(
                              context,
                              false,
                            ),

                child: const Text(
                  'Ahora no',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA DE PUBLICACIÓN
  // ============================================================

  Widget _buildPublishContent() {
    final recipeName =
        widget.recipe['name'] ?? 'Receta';

    final description =
        widget.recipe['description'] ?? '';

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // INSTRUCCIÓN
            // ==================================================

            const Text(
              '📸 Toma una foto de tu platillo final',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC95D2E),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Esta será la foto que aparecerá '
              'en el foro y en tu historial.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // NOMBRE DE RECETA
            // ==================================================

            Text(
              recipeName.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (description
                .toString()
                .isNotEmpty) ...[
              const SizedBox(height: 6),

              Text(
                description.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ==================================================
            // FOTO
            // ==================================================

            Expanded(
              child: GestureDetector(
                onTap: _openCamera,

                child: Container(
                  width: double.infinity,

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(18),

                    border: Border.all(
                      color:
                          const Color(
                        0xFFE9783F,
                      ),
                      width: 2,
                    ),
                  ),

                  child:
                      _finalDishImage != null
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),

                              child:
                                  Image.file(
                                _finalDishImage!,
                                width:
                                    double.infinity,
                                height:
                                    double.infinity,
                                fit:
                                    BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,

                              children: [
                                const Icon(
                                  Icons
                                      .camera_alt,
                                  size: 70,
                                  color:
                                      Color(
                                    0xFFE9783F,
                                  ),
                                ),

                                const SizedBox(
                                  height: 15,
                                ),

                                const Text(
                                  'Tomar foto',
                                  style:
                                      TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        Color(
                                      0xFFC95D2E,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                const Text(
                                  'Toca aquí para abrir la cámara',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // ELEGIR DE GALERÍA
            // ==================================================

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                style:
                    OutlinedButton.styleFrom(
                  side:
                      const BorderSide(
                    color:
                        Color(
                      0xFFE9783F,
                    ),
                    width: 1.5,
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 13,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),

                  backgroundColor:
                      Colors.white,
                ),

                icon:
                    const Icon(
                  Icons.photo_library_outlined,
                  color:
                      Color(
                    0xFFC95D2E,
                  ),
                ),

                label:
                    const Text(
                  'Elegir de galería',
                  style:
                      TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(
                      0xFFC95D2E,
                    ),
                  ),
                ),

                onPressed:
                    _isPublishing
                        ? null
                        : _openGallery,
              ),
            ),

            const SizedBox(height: 10),

            // ==================================================
            // BOTÓN PUBLICAR
            // ==================================================

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFFE9783F,
                  ),

                  disabledBackgroundColor:
                      Colors.grey.shade300,

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 15,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                icon:
                    _isPublishing
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
                            Icons.publish,
                            color:
                                Colors.white,
                          ),

                label:
                    Text(
                  _isPublishing
                      ? 'Publicando...'
                      : 'Publicar en el foro',

                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.white,
                  ),
                ),

                onPressed:
                    _isPublishing
                        ? null
                        : _publishRecipe,
              ),
            ),
          ],
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

      appBar: AppBar(
        backgroundColor:
            const Color(0xFFE9783F),

        elevation: 0,

        title: Text(
          _showCameraSection
              ? 'Publicar receta'
              : 'Resultado',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),

          onPressed:
              _isPublishing
                  ? null
                  : () =>
                      Navigator.pop(context),
        ),
      ),

      body:
          _showCameraSection
              ? _buildPublishContent()
              : _buildShareInvitation(),
    );
  }
}