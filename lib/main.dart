import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga la API Key de Gemini desde el archivo .env
  // (usado por el módulo de reconocimiento de ingredientes)
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RecetiasApp());
}

class RecetiasApp extends StatelessWidget {
  const RecetiasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recetias',
      theme: ThemeData(
        primaryColor: const Color(0xFFE9783F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE9783F),
          primary: const Color(0xFFE9783F),
          secondary: const Color(0xFFF3A477),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF7EC),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras Firebase verifica la sesión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE9783F)),
            ),
          );
        }

        // Hay una sesión activa
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // No hay sesión
        return const LoginScreen();
      },
    );
  }
}
