import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepSeekService {
  static const String _apiUrl =
      'https://api.deepseek.com/chat/completions';

  static const String _apiKey = 'sk-83e6ad7000a54e0282b91f0e03c8a394';

  Future<String> sendMessage({
    required List<Map<String, String>> messages,
  }) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-v4-flash',
        'messages': messages,
        'thinking': {
          'type': 'disabled',
        },
        'temperature': 0.7,
        'max_tokens': 1000,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error de DeepSeek: ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    return data['choices'][0]['message']['content'];
  }
}