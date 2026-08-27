import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'step_by_step_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

  class _ForumScreenState extends State<ForumScreen> {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRecetas() {
    return _firestore
        .collection('recetas')
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

   void _openRecipeDetail(Map<String, dynamic> receta) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          receta: receta,
          onLike: () {},
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getRecetas(),
      builder: (context, snapshot) {

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2ECC71),
        ),
      );
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Error al cargar las recetas:\n${snapshot.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final documentos = snapshot.data?.docs ?? [];

    if (documentos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 70,
              color: Color(0xFF2ECC71),
            ),
            SizedBox(height: 16),
            Text(
              'Todavía no hay recetas publicadas.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Genera una receta con Amelia para verla aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: documentos.length,
      itemBuilder: (context, index) {

        final documento = documentos[index];

        final datos = documento.data();

        final receta = <String, dynamic>{
          'id': documento.id,
          'uid': datos['uid'],
          'titulo': datos['nombre'] ?? 'Receta sin nombre',
          'descripcion': datos['descripcion'] ?? '',
          'ingredientes': datos['ingredients'] is List
              ? List<String>.from(datos['ingredients'])
              : <String>[],
          'preparacion': datos['preparation'] is List
              ? List<String>.from(datos['preparation'])
              : <String>[],
          'servings': datos['servings'],
          'time': datos['time'] ?? '',
          'difficulty': datos['difficulty'] ?? '',
          'advice': datos['advice'] ?? '',
          'finalMessage': datos['finalMessage'] ?? '',
          'autor': 'Usuario',
          'fecha': 'Receta publicada',
          'likes': 0,
          'liked': false,
          'comentarios': 0,
          'comentarios_list': <Map<String, String>>[],
        };

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openRecipeDetail(receta),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [

                      CircleAvatar(
                        backgroundColor: const Color(0xFF2ECC71),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(
                              'Usuario',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            const Text(
                              'Receta publicada',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2ECC71),
                        Color(0xFF27AE60),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant,
                      size: 60,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        receta['titulo'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27AE60),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        receta['descripcion'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
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
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '0',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          const Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '0',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          IconButton(
                            icon: const Icon(
                              Icons.share_outlined,
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '📤 Receta compartida',
                                  ),
                                  backgroundColor: Color(0xFF2ECC71),
                                      ),
                                    );
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
            },
          );
        },
      ),
    );
  }
}

// ===== PANTALLA DE DETALLE DE RECETA =====
class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> receta;
  final VoidCallback onLike;

  const RecipeDetailScreen({
    super.key,
    required this.receta,
    required this.onLike,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, String>> comentarios = [];

  @override
  void initState() {
    super.initState();
    comentarios = List<Map<String, String>>.from(
      widget.receta['comentarios_list'],
    );
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      comentarios.add({'usuario': 'Tú', 'texto': text});
      widget.receta['comentarios'] = comentarios.length;
    });

    _commentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💬 Comentario añadido'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

  Future<void> _saveRecipe() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes iniciar sesión para guardar recetas'),
          backgroundColor: Color(0xFFF39C12),
        ),
      );
      return;
    }

    final recetaId = widget.receta['id'];

    if (recetaId == null || recetaId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No se encontró el ID de la receta'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final guardadaQuery = await FirebaseFirestore.instance
        .collection('recetas_guardadas')
        .where('uid', isEqualTo: user.uid)
        .where('recetaId', isEqualTo: recetaId)
        .limit(1)
        .get();

    if (guardadaQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Esta receta ya está en favoritos'),
          backgroundColor: Color(0xFFF39C12),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('recetas_guardadas')
        .add({
      'uid': user.uid,
      'recetaId': recetaId,
      'fechaGuardado': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .update({
      'recetasGuardadas': FieldValue.increment(1),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Receta guardada en favoritos'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  } catch (e) {
    debugPrint('ERROR AL GUARDAR RECETA: $e');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ No se pudo guardar la receta: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _goToCookingMode() {
  final ingredientes =
      List<String>.from(widget.receta['ingredientes'] ?? []);

  final instrucciones =
      List<String>.from(widget.receta['preparacion'] ?? []).join('\n');

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StepByStepScreen(
        recipeName: widget.receta['titulo'] ?? 'Receta',
        ingredients: ingredientes,
        instructions: instrucciones,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final receta = widget.receta;
    final ingredientes =
    List<String>.from(receta['ingredientes'] ?? []);

    final instrucciones =
        List<String>.from(receta['preparacion'] ?? []).join('\n');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RECETAS PARA TI',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        // ===== ICONOS ELIMINADOS DE LA APP BAR =====
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Autor y fecha
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2ECC71),
                  child: Text(
                    receta['autor'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receta['autor'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      receta['fecha'],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              receta['titulo'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              receta['descripcion'],
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Ingredientes
            const Text(
              '🥘 Ingredientes:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            ...ingredientes.map(
              (ing) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF2ECC71)),
                    const SizedBox(width: 8),
                    Text(ing, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instrucciones
            const Text(
              '👩‍🍳 Instrucciones:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                instrucciones,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // ===== BOTONES EN LA PANTALLA =====
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text(
                      'Modo Cocinar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _goToCookingMode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF39C12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Color(0xFFF39C12),
                    ),
                    label: const Text(
                      'Guardar',
                      style: TextStyle(
                        color: Color(0xFFF39C12),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _saveRecipe,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Comentarios
            const Text(
              '💬 Comentarios:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27AE60),
              ),
            ),
            const SizedBox(height: 8),
            ...comentarios
                .map(
                  (com) => Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          com['usuario']!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(com['texto']!),
                      ],
                    ),
                  ),
                )
                .toList(),

            // Campo para agregar comentario
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _addComment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
