import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/food.dart';
import '../models/food_model.dart';
import '../services/food_service.dart';

class FoodRepository {
  final FoodService _foodService;
  final SharedPreferences _prefs;

  FoodRepository(this._foodService, this._prefs);

  Future<List<Food>> getDailyFoodLog(DateTime date) async {
    final String key = 'food_log_${date.toIso8601String().split('T')[0]}';
    final String? storedData = _prefs.getString(key);

    if (storedData != null) {
      final List<dynamic> jsonList = json.decode(storedData);
      return jsonList
          .map((json) => FoodModel.fromJson(Map<String, dynamic>.from(json)))
          .map((model) => model.toDomain())
          .toList();
    }
    return [];
  }

  Future<Either<Failure, Unit>> addFoodItem(Food item) async {
    try {
      final String key =
          'food_log_${item.timestamp.toIso8601String().split('T')[0]}';
      List<Food> currentLog = await getDailyFoodLog(item.timestamp);
      currentLog.add(item);

      await _prefs.setString(
        key,
        json.encode(currentLog.map((item) => FoodModel.fromDomain(item).toJson()).toList()),
      );
      return right(unit);
    } catch (e) {
      return left(CacheFailure('Failed to add food', cause: e));
    }
  }

  Future<Either<Failure, Food>> detectFoodFromImage(File image) async {
    return await _foodService.detectFoodAndCalories(image);
  }

  Future<Either<Failure, Unit>> deleteFoodItem(Food item) async {
    try {
      final String key =
          'food_log_${item.timestamp.toIso8601String().split('T')[0]}';
      List<Food> currentLog = await getDailyFoodLog(item.timestamp);
      currentLog.removeWhere((existingItem) => existingItem.id == item.id);

      await _prefs.setString(
        key,
        json.encode(currentLog.map((item) => FoodModel.fromDomain(item).toJson()).toList()),
      );
      return right(unit);
    } catch (e) {
      return left(CacheFailure('Failed to delete food', cause: e));
    }
  }

  Future<Either<Failure, Unit>> updateFoodItem(Food item) async {
    try {
      final String key =
          'food_log_${item.timestamp.toIso8601String().split('T')[0]}';
      List<Food> currentLog = await getDailyFoodLog(item.timestamp);
      final index = currentLog.indexWhere(
        (existingItem) => existingItem.id == item.id,
      );

      if (index != -1) {
        currentLog[index] = item;
        await _prefs.setString(
          key,
          json.encode(currentLog.map((item) => FoodModel.fromDomain(item).toJson()).toList()),
        );
      }
      return right(unit);
    } catch (e) {
      return left(CacheFailure('Failed to update food', cause: e));
    }
  }
}
