class StringUtils {
  /// Calculates the Levenshtein distance between two strings.
  static int levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < v0.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,       // Insertion
          v0[j + 1] + 1,   // Deletion
          v0[j] + cost     // Substitution
        ].reduce((min, val) => val < min ? val : min);
      }

      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }

  /// Returns a similarity score between 0.0 and 1.0
  static double similarity(String s1, String s2) {
    int distance = levenshteinDistance(s1, s2);
    int maxLength = s1.length > s2.length ? s1.length : s2.length;
    if (maxLength == 0) return 1.0;
    return 1.0 - (distance / maxLength);
  }

  /// Finds the best fuzzy match of [target] within a larger [rawText].
  /// Uses a sliding window approach to evaluate similarity.
  static double findBestMatch(String rawText, String target) {
    if (rawText.isEmpty || target.isEmpty) return 0.0;
    if (rawText.length <= target.length) return similarity(rawText, target);

    double maxSimilarity = 0.0;
    // Check windows of varying sizes around the target length to account for insertions/deletions
    for (int lengthOffset = -2; lengthOffset <= 2; lengthOffset++) {
      int windowSize = target.length + lengthOffset;
      if (windowSize <= 0 || windowSize > rawText.length) continue;

      for (int i = 0; i <= rawText.length - windowSize; i++) {
        String sub = rawText.substring(i, i + windowSize);
        double sim = similarity(sub, target);
        if (sim > maxSimilarity) {
          maxSimilarity = sim;
        }
      }
    }
    return maxSimilarity;
  }
}
