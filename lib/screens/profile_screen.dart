import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'saved_recipes_screen.dart';
import 'frames_screen.dart';


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
      'color': const Color(0xFF2ECC71),
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
        colors: [Color(0xFFFFD700), Color(0xFFFF6B35)],
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBadges();
    _loadSelectedFrame();
  }

  Future<void> _loadBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final String? badgesJson = prefs.getString('user_badges');
    if (badgesJson != null) {
      final List<String> badges = List<String>.from(json.decode(badgesJson));
      setState(() {
        userBadges = badges;
        for (var frame in availableFrames) {
          if (frame['id'] != 'classic') {
            frame['unlocked'] = badges.contains(frame['id']);
          }
        }
      });
    }
  }

  Future<void> _loadUserData() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isLoadingUser = false;
      });
      return;
    }

    final document = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (document.exists) {
      setState(() {
        userData = document.data();
        _isLoadingUser = false;
      });
    } else {
      setState(() {
        _isLoadingUser = false;
      });
    }
  } catch (e) {
    print('ERROR AL CARGAR USUARIO: $e');

    setState(() {
      _isLoadingUser = false;
    });
  }
}

  Future<void> _loadSelectedFrame() async {
    final prefs = await SharedPreferences.getInstance();
    final String? frame = prefs.getString('selected_frame');
    if (frame != null) {
      setState(() {
        selectedFrame = frame;
      });
    }
  }

  BoxDecoration _getAvatarDecoration() {
    final frame = availableFrames.firstWhere((f) => f['id'] == selectedFrame);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: ListView(
        children: [
          // ===== HEADER =====
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: _getAvatarDecoration(),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF2ECC71),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userData?['usuario'] ?? 'Usuario',
                  style: TextStyle(
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
                  userData?['correo'] ?? 'Sin correo',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem('Recetas', '15'),
                    _StatItem('Likes totales', '95'),
                    _StatItem('Guardadas', '12'),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      'Nivel',
                      '${userData?['nivel'] ?? 1}',
                    ),
                    _StatItem(
                      'Experiencia',
                      '${userData?['experiencia'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _BadgesSection(),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ===== OPCIONES =====
          _ProfileOption(
            icon: Icons.palette, // <-- CAMBIADO
            title: 'Personalizar Marco',
            iconColor: const Color(0xFF2ECC71),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FramesScreen()),
              );
            },
          ),

          _ProfileOption(
            icon: Icons.favorite,
            title: 'Mis Recetas Favoritas',
            iconColor: const Color(0xFFF39C12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
              );
            },
          ),

          _ProfileOption(
            icon: Icons.history,
            title: 'Historial de Amelia', // <-- CAMBIADO
            iconColor: const Color(0xFF2ECC71),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('💬 Historial de Amelia'),
                  backgroundColor: Color(0xFF2ECC71),
                ),
              );
            },
          ),

          _ProfileOption(
            icon: Icons.settings,
            title: 'Configuración',
            iconColor: const Color(0xFF2ECC71),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚙️ Configuración (sin funcionalidad)'),
                  backgroundColor: Color(0xFF2ECC71),
                ),
              );
            },
          ),

          _ProfileOption(
            icon: Icons.help_outline,
            title: 'Ayuda',
            iconColor: const Color(0xFF2ECC71),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❓ Ayuda (sin funcionalidad)'),
                  backgroundColor: Color(0xFF2ECC71),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ===== CERRAR SESIÓN =====
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
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('¿Cerrar sesión?'),
                      content: const Text(
                        '¿Estás seguro de que quieres salir?',
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
                          child: const Text('Salir'),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
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

// ===== STAT ITEM =====
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

// ===== PROFILE OPTION =====
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
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}

// ===== BADGES SECTION =====
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
        color: Color(0xFF2ECC71),
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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

// ===== BADGE MODEL =====
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

// ===== BADGE ITEM =====
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
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
