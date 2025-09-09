import 'package:brie_fly/models/qcm_question.dart';

class ExamRecord {
  final String id; // unique id
  final DateTime date;
  final int durationMinutes;
  final int score;
  final int total;
  final List<String> categories;
  final List<QcmQuestion> questions;
  final List<int?> userAnswers; // index per question, null if unanswered
  // Resume-related
  final bool completed; // true when submitted; false if in-progress
  final int remainingSeconds; // only relevant if not completed
  final int currentIndex; // question index at pause

  ExamRecord({
    required this.id,
    required this.date,
    required this.durationMinutes,
    required this.score,
    required this.total,
    required this.categories,
    required this.questions,
    required this.userAnswers,
    this.completed = true,
    this.remainingSeconds = 0,
    this.currentIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'score': score,
        'total': total,
        'categories': categories,
        'questions': questions
            .map((q) => {
                  'category': q.category,
                  'question': q.question,
                  'options': q.options,
                  'correctOptionIndex': q.correctOptionIndex,
                })
            .toList(),
        'userAnswers': userAnswers,
        'completed': completed,
        'remainingSeconds': remainingSeconds,
        'currentIndex': currentIndex,
      };

  static ExamRecord fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List)
        .map((q) => QcmQuestion(
              category: q['category'],
              question: q['question'],
              options: List<String>.from(q['options']),
              correctOptionIndex: q['correctOptionIndex'] as int,
            ))
        .toList();
    return ExamRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['durationMinutes'] as int,
      score: json['score'] as int,
      total: json['total'] as int,
      categories: List<String>.from(json['categories'] as List),
      questions: questions,
      userAnswers:
          (json['userAnswers'] as List).map((e) => e == null ? null : e as int).toList(),
      completed: (json['completed'] as bool?) ?? true,
      remainingSeconds: (json['remainingSeconds'] as int?) ?? 0,
      currentIndex: (json['currentIndex'] as int?) ?? 0,
    );
  }
}

