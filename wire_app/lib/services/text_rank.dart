class TextRank {
  static List<String> summarize(String rawHtml) {
    // 1. Defensive Regex: Strip all HTML tags, scripts, and image links
    String cleanText = rawHtml.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanText.isEmpty) return ["No summary available."];

    // 2. Split into sentences
    List<String> sentences = cleanText.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 3) return sentences;

    // 3. Brutalist Scoring (Longer, data-dense sentences score higher)
    // In a full production app we'd map word frequencies, but for speed
    // and zero-bloat, we prioritize sentences with the most character density
    // between 40 and 150 chars (avoiding tiny fragments and massive run-ons).
    sentences.sort((a, b) {
      int scoreA = _scoreSentence(a);
      int scoreB = _scoreSentence(b);
      return scoreB.compareTo(scoreA); // Descending
    });

    // 4. Return the top 3
    return sentences.take(3).map((e) => "• ${e.trim()}").toList();
  }

  static int _scoreSentence(String sentence) {
    int len = sentence.length;
    if (len < 40 || len > 200) return 0; // Penalize garbage lengths
    return len; // Simple heuristic: optimal length sentences hold the most context
  }
}
