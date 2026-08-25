import 'dart:convert';
import 'package:flutter/material.dart';

import '/services/deepseek_service.dart';
import '/prompts/amelia_prompt.dart';
import '/prompts/cooking_prompt.dart';

class StepByStepScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;
  final String instructions;

  const StepByStepScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
    required this.instructions,
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

  Future<void> _startCooking() async {
    await _askAmelia('Quiero comenzar a cocinar esta receta.');
  }

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
        {'role': 'system', 'content': ameliaPrompt},
        {'role': 'system', 'content': cookingPrompt},
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
      messages.add({'role': 'user', 'content': userMessage});

      final response = await _deepSeekService.sendMessage(
        messages: messages,
      );

      _conversation.add({'role': 'user', 'content': userMessage});
      _conversation.add({'role': 'assistant', 'content': response});

      if (!mounted) return;

      setState(() {
        _ameliaMessage = response;
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

  Future<void> _sendDoubt() async {
    final text = _doubtController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _doubtController.clear();
    await _askAmelia(text);
  }

  void _nextStep() {
    if (currentStep < steps.length - 1) {
      setState(() {
        currentStep++;
      });

      _askAmelia(
        'Ya terminé el paso ${currentStep}. Indícame qué debo hacer ahora.',
      );
    } else {
      _finishCooking();
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });

      _askAmelia(
        'Quiero regresar al paso ${currentStep + 1}. Ayúdame a continuar desde ahí.',
      );
    }
  }

  void _finishCooking() {
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 ¡Receta completada con Amelia!'),
        backgroundColor: Color(0xFF2ECC71),
      ),
    );
  }

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
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71),
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
                          backgroundColor: Color(0xFF2ECC71),
                          backgroundImage: AssetImage('assets/amelia.jpg'),
                        ),
                        const SizedBox(height: 14),
                        if (_isLoading)
                          const CircularProgressIndicator(
                            color: Color(0xFF2ECC71),
                          )
                        else
                          Text(
                            _ameliaMessage.isEmpty
                                ? '¡Vamos a cocinar juntos! 👩‍🍳'
                                : _ameliaMessage,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
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
                        hintText: '¿Tienes alguna duda? Pregúntame',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (_) => _sendDoubt(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendDoubt,
                    iconSize: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF2ECC71)),
                    label: const Text(
                      'Anterior',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed:
                        currentStep > 0 && !_isLoading ? _previousStep : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    onPressed: _isLoading ? null : _nextStep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Volver al chat',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}