import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'saved_recipes_screen.dart';
import 'recipe_screen.dart';
import 'frames_screen.dart';
import 'step_by_step_screen.dart';
import '../utils/share_utils.dart';
import 'edit_profile_screen.dart';

// ================================================================
// PROFILE SCREEN
// ================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool _isLoadingUser = true;
  List<String> userBadges = [];
  String selectedFrame = 'classic';
  int recetasGeneradas = 0;
  int likesTotales = 0;
  int recetasGuardadas = 0;
  String nombreUsuario = 'Usuario';
  String correoUsuario = '';
  bool _cargandoEstadisticas = true;

  final List<Map<String, dynamic>> availableFrames = [
    {
      'id': 'classic',
      'name': 'Clásico',
      'icon': Icons.circle,
      'color': const Color(0xFF7F8C8D),
      'requirement': 'Sin requisitos',
      'unlocked': true,
      'gradient': null,
    },
    {
      'id': 'beginner',
      'name': 'Principiante',
      'icon': Icons.auto_awesome,
      'color': const Color(0xFF1ABC9C),
      'requirement': 'Publica tu primera receta',
      'unlocked': false,
      'gradient': const LinearGradient(
        colors: [Color(0xFF1ABC9C), Color(0xFF16A085)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'star',
      'name': 'Receta Estrella',
      'icon': Icons.star,
      'color': const Color(0xFF3498DB),
      'requirement': '+50 likes en una receta',
      'unlocked': false,
      'gradient': const LinearGradient(
        colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'trending',
      'name': 'Tendencia',
      'icon': Icons.local_fire_department,
      'color': const Color(0xFFE74C3C),
      'requirement': 'Receta más likeada de la semana',
      'unlocked': false,
      'gradient': const LinearGradient(
        colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'master',
      'name': 'Maestro Cocinero',
      'icon': Icons.workspace_premium,
      'color': const Color(0xFF8E44AD),
      'requirement': '5 recetas con +30 likes',
      'unlocked': false,
      'gradient': const LinearGradient(
        colors: [Color(0xFF8E44AD), Color(0xFF6C3483)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'champion',
      'name': 'Campeón',
      'icon': Icons.emoji_events,
      'color': const Color(0xFF2C3E50),
      'requirement': '100 recetas guardadas',
      'unlocked': false,
      'gradient': const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFF8E44AD), Color(0xFF2C3E50)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBadges();
    _loadSelectedFrame();
    _cargarEstadisticas();
  }

  int _getIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is List) return value.length;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _getCountFromData(Map<String, dynamic> data, List<String> possibleFields) {
    for (final field in possibleFields) {
      if (data.containsKey(field) && data[field] != null) {
        return _getIntValue(data[field]);
      }
    }
    return 0;
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _cargandoEstadisticas = false);
        return;
      }

      final usuarioDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      Map<String, dynamic> datosUsuario = {};
      if (usuarioDoc.exists) datosUsuario = usuarioDoc.data() ?? {};

      final recetasSnapshot = await FirebaseFirestore.instance
          .collection('recetas')
          .where('uid', isEqualTo: user.uid)
          .get();

      int likesPublicados = 0;

      for (final recetaDoc in recetasSnapshot.docs) {
        final receta = recetaDoc.data();
        final publicada = receta['publicadaEnForo'] == true ||
            receta['publicadaEnForo']?.toString().toLowerCase() == 'true';

        if (!publicada) continue;

        likesPublicados += _getCountFromData(receta, ['likes', 'likesCount']);
      }

      final recetasGuardadasSnapshot = await FirebaseFirestore.instance
          .collection('recetas_guardadas')
          .where('uid', isEqualTo: user.uid)
          .get();

      final cantidadRecetasGuardadas = recetasGuardadasSnapshot.docs.length;
      final recetasGeneradasFirestore = _getCountFromData(datosUsuario, ['recetasGeneradas']);
      final recetasGeneradasFinal = recetasGeneradasFirestore > 0
          ? recetasGeneradasFirestore
          : recetasSnapshot.docs.length;

      if (mounted) {
        setState(() {
          nombreUsuario = datosUsuario['usuario']?.toString() ??
              datosUsuario['nombre']?.toString() ??
              'Usuario';
          correoUsuario = datosUsuario['correo']?.toString() ?? user.email ?? '';
          recetasGeneradas = recetasGeneradasFinal;
          likesTotales = likesPublicados;
          recetasGuardadas = cantidadRecetasGuardadas;
          _cargandoEstadisticas = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR AL CARGAR ESTADÍSTICAS: $e');
      if (mounted) setState(() => _cargandoEstadisticas = false);
    }
  }

  Future<void> _loadBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? badgesJson = prefs.getString('user_badges');
      if (badgesJson != null) {
        final List<String> badges = List<String>.from(json.decode(badgesJson));
        if (!mounted) return;
        setState(() {
          userBadges = badges;
          for (var frame in availableFrames) {
            if (frame['id'] != 'classic') {
              frame['unlocked'] = badges.contains(frame['id']);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('ERROR AL CARGAR MEDALLAS: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingUser = false);
        return;
      }
      final document = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (document.exists) {
        setState(() {
          userData = document.data();
          _isLoadingUser = false;
        });
      } else {
        setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      debugPrint('ERROR AL CARGAR USUARIO: $e');
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadSelectedFrame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? frame = prefs.getString('selected_frame');
      if (frame != null && mounted) {
        setState(() => selectedFrame = frame);
      }
    } catch (e) {
      debugPrint('ERROR AL CARGAR MARCO: $e');
    }
  }

  BoxDecoration _getAvatarDecoration() {
    final frame = availableFrames.firstWhere(
      (f) => f['id'] == selectedFrame,
      orElse: () => availableFrames.first,
    );
    if (frame['gradient'] != null) {
      return BoxDecoration(
        shape: BoxShape.circle,
        gradient: frame['gradient'],
        boxShadow: [
          BoxShadow(
            color: (frame['color'] as Color).withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      );
    }
    return BoxDecoration(
      shape: BoxShape.circle,
      color: frame['color'] as Color? ?? Colors.grey,
      boxShadow: [
        BoxShadow(
          color: (frame['color'] as Color).withOpacity(0.4),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    );
  }

  Future<void> _abrirHistorialAmelia() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AmeliaHistoryScreen()),
    );
    await _loadUserData();
    await _cargarEstadisticas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9783F),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE9783F), Color(0xFFC95D2E)],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _getAvatarDecoration(),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: userData?['fotoPerfil'] != null &&
                            userData!['fotoPerfil'].toString().isNotEmpty
                        ? NetworkImage(userData!['fotoPerfil'].toString())
                        : null,
                    child: userData?['fotoPerfil'] == null ||
                            userData!['fotoPerfil'].toString().isEmpty
                        ? const Icon(Icons.person, size: 50, color: Color(0xFFE9783F))
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  nombreUsuario,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '🍳 Amante de la cocina',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  correoUsuario,
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      'Recetas',
                      _cargandoEstadisticas ? '...' : recetasGeneradas.toString(),
                    ),
                    _StatItem(
                      'Likes totales',
                      _cargandoEstadisticas ? '...' : likesTotales.toString(),
                    ),
                    _StatItem(
                      'Guardadas',
                      _cargandoEstadisticas ? '...' : recetasGuardadas.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _BadgesSection(),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ========================================================
          // PERSONALIZAR MARCO
          // ========================================================

          _ProfileOption(
            icon: Icons.palette,
            title: 'Personalizar Marco',
            iconColor: const Color(0xFFE9783F),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FramesScreen()),
              );
              await _loadSelectedFrame();
              await _loadBadges();
              await _cargarEstadisticas();
            },
          ),

          // ========================================================
          // EDITAR PERFIL
          // ========================================================

          _ProfileOption(
            icon: Icons.person,
            title: 'Editar Perfil',
            iconColor: const Color(0xFFE9783F),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    userData: userData ?? {},
                  ),
                ),
              );
              if (result == true) {
                _loadUserData();
                _cargarEstadisticas();
              }
            },
          ),

          // ========================================================
          // MIS RECETAS FAVORITAS
          // ========================================================

          _ProfileOption(
            icon: Icons.favorite,
            title: 'Mis Recetas Favoritas',
            iconColor: const Color(0xFFF39C12),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
              );
              await _cargarEstadisticas();
            },
          ),

          // ========================================================
          // HISTORIAL DE AMELIA
          // ========================================================

          _ProfileOption(
            icon: Icons.history,
            title: 'Historial de Amelia',
            iconColor: const Color(0xFFE9783F),
            onTap: _abrirHistorialAmelia,
          ),

          // ========================================================
          // CONFIGURACIÓN (SIN MODO OSCURO)
          // ========================================================

          _ProfileOption(
            icon: Icons.settings,
            title: 'Configuración',
            iconColor: const Color(0xFFE9783F),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚙️ Configuración (sin funcionalidad)'),
                  backgroundColor: Color(0xFFE9783F),
                ),
              );
            },
          ),

          // ========================================================
          // AYUDA
          // ========================================================

          _ProfileOption(
            icon: Icons.help_outline,
            title: 'Ayuda',
            iconColor: const Color(0xFFE9783F),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❓ Ayuda (sin funcionalidad)'),
                  backgroundColor: Color(0xFFE9783F),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ========================================================
          // CERRAR SESIÓN
          // ========================================================

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('¿Cerrar sesión?'),
                      content: const Text('¿Estás seguro de que quieres salir?'),
                      actions: [
                        TextButton(
                          child: const Text('Cancelar'),
                          onPressed: () => Navigator.pop(context),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Salir'),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ================================================================
// STAT ITEM
// ================================================================

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

// ================================================================
// PROFILE OPTION
// ================================================================

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback onTap;
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ================================================================
// BADGES SECTION
// ================================================================

class _BadgesSection extends StatelessWidget {
  const _BadgesSection();

  @override
  Widget build(BuildContext context) {
    final List<_Badge> badges = const [
      _Badge(
        icon: Icons.emoji_events,
        label: 'Campeón',
        color: Color(0xFFFFD700),
        description: '100 recetas guardadas',
      ),
      _Badge(
        icon: Icons.local_fire_department,
        label: 'Tendencia',
        color: Color(0xFFFF6B35),
        description: 'Receta más likeada de la semana',
      ),
      _Badge(
        icon: Icons.star,
        label: 'Receta Estrella',
        color: Color(0xFFFFD700),
        description: '+50 likes en una receta',
      ),
      _Badge(
        icon: Icons.workspace_premium,
        label: 'Maestro Cocinero',
        color: Color(0xFF9B59B6),
        description: '5 recetas con +30 likes',
      ),
      _Badge(
        icon: Icons.bookmark,
        label: 'Favorita',
        color: Color(0xFFE74C3C),
        description: 'Receta más guardada',
      ),
      _Badge(
        icon: Icons.auto_awesome,
        label: 'Principiante',
        color: Color(0xFFE9783F),
        description: 'Primera receta publicada',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              '🏅 Medallas',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            return _BadgeItem(badge: badges[index]);
          },
        ),
      ],
    );
  }
}

// ================================================================
// BADGE MODEL
// ================================================================

class _Badge {
  final IconData icon;
  final String label;
  final Color color;
  final String description;
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
  });
}

