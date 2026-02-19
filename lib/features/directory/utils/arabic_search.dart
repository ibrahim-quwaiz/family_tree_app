import '../models/directory_person.dart';

class ArabicSearch {
  /// تطبيع النص العربي
  static String normalize(String text) {
    var result = text;
    result = result.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
    result = result.replaceAll(RegExp(r'[أإآ]'), 'ا');
    result = result.replaceAll('ى', 'ي');
    result = result.replaceAll('ة', 'ه');
    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    return result.toLowerCase();
  }

  /// بحث ذكي - يدعم السلسلة النسبية
  static List<DirectoryPerson> search({
    required List<DirectoryPerson> people,
    required String query,
  }) {
    if (query.isEmpty) return people;

    final normalizedQuery = normalize(query);
    final queryWords = normalizedQuery
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) return people;

    // إذا كلمة واحدة → بحث عادي
    if (queryWords.length == 1) {
      return _simpleSearch(people, normalizedQuery);
    }

    // إذا كلمتين أو أكثر → بحث بالسلسلة النسبية
    return _ancestralSearch(people, queryWords);
  }

  /// بحث عادي بكلمة واحدة
  static List<DirectoryPerson> _simpleSearch(
    List<DirectoryPerson> people,
    String query,
  ) {
    final results = <_SearchResult>[];

    for (var person in people) {
      int score = 0;
      final name = normalize(person.name);
      final city = normalize(person.residenceCity ?? '');
      final job = normalize(person.job ?? '');

      if (name == query) score += 100;
      else if (name.startsWith(query)) score += 80;
      else if (name.contains(query)) score += 60;

      if (city.contains(query)) score += 20;
      if (job.contains(query)) score += 15;

      if (score > 0) results.add(_SearchResult(person: person, score: score));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.map((r) => r.person).toList();
  }

  /// بحث بالسلسلة النسبية
  /// "محمد عبدالله سعد إبراهيم" = محمد بن عبدالله بن سعد بن إبراهيم
  static List<DirectoryPerson> _ancestralSearch(
    List<DirectoryPerson> people,
    List<String> names,
  ) {
    print('🔍 _ancestralSearch: البحث بـ ${names.length} أسماء: $names');
    final results = <_SearchResult>[];

    for (var person in people) {
      final personName = normalize(person.name);

      // تحقق أن اسم الشخص يطابق الاسم الأول
      if (!personName.contains(names[0])) continue;

      // تحقق من سلسلة الأجداد
      final chainScore = _checkAncestralChain(person, names.sublist(1));

      if (chainScore > 0) {
        final nameBonus = personName.startsWith(names[0]) ? 20 : 0;
        results.add(_SearchResult(
          person: person,
          score: chainScore + nameBonus,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.map((r) => r.person).toList();
  }

  /// تحقق من سلسلة الأجداد (حتى 4 أجيال: أب، جد، جد الجد، جد جد الجد)
  static int _checkAncestralChain(
    DirectoryPerson person,
    List<String> ancestorNames,
  ) {
    if (ancestorNames.isEmpty) return 50;

    print('🔍 _checkAncestralChain: البحث عن ${ancestorNames.length} أجداد');
    print('   ancestorNames: $ancestorNames');
    print('   person: ${person.name}, father: ${person.fatherName}, grandfather: ${person.grandfatherName}, greatGrandfather: ${person.greatGrandfatherName}, greatGreatGrandfather: ${person.greatGreatGrandfatherName}');

    int score = 50;

    // الأب (names[0])
    if (ancestorNames.length >= 1) {
      final fatherName = normalize(person.fatherName ?? '');
      if (fatherName.isEmpty) return 0;
      if (!fatherName.contains(ancestorNames[0])) return 0;
      
      if (fatherName == ancestorNames[0]) score += 30;
      else if (fatherName.startsWith(ancestorNames[0])) score += 20;
      else score += 10;
    }

    // الجد (names[1])
    if (ancestorNames.length >= 2) {
      final grandfatherName = normalize(person.grandfatherName ?? '');
      if (grandfatherName.isEmpty) return score; // لا نرفض، لكن لا نزيد نقاط
      if (!grandfatherName.contains(ancestorNames[1])) return 0;
      
      if (grandfatherName == ancestorNames[1]) score += 25;
      else if (grandfatherName.startsWith(ancestorNames[1])) score += 15;
      else score += 10;
    }

    // جد الجد (names[2])
    if (ancestorNames.length >= 3) {
      final greatGrandfatherName = normalize(person.greatGrandfatherName ?? '');
      if (greatGrandfatherName.isEmpty) return 0;
      if (!greatGrandfatherName.contains(ancestorNames[2])) return 0;
      
      if (greatGrandfatherName == ancestorNames[2]) score += 20;
      else if (greatGrandfatherName.startsWith(ancestorNames[2])) score += 10;
      else score += 5;
    }

    // جد جد الجد (names[3])
    if (ancestorNames.length >= 4) {
      print('   ✅ التحقق من الجيل الرابع (names[3]): "${ancestorNames[3]}"');
      final greatGreatGrandfatherName = normalize(person.greatGreatGrandfatherName ?? '');
      print('   greatGreatGrandfatherName: "$greatGreatGrandfatherName"');
      if (greatGreatGrandfatherName.isEmpty) {
        print('   ❌ greatGreatGrandfatherName فارغ - رفض النتيجة');
        return 0;
      }
      if (!greatGreatGrandfatherName.contains(ancestorNames[3])) {
        print('   ❌ greatGreatGrandfatherName لا يحتوي على "${ancestorNames[3]}" - رفض النتيجة');
        return 0;
      }
      
      print('   ✅ تطابق الجيل الرابع!');
      if (greatGreatGrandfatherName == ancestorNames[3]) score += 15;
      else if (greatGreatGrandfatherName.startsWith(ancestorNames[3])) score += 8;
      else score += 3;
    }

    print('   ✅ النتيجة النهائية: $score');
    return score;
  }

  /// توليد اقتراحات للـ Autocomplete
  static List<String> getSuggestions({
    required List<DirectoryPerson> people,
    required String query,
    int maxSuggestions = 5,
  }) {
    if (query.length < 2) return [];

    final normalizedQuery = normalize(query);
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();

    // إذا كلمة واحدة → اقترح أسماء
    if (queryWords.length <= 1) {
      final suggestions = <String>{};
      for (var person in people) {
        if (normalize(person.name).contains(normalizedQuery)) {
          suggestions.add(person.name);
          if (suggestions.length >= maxSuggestions) break;
        }
      }
      return suggestions.toList();
    }

    // إذا كلمتين أو أكثر → اقترح "الاسم بن الأب بن الجد"
    final results = search(people: people, query: query);
    return results
        .take(maxSuggestions)
        .map((p) => _buildSuggestionText(p))
        .toList();
  }

  /// بناء نص الاقتراح مع السلسلة النسبية
  static String _buildSuggestionText(DirectoryPerson person) {
    final parts = [person.name];
    
    if (person.fatherName != null && person.fatherName!.isNotEmpty) {
      parts.add(person.fatherName!);
    }
    
    if (person.grandfatherName != null && person.grandfatherName!.isNotEmpty) {
      parts.add(person.grandfatherName!);
    }
    
    return parts.join(' بن ');
  }
}

class _SearchResult {
  final DirectoryPerson person;
  final int score;
  _SearchResult({required this.person, required this.score});
}
