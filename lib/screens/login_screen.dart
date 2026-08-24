import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final usuarioController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    usuarioController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
  final usuario = usuarioController.text.trim();
  final password = passwordController.text;

  if (usuario.isEmpty || password.isEmpty) {
    _mostrarMensaje('Completa todos los campos.');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    print('Intentando iniciar sesión...');
    print('Usuario: $usuario');

    // Buscar el usuario en la colección usuarios_login
    final documento = await FirebaseFirestore.instance
        .collection('usuarios_login')
        .doc(usuario.toLowerCase())
        .get();

    if (!documento.exists) {
      print('USUARIO NO ENCONTRADO');

      if (mounted) {
        _mostrarMensaje('El usuario no existe.');
      }

      return;
    }

    // Obtener los datos del usuario
    final datosUsuario = documento.data()!;
    final correo = datosUsuario['correo'] as String;

    print('Usuario encontrado.');
    print('Correo asociado: $correo');

    // Iniciar sesión con Firebase Authentication
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: correo,
      password: password,
    );

    print('LOGIN CORRECTO');

    if (!mounted) return;

    _mostrarMensaje('¡Bienvenido a Recetias!');

    // Ir al Home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  } on FirebaseAuthException catch (e) {
    print('ERROR DE FIREBASE AUTH: ${e.code}');
    print('MENSAJE: ${e.message}');

    String mensaje;

    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        mensaje = 'Usuario o contraseña incorrectos.';
        break;

      case 'user-not-found':
        mensaje = 'El usuario no existe.';
        break;

      case 'invalid-email':
        mensaje = 'El correo electrónico no es válido.';
        break;

      case 'user-disabled':
        mensaje = 'Esta cuenta ha sido deshabilitada.';
        break;

      case 'too-many-requests':
        mensaje =
            'Demasiados intentos. Intenta nuevamente más tarde.';
        break;

      default:
        mensaje = 'No se pudo iniciar sesión.';
    }

    if (mounted) {
      _mostrarMensaje(mensaje);
    }
  } catch (e) {
    print('ERROR GENERAL: $e');

    if (mounted) {
      _mostrarMensaje('Ocurrió un error al iniciar sesión.');
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

void _mostrarMensaje(String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: const Color(0xFF2ECC71),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Card(
              elevation: 20,
              shadowColor: const Color(0xFF2ECC71).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // ===== IMAGEN ROBOT =====
                    Image.asset(
                      'assets/robot.jpeg',
                      height: 120,
                      width: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy, // <-- CORREGIDO
                            size: 60,
                            color: Color(0xFF2ECC71),
                          ),
                        );
                      },
                    ),
                    // ============================
                    const SizedBox(height: 20),
                    const Text(
                      'Recetias',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF27AE60),
                      ),
                    ),
                    const Text(
                      '¡Bienvenido de vuelta!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    TextField(
                      controller: usuarioController,
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFDFBF7),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFDFBF7),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Ingresar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                        onPressed: _isLoading ? null : _login,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            '¿No tienes cuenta? Regístrate',
                            style: TextStyle(
                              color: Color(0xFF2ECC71),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
