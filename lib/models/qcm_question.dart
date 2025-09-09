class QcmQuestion {
  final String category;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String? imagePath;

  QcmQuestion({
    required this.category,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.imagePath,
  });

  bool get isValid {
    return question.trim().isNotEmpty &&
           options.length >= 2 &&
           correctOptionIndex >= 0 &&
           correctOptionIndex < options.length;
  }
}
