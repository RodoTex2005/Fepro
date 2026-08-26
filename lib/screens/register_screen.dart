import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usuarioController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    usuarioController.dispose();
    correoController.dispose();
    passwordController.dispose();
    confirmarPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // REGISTRAR USUARIO
  // ============================================================

  Future<void> _registrarUsuario() async {
    print('BOTON CREAR CUENTA PRESIONADO');

    final usuario = usuarioController.text.trim();
    final correo = correoController.text.trim();
    final password = passwordController.text;
    final confirmarPassword = confirmarPasswordController.text;

    print('Usuario: $usuario');
    print('Correo: $correo');

    // ---------------- VALIDACIONES ----------------

    if (usuario.isEmpty ||
        correo.isEmpty ||
        password.isEmpty ||
        confirmarPassword.isEmpty) {
      print('ERROR: Hay campos vacíos');
      _mostrarMensaje('Completa todos los campos.');
      return;
    }

    if (password != confirmarPassword) {
      print('ERROR: Las contraseñas no coinciden');
      _mostrarMensaje('Las contraseñas no coinciden.');
      return;
    }

    if (password.length < 6) {
      print('ERROR: Contraseña demasiado corta');
      _mostrarMensaje(
        'La contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }

    print('VALIDACIONES CORRECTAS');

    setState(() {
      _isLoading = true;
    });

    try {
      // ==========================================================
      // 1. COMPROBAR QUE EL NOMBRE DE USUARIO NO ESTÉ OCUPADO
      // ==========================================================

      print('Comprobando disponibilidad del usuario...');

      final usuarioExistente = await FirebaseFirestore.instance
          .collection('usuarios_login')
          .doc(usuario.toLowerCase())
          .get();

      if (usuarioExistente.exists) {
        print('ERROR: El usuario ya existe');

        if (mounted) {
          _mostrarMensaje('Ese nombre de usuario ya está ocupado.');
        }

        return;
      }

      // ==========================================================
      // 2. CREAR USUARIO EN FIREBASE AUTHENTICATION
      // ==========================================================

      print('Intentando crear usuario en Firebase Authentication...');

      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );

      print('USUARIO CREADO EN AUTHENTICATION');

      final uid = credencial.user!.uid;

      print('UID: $uid');

      // ==========================================================
      // 3. GUARDAR DATOS COMPLETOS EN USUARIOS
      // ==========================================================

      print('Intentando crear documento en Firestore...');

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .set({
        'uid': uid,
        'usuario': usuario,
        'correo': correo,
        'fotoPerfil': '',
        'fechaRegistro': FieldValue.serverTimestamp(),
        'nivel': 1,
        'experiencia': 0,

        // Estadísticas
        'recetasGeneradas': 0,
        'recetasPublicadas': 0,
        'recetasGuardadas': 0,
        'likesRecibidos': 0,
        'likesDados': 0,

        // Marcos
        'marcoSeleccionado': 'classic',
        'marcosDesbloqueados': ['classic'],
      });

      print('DOCUMENTO CREADO EN USUARIOS');

      // ==========================================================
      // 4. GUARDAR RELACIÓN USUARIO -> CORREO
      // ==========================================================

      await FirebaseFirestore.instance
          .collection('usuarios_login')
          .doc(usuario.toLowerCase())
          .set({
        'usuario': usuario,
        'correo': correo,
        'uid': uid,
      });

      print('DOCUMENTO CREADO EN USUARIOS_LOGIN');

      // ==========================================================
      // 5. REGISTRO TERMINADO
      // ==========================================================

      if (!mounted) return;

      _mostrarMensaje('¡Cuenta creada correctamente!');

      // Regresar a Login
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      print('ERROR DE FIREBASE AUTH: ${e.code}');
      print('MENSAJE: ${e.message}');

      String mensaje;

      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Este correo ya está registrado.';
          break;

        case 'invalid-email':
          mensaje = 'El correo electrónico no es válido.';
          break;

        case 'weak-password':
          mensaje = 'La contraseña es demasiado débil.';
          break;

        case 'operation-not-allowed':
          mensaje = 'El registro con correo y contraseña no está habilitado.';
          break;

        default:
          mensaje = 'No se pudo crear la cuenta.';
      }

      if (mounted) {
        _mostrarMensaje(mensaje);
      }
    } catch (e) {
      print('ERROR GENERAL: $e');

      if (mounted) {
        _mostrarMensaje(
          'Ocurrió un error al crear la cuenta.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MENSAJES
  // ============================================================

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFF2ECC71),
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

      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),

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

                  // ==================================================
                  // ICONO
                  // ==================================================

                  const Icon(
                    Icons.person_add,
                    size: 70,
                    color: Color(0xFF2ECC71),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // TITULO
                  // ==================================================

                  const Text(
                    'Crear cuenta',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF27AE60),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // USUARIO
                  // ==================================================

                  TextField(
                    controller: usuarioController,

                    decoration: InputDecoration(
                      labelText: 'Usuario',

                      prefixIcon: const Icon(
                        Icons.person,
                      ),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),

                      filled: true,

                      fillColor: const Color(0xFFFDFBF7),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // CORREO
                  // ==================================================

                  TextField(
                    controller: correoController,

                    keyboardType:
                        TextInputType.emailAddress,

                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',

                      prefixIcon: const Icon(
                        Icons.email,
                      ),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),

                      filled: true,

                      fillColor: const Color(0xFFFDFBF7),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // CONTRASEÑA
                  // ==================================================

                  TextField(
                    controller: passwordController,

                    obscureText: _obscurePassword,

                    decoration: InputDecoration(
                      labelText: 'Contraseña',

                      prefixIcon: const Icon(
                        Icons.lock,
                      ),

                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),

                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
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

                  const SizedBox(height: 16),

                  // ==================================================
                  // CONFIRMAR CONTRASEÑA
                  // ==================================================

                  TextField(
                    controller:
                        confirmarPasswordController,

                    obscureText:
                        _obscureConfirmPassword,

                    decoration: InputDecoration(
                      labelText:
                          'Confirmar contraseña',

                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),

                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),

                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword;
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

                  // ==================================================
                  // BOTÓN CREAR CUENTA
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 54,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF2ECC71),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),

                        elevation: 4,
                      ),

                      // IMPORTANTE:
                      // NO lleva paréntesis.
                      onPressed: _isLoading
                          ? null
                          : _registrarUsuario,

                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,

                              child:
                                  CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )

                          : const Text(
                              'Crear cuenta',

                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}