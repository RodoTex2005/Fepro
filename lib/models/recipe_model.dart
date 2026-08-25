class RecipeModel {
  final String name;
  final String description;
  final int? servings;
  final String time;
  final String difficulty;
  final List<String> ingredients;
  final List<String> optionalIngredients;
  final List<String> preparation;
  final String advice;
  final String finalMessage;

  RecipeModel({
    required this.name,
    required this.description,
    this.servings,
    required this.time,
    required this.difficulty,
    required this.ingredients,
    required this.optionalIngredients,
    required this.preparation,
    required this.advice,
    required this.finalMessage,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      servings: json['servings'],
      time: json['time'] ?? '',
      difficulty: json['difficulty'] ?? '',
      ingredients: List<String>.from(
        json['ingredients'] ?? [],
      ),
      optionalIngredients: List<String>.from(
        json['optionalIngredients'] ?? [],
      ),
      preparation: List<String>.from(
        json['preparation'] ?? [],
      ),
      advice: json['advice'] ?? '',
      finalMessage: json['finalMessage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'servings': servings,
      'time': time,
      'difficulty': difficulty,
      'ingredients': ingredients,
      'optionalIngredients': optionalIngredients,
      'preparation': preparation,
      'advice': advice,
      'finalMessage': finalMessage,
    };
  }
}