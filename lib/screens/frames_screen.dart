import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FramesScreen extends StatefulWidget {
  const FramesScreen({super.key});

  @override
  State<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends State<FramesScreen> {
  String selectedFrame = 'classic';

  bool _isLoading = true;

  final List<Map<String, dynamic>> availableFrames = [
    {
      'id': 'classic',
      'name': 'Clásico',
      'icon': Icons.circle,
      'color': Colors.grey,
      'requirement': 'Sin requisitos',
      'unlocked': true,
      'gradient': null,
    },
    {
      'id': 'beginner',
      'name': 'Principiante',
      'icon': Icons.auto_awesome,
      'color': const Color(0xFFE9783F),
      'requirement': 'Publica tu primera receta',
      'unlocked': false,
      'gradient': null,
    },
    {
      'id': 'star',
      'name': 'Receta Estrella',
      'icon': Icons.star,
      'color': const Color(0xFFFFD700),
      'requirement': '+50 likes en una receta',
      'unlocked': false,
      'gradient': null,
    },
    {
      'id': 'trending',
      'name': 'Tendencia',
      'icon': Icons.local_fire_department,
      'color': const Color(0xFFFF6B35),
      'requirement': 'Receta más likeada de la semana',
      'unlocked': false,
      'gradient': null,
    },
    {
      'id': 'master',
      'name': 'Maestro Cocinero',
      'icon': Icons.workspace_premium,
      'color': const Color(0xFF9B59B6),
      'requirement': '5 recetas con +30 likes',
      'unlocked': false,
      'gradient': null,
    },
    {
      'id': 'champion',
      'name': 'Campeón',
      'icon': Icons.emoji_events,
      'color': const Color(0xFFFFD700),
      'requirement': '100 recetas guardadas',
      'unlocked': false,
      'gradient': const LinearGradient(
        colors: [
          Color(0xFFFFD700),
          Color(0xFFFF6B35),
        ],
      ),
    },
  ];

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // ============================================================
  // CARGAR DATOS
  // ============================================================

  Future<void> _loadData() async {
    await _loadSelectedFrame();

    await _checkAchievements();
  }

  // ============================================================
  // CARGAR MARCO SELECCIONADO
  // ============================================================

  Future<void> _loadSelectedFrame() async {
    final prefs = await SharedPreferences.getInstance();

    final String? frame = prefs.getString('selected_frame');

    if (!mounted) return;

    if (frame != null) {
      setState(() {
        selectedFrame = frame;
      });
    }
  }

  // ============================================================
  // COMPROBAR LOGROS AUTOMÁTICAMENTE
  // ============================================================

  Future<void> _checkAchievements() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        return;
      }

      print(
        'Comprobando logros para usuario: ${user.uid}',
      );

      // ========================================================
      // OBTENER RECETAS DEL USUARIO
      // ========================================================

      final recetasSnapshot = await FirebaseFirestore.instance
          .collection('recetas')
          .where(
            'uid',
            isEqualTo: user.uid,
          )
          .get();

      final recetas = recetasSnapshot.docs;

      print(
        'Recetas encontradas para logros: ${recetas.length}',
      );

      // ========================================================
      // PRINCIPIANTE
      // ========================================================

      bool beginnerUnlocked = false;

      for (final receta in recetas) {
        final datos = receta.data();

        if (datos['publicadaEnForo'] == true) {
          beginnerUnlocked = true;
          break;
        }
      }

      // ========================================================
      // RECETA ESTRELLA
      // ========================================================

      bool starUnlocked = false;

      for (final receta in recetas) {
        final datos = receta.data();

        final likes = _getLikes(datos);

        if (likes >= 50) {
          starUnlocked = true;
          break;
        }
      }

      // ========================================================
      // MAESTRO COCINERO
      // ========================================================

      int recetasCon30Likes = 0;

      for (final receta in recetas) {
        final datos = receta.data();

        final likes = _getLikes(datos);

        if (likes >= 30) {
          recetasCon30Likes++;
        }
      }

      final bool masterUnlocked =
          recetasCon30Likes >= 5;

      // ========================================================
      // RECETAS GUARDADAS
      // ========================================================

      final recetasGuardadasSnapshot =
          await FirebaseFirestore.instance
              .collection('recetas_guardadas')
              .where(
                'uid',
                isEqualTo: user.uid,
              )
              .get();

      final int cantidadRecetasGuardadas =
          recetasGuardadasSnapshot.docs.length;

      print(
        'Recetas guardadas: $cantidadRecetasGuardadas',
      );

      final bool championUnlocked =
          cantidadRecetasGuardadas >= 100;

      // ========================================================
      // TENDENCIA
      // ========================================================

      final bool trendingUnlocked =
          await _checkTrendingAchievement(
        userUid: user.uid,
      );

      // ========================================================
      // ACTUALIZAR ESTADO DE LOS MARCOS
      // ========================================================

      if (!mounted) return;

      setState(() {
        for (final frame in availableFrames) {
          switch (frame['id']) {
            case 'classic':
              frame['unlocked'] = true;
              break;

            case 'beginner':
              frame['unlocked'] = beginnerUnlocked;
              break;

            case 'star':
              frame['unlocked'] = starUnlocked;
              break;

            case 'trending':
              frame['unlocked'] = trendingUnlocked;
              break;

            case 'master':
              frame['unlocked'] = masterUnlocked;
              break;

            case 'champion':
              frame['unlocked'] = championUnlocked;
              break;
          }
        }

        _isLoading = false;
      });

      print('========================================');
      print('LOGROS');
      print('Principiante: $beginnerUnlocked');
      print('Receta Estrella: $starUnlocked');
      print('Tendencia: $trendingUnlocked');
      print('Maestro Cocinero: $masterUnlocked');
      print('Campeón: $championUnlocked');
      print('========================================');

      // ========================================================
      // SEGURIDAD
      // ========================================================
      //
      // Si por alguna razón el usuario tenía seleccionado
      // un marco que ahora no está disponible, regresamos
      // automáticamente al clásico.
      //

      final selectedIsUnlocked =
          availableFrames.any(
        (frame) =>
            frame['id'] == selectedFrame &&
            frame['unlocked'] == true,
      );

      if (!selectedIsUnlocked) {
        await _selectFrame(
          'classic',
          mostrarMensaje: false,
        );
      }
    } catch (e) {
      print(
        'ERROR AL COMPROBAR LOGROS: $e',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // OBTENER LIKES
  // ============================================================

  int _getLikes(
    Map<String, dynamic> datos,
  ) {
    final likes = datos['likes'];

    if (likes is int) {
      return likes;
    }

    if (likes is num) {
      return likes.toInt();
    }

    return 0;
  }

  // ============================================================
  // COMPROBAR TENDENCIA
  // ============================================================

  Future<bool> _checkTrendingAchievement({
    required String userUid,
  }) async {
    try {
      // --------------------------------------------------------
      // FECHA ACTUAL
      // --------------------------------------------------------

      final ahora = DateTime.now();

      // Calculamos el inicio de la semana.
      //
      // DateTime.monday = 1
      // DateTime.sunday = 7
      //

      final inicioSemana = DateTime(
        ahora.year,
        ahora.month,
        ahora.day,
      ).subtract(
        Duration(
          days: ahora.weekday - DateTime.monday,
        ),
      );

      final inicioSemanaTimestamp =
          Timestamp.fromDate(
        inicioSemana,
      );

      // --------------------------------------------------------
      // OBTENER RECETAS PUBLICADAS ESTA SEMANA
      // --------------------------------------------------------

      final snapshot = await FirebaseFirestore.instance
          .collection('recetas')
          .where(
            'publicadaEnForo',
            isEqualTo: true,
          )
          .get();

      if (snapshot.docs.isEmpty) {
        return false;
      }

      int mayorCantidadLikes = 0;

      String? usuarioConMasLikes;

      for (final documento in snapshot.docs) {
        final datos = documento.data();

        // ------------------------------------------------------
        // OBTENER FECHA
        // ------------------------------------------------------

        final fecha = _obtenerFecha(datos);

        if (fecha == null) {
          continue;
        }

        DateTime? fechaReceta;

        if (fecha is Timestamp) {
          fechaReceta = fecha.toDate();
        } else if (fecha is DateTime) {
          fechaReceta = fecha;
        }

        if (fechaReceta == null) {
          continue;
        }

        // ------------------------------------------------------
        // COMPROBAR QUE SEA DE ESTA SEMANA
        // ------------------------------------------------------

        if (fechaReceta.isBefore(inicioSemana)) {
          continue;
        }

        // ------------------------------------------------------
        // LIKES
        // ------------------------------------------------------

        final likes = _getLikes(datos);

        if (likes > mayorCantidadLikes) {
          mayorCantidadLikes = likes;

          usuarioConMasLikes =
              datos['uid']?.toString();
        }
      }

      print(
        'Mayor cantidad de likes esta semana: '
        '$mayorCantidadLikes',
      );

      print(
        'Usuario con más likes esta semana: '
        '$usuarioConMasLikes',
      );

      // --------------------------------------------------------
      // EL USUARIO ES EL GANADOR
      // --------------------------------------------------------

      return usuarioConMasLikes == userUid &&
          mayorCantidadLikes > 0;
    } catch (e) {
      print(
        'ERROR AL COMPROBAR TENDENCIA: $e',
      );

      return false;
    }
  }

  // ============================================================
  // OBTENER FECHA DE RECETA
  // ============================================================

  dynamic _obtenerFecha(
    Map<String, dynamic> datos,
  ) {
    return datos['fechaPublicacionForo'] ??
        datos['fechaCreacion'] ??
        datos['fechaGeneracion'] ??
        datos['fecha'] ??
        datos['createdAt'];
  }

  // ============================================================
  // SELECCIONAR MARCO
  // ============================================================

  Future<void> _selectFrame(
    String frameId, {
    bool mostrarMensaje = true,
  }) async {
    final frame = availableFrames.firstWhere(
      (f) => f['id'] == frameId,
    );

    final bool isUnlocked =
        frame['unlocked'] == true;

    if (!isUnlocked) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'selected_frame',
      frameId,
    );

    if (!mounted) return;

    setState(() {
      selectedFrame = frameId;
    });

    if (mostrarMensaje) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Marco seleccionado: '
            '${_getFrameName(frameId)}',
          ),
          backgroundColor:
              const Color(0xFFE9783F),
        ),
      );
    }
  }

  // ============================================================
  // NOMBRE DEL MARCO
  // ============================================================

  String _getFrameName(
    String frameId,
  ) {
    final frame = availableFrames.firstWhere(
      (f) => f['id'] == frameId,
    );

    return frame['name'];
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🎨 Personalizar Marco',
          style: TextStyle(
            color: Colors.white,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE9783F),
              ),
            )
          : Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // VISTA PREVIA
                  // ==================================================

                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Vista previa',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Container(
                          padding:
                              const EdgeInsets.all(8),
                          decoration:
                              _getFrameDecoration(
                            selectedFrame,
                          ),
                          child:
                              const CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Color(
                                0xFFE9783F,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          'Marco: '
                          '${_getFrameName(selectedFrame)}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  const Divider(),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    'Selecciona tu marco:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFFC95D2E),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Los marcos se desbloquean '
                    'automáticamente al cumplir logros',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // GRID
                  // ==================================================

                  Expanded(
                    child:
                        GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio:
                            1.3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),

                      itemCount:
                          availableFrames.length,

                      itemBuilder:
                          (context, index) {
                        final frame =
                            availableFrames[
                                index];

                        final isSelected =
                            selectedFrame ==
                                frame['id'];

                        final isUnlocked =
                            frame['unlocked'] ??
                                false;

                        return GestureDetector(
                          onTap: isUnlocked
                              ? () =>
                                  _selectFrame(
                                    frame['id'],
                                  )
                              : null,

                          child: Container(
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),

                              border:
                                  Border.all(
                                color:
                                    isSelected
                                        ? const Color(
                                            0xFFE9783F,
                                          )
                                        : Colors
                                            .grey
                                            .withOpacity(
                                            0.3,
                                          ),
                                width:
                                    isSelected
                                        ? 3
                                        : 1,
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors
                                      .black
                                      .withOpacity(
                                    0.05,
                                  ),
                                  blurRadius:
                                      8,
                                  offset:
                                      const Offset(
                                    0,
                                    2,
                                  ),
                                ),
                              ],
                            ),

                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,

                              children: [
                                // ==================================
                                // VISTA DEL MARCO
                                // ==================================

                                Container(
                                  padding:
                                      const EdgeInsets
                                          .all(4),

                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape.circle,

                                    color:
                                        frame['color']
                                                as Color? ??
                                            Colors
                                                .grey,

                                    gradient:
                                        frame[
                                            'gradient'],
                                  ),

                                  child:
                                      const CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        Colors.white,
                                    child:
                                        Icon(
                                      Icons.person,
                                      size:
                                          24,
                                      color:
                                          Color(
                                        0xFFE9783F,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height: 8,
                                ),

                                // ==================================
                                // NOMBRE
                                // ==================================

                                Text(
                                  frame['name'],
                                  style:
                                      TextStyle(
                                    fontSize:
                                        14,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight
                                                .bold
                                            : FontWeight
                                                .normal,
                                    color:
                                        isUnlocked
                                            ? Colors
                                                .black87
                                            : Colors
                                                .grey,
                                  ),
                                ),

                                const SizedBox(
                                  height: 2,
                                ),

                                // ==================================
                                // BLOQUEADO
                                // ==================================

                                if (!isUnlocked)
                                  const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        size:
                                            14,
                                        color:
                                            Colors.grey,
                                      ),
                                      SizedBox(
                                        width:
                                            4,
                                      ),
                                      Text(
                                        'Bloqueado',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              11,
                                          color:
                                              Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),

                                // ==================================
                                // SELECCIONADO
                                // ==================================

                                if (isSelected)
                                  const Icon(
                                    Icons
                                        .check_circle,
                                    size: 18,
                                    color:
                                        Color(
                                      0xFFE9783F,
                                    ),
                                  ),

                                // ==================================
                                // REQUISITO
                                // ==================================

                                if (!isUnlocked &&
                                    frame[
                                            'requirement'] !=
                                        null)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          8,
                                    ),
                                    child:
                                        Text(
                                      '🔒 '
                                      '${frame['requirement']}',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            10,
                                        color:
                                            Colors.grey,
                                      ),
                                      textAlign:
                                          TextAlign
                                              .center,
                                      maxLines:
                                          2,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  ),
                              ],
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

  // ============================================================
  // DECORACIÓN DEL MARCO
  // ============================================================

  BoxDecoration _getFrameDecoration(
    String frameId,
  ) {
    final frame =
        availableFrames.firstWhere(
      (f) => f['id'] == frameId,
    );

    if (frame['gradient'] != null) {
      return BoxDecoration(
        shape: BoxShape.circle,
        gradient: frame['gradient'],
        boxShadow: [
          BoxShadow(
            color:
                (frame['color'] as Color)
                    .withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      );
    }

    return BoxDecoration(
      shape: BoxShape.circle,
      color:
          frame['color'] as Color? ??
              Colors.grey,
      boxShadow: [
        BoxShadow(
          color:
              (frame['color'] as Color)
                  .withOpacity(0.4),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    );
  }
}