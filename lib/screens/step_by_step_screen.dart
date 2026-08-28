import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '/services/deepseek_service.dart';
import '/prompts/amelia_prompt.dart';
import '/prompts/cooking_prompt.dart';

import 'publish_recipe_screen.dart';

class StepByStepScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;
  final String instructions;

  // Receta completa para poder compartirla al finalizar
  final Map<String, dynamic> recipe;

  const StepByStepScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
    required this.instructions,
    required this.recipe,
  });

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  final DeepSeekService _deepSeekService = DeepSeekService();
  final TextEditingController _doubtController = TextEditingController();
  final List<Map<String, String>> _conversation = [];

  String _ameliaMessage = '';
  bool _isLoading = false;
  int currentStep = 0;
  late List<String> steps;

  @override
  void initState() {
    super.initState();

    // Convertir la cadena de texto con saltos de línea en una lista de pasos
    steps = widget.instructions
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _startCooking();
  }

  @override
  void dispose() {
    _doubtController.dispose();
    super.dispose();
  }

  // ============================================================
  // INICIAR COCINA
  // ============================================================

  Future<void> _startCooking() async {
    await _askAmelia('Quiero comenzar a cocinar esta receta.');
  }

  // ============================================================
  // PREGUNTAR A AMELIA
  // ============================================================

  Future<void> _askAmelia(String userMessage) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final recipeData = {
        'name': widget.recipeName,
        'ingredients': widget.ingredients,
        'instructions': widget.instructions,
      };

      final recipeJson = jsonEncode(recipeData);

      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': ameliaPrompt,
        },
        {
          'role': 'system',
          'content': cookingPrompt,
        },
        {
          'role': 'system',
          'content': '''
Esta es la receta que el usuario está preparando:

$recipeJson

Paso actual de la interfaz: ${currentStep + 1} de ${steps.length}.

El paso actual es:
${steps.isNotEmpty && currentStep < steps.length ? steps[currentStep] : 'No hay paso actual.'}

Utiliza esta receta como fuente principal de verdad.
No inventes pasos, ingredientes, tiempos ni cantidades.
''',
        },
      ];

      messages.addAll(_conversation);

      messages.add({
        'role': 'user',
        'content': userMessage,
      });

      final response = await _deepSeekService.sendMessage(
        messages: messages,
      );

      _conversation.add({
        'role': 'user',
        'content': userMessage,
      });

      _conversation.add({
        'role': 'assistant',
        'content': response,
      });

      if (!mounted) return;

      setState(() {
final sanitized = response.replaceAll('*', '');
    _ameliaMessage = sanitized;
      });
    } catch (e) {
      debugPrint('Error en Cocina con Amelia: $e');

      if (!mounted) return;

      setState(() {
        _ameliaMessage =
            'Tuve un pequeño problema para responderte. 😅 Inténtalo nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ENVIAR DUDA
  // ============================================================

  Future<void> _sendDoubt() async {
    final text = _doubtController.text.trim();

    if (text.isEmpty || _isLoading) return;

    _doubtController.clear();

    await _askAmelia(text);
  }

  // ============================================================
  // SIGUIENTE PASO
  // ============================================================

  void _nextStep() {
    if (currentStep < steps.length - 1) {
      setState(() {
        currentStep++;
      });

      _askAmelia(
        'Ya terminé el paso $currentStep. Indícame qué debo hacer ahora.',
      );
    } else {
      _finishCooking();
    }
  }

  // ============================================================
  // PASO ANTERIOR
  // ============================================================

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });

      _askAmelia(
        'Quiero regresar al paso ${currentStep + 1}. '
        'Ayúdame a continuar desde ahí.',
      );
    }
  }

  // ============================================================
  // FINALIZAR RECETA
  // ============================================================

  Future<void> _finishCooking() async {
    if (!mounted) return;

    // ============================================================
    // PREGUNTAR SI QUIERE COMPARTIR
    // ============================================================

    final compartir = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🎉 ¡Receta completada!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFC95D2E),
            ),
          ),
          content: const Text(
            '¡Felicidades! Terminaste de preparar tu receta con Amelia. 👩‍🍳✨\n\n'
            '¿Te gustaría compartir tu logro en el foro?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Ahora no',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9783F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.camera_alt,
              ),
              label: const Text(
                'Compartir logro',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    // ============================================================
    // EL USUARIO NO QUIERE COMPARTIR
    // ============================================================

    if (compartir != true) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🎉 ¡Receta completada con Amelia!',
          ),
          backgroundColor: Color(0xFFE9783F),
        ),
      );

      return;
    }

    // ============================================================
    // EL USUARIO QUIERE COMPARTIR
    // ============================================================

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublishRecipeScreen(
          recipe: widget.recipe,
        ),
      ),
    );

    if (!mounted) return;

    // ============================================================
    // PUBLICACIÓN EXITOSA
    // ============================================================

    if (resultado == true) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🎉 ¡Tu logro fue compartido en el foro!',
          ),
          backgroundColor: Color(0xFFE9783F),
        ),
      );
    }
  }

  // ============================================================
  // INTERFAZ PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipeName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFE9783F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: Column(
          children: [
            // ======================================================
            // INDICADOR DEL PASO
            // ======================================================

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE9783F),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                steps.isEmpty
                    ? 'Cocinando con Amelia'
                    : 'Paso ${currentStep + 1} de ${steps.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ======================================================
            // MENSAJE DE AMELIA
            // ======================================================

            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFE9783F),
                          backgroundImage: AssetImage(
                            'assets/amelia.jpg',
                          ),
                        ),

                        const SizedBox(height: 14),

                        if (_isLoading)
                          const CircularProgressIndicator(
                            color: Color(0xFFE9783F),
                          )
                        else
                          MarkdownBody(
                            data: _ameliaMessage.isEmpty
                                ? '¡Vamos a cocinar juntos! 👩‍🍳'
                                : _ameliaMessage,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                fontSize: 17,
                                height: 1.5,
                              ),
                            ),
                            selectable: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ======================================================
            // CAJA DE DUDAS
            // ======================================================

            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _doubtController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText:
                            '¿Tienes alguna duda? Pregúntame',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      onSubmitted: (_) => _sendDoubt(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9783F),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                    onPressed:
                        _isLoading ? null : _sendDoubt,
                    iconSize: 24,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ======================================================
            // BOTONES ANTERIOR / SIGUIENTE
            // ======================================================

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFE9783F),
                    ),
                    label: const Text(
                      'Anterior',
                      style: TextStyle(
                        color: Color(0xFFE9783F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed:
                        currentStep > 0 && !_isLoading
                            ? _previousStep
                            : null,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE9783F),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      currentStep < steps.length - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                      color: Colors.white,
                    ),
                    label: Text(
                      currentStep < steps.length - 1
                          ? 'Siguiente'
                          : '¡Finalizar!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed:
                        _isLoading ? null : _nextStep,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ======================================================
            // VOLVER AL CHAT
            // ======================================================

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Volver al chat',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// INFO CHIP
// ================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFFC95D2E),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFC95D2E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}