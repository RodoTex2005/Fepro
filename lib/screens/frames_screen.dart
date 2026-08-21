import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FramesScreen extends StatefulWidget {
  const FramesScreen({super.key});

  @override
  State<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends State<FramesScreen> {
  String selectedFrame = 'classic';
  List<String> userBadges = [];

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
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar medallas
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

    // Cargar marco seleccionado
    final String? frame = prefs.getString('selected_frame');
    if (frame != null) {
      setState(() {
        selectedFrame = frame;
      });
    }
  }

  Future<void> _selectFrame(String frameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_frame', frameId);
    setState(() {
      selectedFrame = frameId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Marco seleccionado: ${_getFrameName(frameId)}'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );
  }

  String _getFrameName(String frameId) {
    final frame = availableFrames.firstWhere((f) => f['id'] == frameId);
    return frame['name'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🎨 Personalizar Marco',
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vista previa del avatar con el marco seleccionado
            Center(
              child: Column(
                children: [
                  const Text(
                    'Vista previa',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _getFrameDecoration(selectedFrame),
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
                  const SizedBox(height: 4),
                  Text(
                    'Marco: ${_getFrameName(selectedFrame)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Selecciona tu marco:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Los marcos se desbloquean al cumplir logros',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: availableFrames.length,
                itemBuilder: (context, index) {
                  final frame = availableFrames[index];
                  final isSelected = selectedFrame == frame['id'];
                  final isUnlocked = frame['unlocked'] ?? false;

                  return GestureDetector(
                    onTap: isUnlocked ? () => _selectFrame(frame['id']) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2ECC71)
                              : Colors.grey.withOpacity(0.3),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Vista previa del marco
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: frame['color'] as Color? ?? Colors.grey,
                              gradient: frame['gradient'],
                            ),
                            child: const CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.person,
                                size: 24,
                                color: Color(0xFF2ECC71),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            frame['name'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isUnlocked ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (!isUnlocked)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Bloqueado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Color(0xFF2ECC71),
                            ),
                          if (!isUnlocked && frame['requirement'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '🔒 ${frame['requirement']}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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

  BoxDecoration _getFrameDecoration(String frameId) {
    final frame = availableFrames.firstWhere((f) => f['id'] == frameId);

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
}
