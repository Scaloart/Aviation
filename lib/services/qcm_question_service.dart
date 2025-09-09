import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:brie_fly/models/qcm_question.dart';

class QcmQuestionService {
  Future<Map<String, List<QcmQuestion>>> loadQuestions() async {
    final String jsonString = await rootBundle.loadString('assets/qcm_data.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);

    final Map<String, List<QcmQuestion>> questionsByCategory = {};

    jsonMap.forEach((category, questionsData) {
      final List<QcmQuestion> questions = (questionsData as List).map((qData) {
        return QcmQuestion(
          category: category,
          question: qData['question'],
          options: List<String>.from(qData['options']),
          correctOptionIndex: qData['correctOptionIndex'],
        );
      }).toList();
      questionsByCategory[category] = questions;
    });

    return questionsByCategory;
  }
}


