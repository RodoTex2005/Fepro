import 'package:flutter/material.dart';
import 'forum_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int paginaActual = 1;

  final List<Widget> paginas = const [
    ChatScreen(),
    ForumScreen(),
    ProfileScreen(),
  ];

  final List<String> titulos = [
    'Hablar con Amelia',
    'RECETAS PARA TI',
    'Mi Perfil',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ===== APP BAR OCULTO PARA EL CHAT =====
      appBar: paginaActual == 0
          ? null // Oculta el AppBar en el chat
          : AppBar(
              title: Text(
                titulos[paginaActual],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: const Color(0xFFE9783F),
            ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: paginas[paginaActual],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: paginaActual,
        onTap: (index) {
          setState(() {
            paginaActual = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE9783F),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/amelia.jpg',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
            label: 'Amelia',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Foro'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Yo'),
        ],
      ),
    );
  }
}