// ================================================================
// BADGE ITEM
// ================================================================

class _BadgeItem extends StatelessWidget {
  final _Badge badge;
  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(badge.icon, color: badge.color, size: 28),
            const SizedBox(height: 4),
            Text(
              badge.label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

  const ForumRecipeCard({
    super.key,
    required this.receta,
    required this.onTap,
  });

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

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(0),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: receta['fotoPlatilloUrl'].toString().isNotEmpty
                    ? Image.network(
                        receta['fotoPlatilloUrl'].toString(),
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
                      )
                    : Container(
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receta['titulo']?.toString() ?? 'Receta sin nombre',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC95D2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (receta['descripcion'].toString().isNotEmpty)
                    Text(
                      receta['descripcion'].toString(),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${receta['likes'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${receta['comentarios'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () {
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

// ================================================================
// HISTORIAL DE AMELIA
// ================================================================

class AmeliaHistoryScreen extends StatelessWidget {
  const AmeliaHistoryScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _getMisRecetas() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('recetas')
        .where('uid', isEqualTo: user.uid)
        .snapshots();
  }

  Future<Map<String, String>> _getDatosUsuario(String uid) async {
    try {
      if (uid.isEmpty) return {'nombre': 'Usuario', 'fotoPerfil': ''};
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

  int _getIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is List) return value.length;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

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

  dynamic _obtenerFecha(Map<String, dynamic> datos) {
    return datos['fechaCreacion'] ??
        datos['fechaGeneracion'] ??
        datos['fecha'] ??
        datos['createdAt'] ??
        datos['fechaPublicacionForo'];
  }

  // ============================================================
  // ABRIR RECETA - VERSIÓN SIMPLIFICADA
  // ============================================================

  Future<void> _openRecipeDetail(
    BuildContext context,
    Map<String, dynamic> receta,
  ) async {
    final publicada = receta['publicadaEnForo'] == true ||
        receta['publicadaEnForo']?.toString().toLowerCase() == 'true';

    final uid = receta['uid']?.toString() ?? '';
    final datosUsuario = await _getDatosUsuario(uid);
    final nombreUsuario = datosUsuario['nombre'] ?? 'Usuario';
    final fotoPerfil = datosUsuario['fotoPerfil'] ?? '';

    // Usar datos de la receta (NO de publicaciones)
    final likes = _getIntValue(receta['likes'] ?? receta['likesCount'] ?? 0);
    final comentarios = _getIntValue(receta['comentarios'] ?? receta['comentariosCount'] ?? 0);

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeScreen(
          recipeName: receta['titulo']?.toString() ?? 'Receta sin nombre',
          ingredients: receta['ingredientes'] is List
              ? List<String>.from(receta['ingredientes'])
              : <String>[],
          instructions: receta['preparacion'] is List
              ? List<String>.from(receta['preparacion']).join('\n\n')
              : receta['preparacion']?.toString() ?? '',
          recipe: {
            ...receta,
            'publicadaEnForo': publicada,
            'recetaId': receta['recetaId'] ?? receta['id'],
            'uid': uid,
            'usuario': nombreUsuario,
            'nombreUsuario': nombreUsuario,
            'nombre': nombreUsuario,
            'fotoPerfil': fotoPerfil,
            'fotoPlatilloUrl': receta['fotoPlatilloUrl']?.toString() ?? '',
            'likes': likes,
            'likesCount': likes,
            'comentarios': comentarios,
            'comentariosCount': comentarios,
          },
        ),
      ),
    );
  }

  Widget _placeholderDishImage({double height = 200}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9783F), Color(0xFFC95D2E)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 60,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildPrivateCard(
    BuildContext context,
    Map<String, dynamic> receta,
    String fecha,
    String uid,
  ) {
    return FutureBuilder<Map<String, String>>(
      future: _getDatosUsuario(uid),
      builder: (context, userSnapshot) {
        final nombre = userSnapshot.data?['nombre'] ?? 'Usuario';
        final fotoPerfil = userSnapshot.data?['fotoPerfil'] ?? '';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openRecipeDetail(context, receta),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFFE9783F),
                        backgroundImage: fotoPerfil.isNotEmpty
                            ? NetworkImage(fotoPerfil)
                            : null,
                        child: fotoPerfil.isEmpty
                            ? Text(
                                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Privada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    receta['titulo']?.toString() ?? 'Receta sin nombre',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC95D2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if ((receta['descripcion']?.toString() ?? '').isNotEmpty)
                    Text(
                      receta['descripcion'].toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 19,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta receta es privada. Solo tú puedes verla.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Ver receta',
                        style: TextStyle(
                          color: Color(0xFFE9783F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 15,
                        color: Color(0xFFE9783F),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // VERIFICAR SI ESTÁ PUBLICADA
  // ============================================================

  bool _isPublicada(dynamic valorPublicada) {
    if (valorPublicada == null) return false;
    if (valorPublicada is bool) return valorPublicada;
    if (valorPublicada is String) {
      return valorPublicada.toLowerCase() == 'true' ||
          valorPublicada.toLowerCase() == '1';
    }
    if (valorPublicada is num) return valorPublicada == 1;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HISTORIAL DE AMELIA',
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
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getMisRecetas(),
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
                  'Error al cargar tu historial:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final documentos = snapshot.data?.docs ?? [];

          if (documentos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 80,
                      color: Color(0xFFE9783F),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Todavía no tienes recetas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Cuando generes una receta con Amelia aparecerá aquí, aunque no la publiques en el foro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final recetas = documentos.toList();
          recetas.sort((a, b) {
            final fechaA = _obtenerFecha(a.data());
            final fechaB = _obtenerFecha(b.data());
            if (fechaA is Timestamp && fechaB is Timestamp) {
              return fechaB.compareTo(fechaA);
            }
            return 0;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recetas.length,
            itemBuilder: (context, index) {
              final documento = recetas[index];
              final datos = documento.data();

              // ==================================================
              // VERIFICAR SI ESTÁ PUBLICADA
              // ==================================================

              final publicada = _isPublicada(datos['publicadaEnForo']);

              // Si tiene publicacionId, también está publicada
              final hasPublicacionId = datos['publicacionId'] != null &&
                  datos['publicacionId'].toString().isNotEmpty;

              final isPublicada = publicada || hasPublicacionId;

              debugPrint('🔍 Receta: ${datos['nombre']} - Publicada: $isPublicada');

              final uid = datos['uid']?.toString() ??
                  FirebaseAuth.instance.currentUser?.uid ??
                  '';

              final fecha = _formatFecha(_obtenerFecha(datos));
              final recetaId = datos['recetaId']?.toString() ?? documento.id;

              // ==================================================
              // CONSTRUIR RECETA COMPLETA
              // ==================================================

              final receta = <String, dynamic>{
                'id': documento.id,
                'recetaId': recetaId,
                'uid': uid,
                'publicacionId': datos['publicacionId'],
                'fotoPlatilloUrl': datos['fotoPlatilloUrl']?.toString() ?? '',
                'titulo': datos['nombre']?.toString() ??
                    datos['titulo']?.toString() ??
                    'Receta sin nombre',
                'descripcion': datos['descripcion']?.toString() ?? '',
                'ingredientes': datos['ingredients'] is List
                    ? List<String>.from(datos['ingredients'])
                    : datos['ingredientes'] is List
                        ? List<String>.from(datos['ingredientes'])
                        : <String>[],
                'preparacion': datos['preparation'] is List
                    ? List<String>.from(datos['preparation'])
                    : datos['preparacion'] is List
                        ? List<String>.from(datos['preparacion'])
                        : <String>[],
                'likes': _getIntValue(datos['likes'] ?? datos['likesCount']),
                'likesCount': _getIntValue(datos['likesCount'] ?? datos['likes']),
                'comentarios': _getIntValue(datos['comentarios'] ?? datos['comentariosCount']),
                'comentariosCount': _getIntValue(
                    datos['comentariosCount'] ?? datos['comentarios']),
                'publicadaEnForo': isPublicada,
                'fechaCreacion': datos['fechaCreacion'],
                'fechaPublicacionForo': datos['fechaPublicacionForo'],
                'usuario': datos['usuario'] ??
                    datos['nombreUsuario'] ??
                    datos['nombre'],
                'nombreUsuario': datos['nombreUsuario'] ??
                    datos['usuario'] ??
                    datos['nombre'],
                'fotoPerfil': datos['fotoPerfil'],
              };

              // ==================================================
              // SI ESTÁ PUBLICADA → USAR DISEÑO DEL FORO
              // ==================================================

              if (isPublicada) {
                return ForumRecipeCard(
                  receta: receta,
                  onTap: () => _openRecipeDetail(context, receta),
                );
              }

              // ==================================================
              // SI ES PRIVADA → USAR DISEÑO PRIVADO
              // ==================================================

              return _buildPrivateCard(
                context,
                receta,
                fecha,
                uid,
              );
            },
          );
        },
      ),
    );
  }
}