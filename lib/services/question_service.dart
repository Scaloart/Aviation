import 'package:flutter/services.dart' show rootBundle;
import 'package:brie_fly/models/question.dart';

class QuestionService {
  Future<List<Question>> loadQuestions() async {
    const validCategories = [
      'METEOROLOGIE',
      'REGLEMENTATION',
      'DEFINITIONS',
      'AEROMEDECINE',
      'NAVIGATION',
      'INSTRUMENT DE BORD',
      'AEROTECHNIQUE',
      'TECHNIQUE DE VOL'
    ];

    final String fileContent = await rootBundle.loadString('assets/qr_data.txt');
    final List<String> lines = fileContent.split('\n');
    
    List<Question> questions = [];
    String currentCategory = '';
    String currentQuestion = '';
    String currentAnswer = '';

    // This regex now matches a number followed by either a dash or a dot.
    final _questionRegex = RegExp(r'^\d+\s*[.-]\s*');

    for (String line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final potentialCategory = trimmedLine.toUpperCase();

      if (validCategories.contains(potentialCategory)) {
        if (currentQuestion.isNotEmpty) {
          questions.add(Question(category: currentCategory, question: currentQuestion, answer: currentAnswer.trim()));
        }
        currentCategory = potentialCategory;
        currentQuestion = '';
        currentAnswer = '';
        continue; 
      }

      if (_questionRegex.hasMatch(trimmedLine) && trimmedLine.endsWith('?')) {
        if (currentQuestion.isNotEmpty) {
          questions.add(Question(category: currentCategory, question: currentQuestion, answer: currentAnswer.trim()));
        }
        final match = _questionRegex.firstMatch(trimmedLine);
        if (match != null) {
          currentQuestion = trimmedLine.substring(match.end).trim();
        }
        currentAnswer = '';
        continue;
      }

      if (currentQuestion.isNotEmpty) {
        currentAnswer += trimmedLine + '\n';
      }
    }

    if (currentQuestion.isNotEmpty) {
      questions.add(Question(category: currentCategory, question: currentQuestion, answer: currentAnswer.trim()));
    }
    return questions;
  }
}

