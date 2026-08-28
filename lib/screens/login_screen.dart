import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  bool _isGoogleLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
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

  // ============================================================
  // LOGIN CON USUARIO Y CONTRASEÑA
  // ============================================================

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

      final datosUsuario = documento.data()!;

      final correo = datosUsuario['correo']?.toString() ?? '';

      if (correo.isEmpty) {
        _mostrarMensaje(
          'No se encontró un correo asociado a este usuario.',
        );
        return;
      }

      print('Usuario encontrado.');
      print('Correo asociado: $correo');

      final credencial =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );

      final usuarioFirebase = credencial.user;

      if (usuarioFirebase == null) {
        _mostrarMensaje('No se pudo iniciar sesión.');
        return;
      }

      if (!usuarioFirebase.emailVerified) {
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          await _mostrarCorreoNoVerificado();
        }

        return;
      }

      print('LOGIN CORRECTO');
      print('CORREO VERIFICADO');

      if (!mounted) return;

      _mostrarMensaje('¡Bienvenido a Recetias!');

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

        case 'network-request-failed':
          mensaje =
              'No hay conexión a Internet. Revisa tu conexión.';
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
        _mostrarMensaje(
          'Ocurrió un error al iniciar sesión.',
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
  // LOGIN CON GOOGLE
  // ============================================================

  Future<void> _loginConGoogle() async {
    if (_isLoading || _isGoogleLoading) return;

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      print('INICIANDO LOGIN CON GOOGLE');

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser =
          await googleSignIn.authenticate();

      print('CUENTA GOOGLE SELECCIONADA');
      print('Correo Google: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      print('================ GOOGLE USER ================');
      print('NOMBRE GOOGLE: ${googleUser.displayName}');
      print('CORREO GOOGLE: ${googleUser.email}');
      print('ID GOOGLE: ${googleUser.id}');
      print('ID TOKEN: ${googleAuth.idToken != null}');
      print('==============================================');

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user == null) {
        throw Exception(
          'No se pudo obtener el usuario de Google.',
        );
      }

      // ========================================================
      // INFORMACIÓN DEL USUARIO DE FIREBASE
      // ========================================================

      print('================ FIREBASE USER ================');
      print('UID: ${user.uid}');
      print('NOMBRE: ${user.displayName}');
      print('CORREO: ${user.email}');
      print('PHOTO URL: ${user.photoURL}');
      print('PROVIDER: ${user.providerData.map((p) => p.providerId)}');
      print('================================================');

      // ========================================================
      // OBTENER FOTO DE GOOGLE
      // ========================================================

      String fotoPerfil = user.photoURL ?? '';

      if (fotoPerfil.isEmpty) {
        print('LA FOTO DE FIREBASE VIENE VACÍA.');

        // Intentamos obtener nuevamente la información
        // del usuario después de la autenticación.
        await user.reload();

        final usuarioActualizado =
            FirebaseAuth.instance.currentUser;

        fotoPerfil =
            usuarioActualizado?.photoURL ?? '';

        print(
          'PHOTO URL DESPUÉS DE RELOAD: $fotoPerfil',
        );
      }

      // ========================================================
      // BUSCAR DOCUMENTO DEL USUARIO
      // ========================================================

      final usuarioDocumento = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      // ========================================================
      // SI ES USUARIO NUEVO
      // ========================================================

      if (!usuarioDocumento.exists) {
        String nombreUsuario =
            user.displayName?.trim() ?? '';

        if (nombreUsuario.isEmpty) {
          nombreUsuario = 'Usuario';
        }

        // Hacemos el nombre único para usuarios_login.
        String usuarioBase = nombreUsuario
            .toLowerCase()
            .replaceAll(
              RegExp(r'[^a-z0-9áéíóúñü]'),
              '',
            );

        if (usuarioBase.isEmpty) {
          usuarioBase = 'usuario';
        }

        String usuarioFinal = usuarioBase;

        int contador = 1;

        while (true) {
          final existente = await FirebaseFirestore.instance
              .collection('usuarios_login')
              .doc(usuarioFinal)
              .get();

          if (!existente.exists) {
            break;
          }

          usuarioFinal = '$usuarioBase$contador';
          contador++;
        }

        // ======================================================
        // CREAR USUARIO EN usuarios
        // ======================================================

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'usuario': usuarioFinal,
          'correo': user.email ?? '',
          'fotoPerfil': fotoPerfil,
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

        print('==============================================');
        print('USUARIO GOOGLE CREADO EN FIRESTORE');
        print('USUARIO: $usuarioFinal');
        print('FOTO GUARDADA: $fotoPerfil');
        print('==============================================');

        // ======================================================
        // CREAR RELACIÓN usuario -> correo
        // ======================================================

        await FirebaseFirestore.instance
            .collection('usuarios_login')
            .doc(usuarioFinal)
            .set({
          'usuario': usuarioFinal,
          'correo': user.email ?? '',
          'uid': user.uid,
        });
      } else {
        // ======================================================
        // USUARIO GOOGLE YA EXISTE
        // ======================================================

        print(
          'EL USUARIO GOOGLE YA EXISTÍA EN FIRESTORE',
        );

        final datosExistentes =
            usuarioDocumento.data() ?? {};

        final fotoExistente =
            datosExistentes['fotoPerfil']?.toString() ?? '';

        print('FOTO ACTUAL EN FIRESTORE: $fotoExistente');
        print('FOTO DE GOOGLE: $fotoPerfil');

        // Si tenemos una foto de Google, actualizamos
        // fotoPerfil para corregir registros anteriores
        // que tenían el campo vacío.
        if (fotoPerfil.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .update({
            'fotoPerfil': fotoPerfil,
          });

          print(
            'FOTO DE PERFIL ACTUALIZADA EN FIRESTORE.',
          );
        }
      }

      if (!mounted) return;

      _mostrarMensaje(
        '¡Bienvenido a Recetias!',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      print('========================================');
      print('ERROR GOOGLE FIREBASE');
      print('CODE: ${e.code}');
      print('MENSAJE: ${e.message}');
      print('========================================');

      String mensaje;

      switch (e.code) {
        case 'account-exists-with-different-credential':
          mensaje =
              'Ya existe una cuenta con este correo usando otro método de acceso.';
          break;

        case 'network-request-failed':
          mensaje =
              'No hay conexión a Internet.';
          break;

        default:
          mensaje =
              'Error Firebase: ${e.code}';
      }

      if (mounted) {
        _mostrarMensaje(mensaje);
      }
    } catch (e) {
      print('========================================');
      print('ERROR GOOGLE GENERAL');
      print('TIPO: ${e.runtimeType}');
      print('ERROR: $e');
      print('========================================');

      if (mounted) {
        _mostrarMensaje(
          'Error Google: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CORREO NO VERIFICADO
  // ============================================================

  Future<void> _mostrarCorreoNoVerificado() async {
    bool reenviando = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.mark_email_unread,
                    color: Color(0xFF2ECC71),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Correo no verificado',
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Debes verificar tu correo electrónico antes de '
                'iniciar sesión.\n\n'
                'Revisa tu bandeja de entrada y también la carpeta '
                'de spam.',
              ),
              actions: [
                TextButton(
                  onPressed: reenviando
                      ? null
                      : () async {
                          setDialogState(() {
                            reenviando = true;
                          });

                          try {
                            final usuario =
                                FirebaseAuth.instance.currentUser;

                            if (usuario != null) {
                              await usuario.sendEmailVerification();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Correo de verificación reenviado.',
                                    ),
                                    backgroundColor:
                                        Color(0xFF2ECC71),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            print(
                              'ERROR AL REENVIAR VERIFICACIÓN: $e',
                            );
                          }

                          if (context.mounted) {
                            setDialogState(() {
                              reenviando = false;
                            });
                          }
                        },
                  child: reenviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Reenviar correo',
                        ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Entendido',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    await FirebaseAuth.instance.signOut();
  }

  // ============================================================
  // MENSAJE
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Card(
              elevation: 20,
              shadowColor:
                  const Color(0xFF2ECC71).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // ==================================================
                    // ROBOT
                    // ==================================================

                    Image.asset(
                      'assets/robot.jpeg',
                      height: 120,
                      width: 120,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71)
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            size: 60,
                            color: Color(0xFF2ECC71),
                          ),
                        );
                      },
                    ),

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
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ==================================================
                    // USUARIO
                    // ==================================================

                    TextField(
                      controller: usuarioController,
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon:
                            const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide:
                              BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFFDFBF7),
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
                        prefixIcon:
                            const Icon(Icons.lock),
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
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide:
                              BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFFDFBF7),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // INGRESAR
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF2ECC71),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed:
                            (_isLoading ||
                                    _isGoogleLoading)
                                ? null
                                : _login,
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
                                'Ingresar',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // SEPARADOR
                    // ==================================================

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey
                                .withOpacity(0.4),
                          ),
                        ),
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: Text(
                            'O',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey
                                .withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // GOOGLE
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        style:
                            OutlinedButton.styleFrom(
                          backgroundColor:
                              Colors.white,
                          side: BorderSide(
                            color: Colors.grey
                                .withOpacity(0.4),
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            (_isLoading ||
                                    _isGoogleLoading)
                                ? null
                                : _loginConGoogle,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.login,
                                color: Colors.black87,
                              ),
                        label: const Text(
                          'Continuar con Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // REGISTRO
                    // ==================================================

                    TextButton(
                      onPressed:
                          (_isLoading ||
                                  _isGoogleLoading)
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                      child: const Text(
                        '¿No tienes cuenta? Regístrate',
                        style: TextStyle(
                          color:
                              Color(0xFF2ECC71),
                          fontWeight:
                              FontWeight.w500,
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