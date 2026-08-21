import 'package:flutter/material.dart';

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
  int currentStep = 0;
  late List<String> steps;
  final TextEditingController _doubtController = TextEditingController();

  @override
  void initState() {
    super.initState();
    steps = widget.instructions
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  void _sendDoubt() {
    final text = _doubtController.text.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💬 Tu pregunta: "$text"'),
        backgroundColor: const Color(0xFF2ECC71),
        duration: const Duration(seconds: 2),
      ),
    );
    _doubtController.clear();
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color(0xFFFFF8F0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // ===== INDICADOR DE PASO =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Paso ${currentStep + 1} de ${steps.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ===== CONTENEDOR DE INSTRUCCIÓN =====
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 36,
                        color: Color(0xFF2ECC71),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        steps[currentStep],
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ===== ESPACIO REDUCIDO ENTRE RECETA Y CAMPO =====
            const SizedBox(height: 6), // <-- CASI PEGADO
            // ===== CAMPO PARA ESCRIBIR DUDAS (JUSTO ABAJO DE LA RECETA) =====
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withOpacity(0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendDoubt,
                    iconSize: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ===== BOTONES ANTERIOR Y SIGUIENTE =====
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF2ECC71),
                    ),
                    label: Text(
                      'Anterior',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: currentStep > 0
                        ? () {
                            setState(() {
                              currentStep--;
                            });
                          }
                        : null,
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
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: Text(
                      currentStep < steps.length - 1
                          ? 'Siguiente'
                          : '¡Finalizar!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      if (currentStep < steps.length - 1) {
                        setState(() {
                          currentStep++;
                        });
                      } else {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 ¡Receta completada!'),
                            backgroundColor: Color(0xFF2ECC71),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
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
