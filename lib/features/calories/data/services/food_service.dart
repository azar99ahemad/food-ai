import 'dart:convert';
import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../core/error/failure.dart';
import '../../domain/entities/food.dart';

class FoodService {
  String get _apiKey => dotenv.env['GROK_API_KEY'] ?? '';

  Future<Either<Failure, Food>> detectFoodAndCalories(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return left(NetworkFailure('File not found', cause: imageFile.path));
      }

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $_apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct', // free vision model
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
                {
                  'type': 'text',
                  'text':
                      'Analyze this image and identify the food. '
                      'Estimate its calories, protein, carbs, and fat. '
                      'Return JSON only, no markdown, no explanation, in this exact format: '
                      '{"name": "food name", "calories": 100, "protein": 10, "carbs": 20, "fat": 5}',
                },
              ],
            },
          ],
          'max_tokens': 200,
        }),
      );

      if (response.statusCode != 200) {
        return left(NetworkFailure('API error: ${response.statusCode}', cause: response.body));
      }

      final data = jsonDecode(response.body);
      final output = data['choices'][0]['message']['content'] as String;

      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(output);
      if (match == null) {
        return left(NetworkFailure('No valid JSON found in response', cause: output));
      }

      final foodData = jsonDecode(match.group(0)!);

      return right(Food(id: DateTime.now().millisecondsSinceEpoch.toString(), name: foodData['name'] as String, calories: (foodData['calories'] as num).toDouble(), protein: (foodData['protein'] as num).toDouble(), carbs: (foodData['carbs'] as num).toDouble(), fat: (foodData['fat'] as num).toDouble(), quantity: 100.0, timestamp: DateTime.now()));
    } catch (e) {
      return left(NetworkFailure('Failed to detect food', cause: e));
    }
  }
}
