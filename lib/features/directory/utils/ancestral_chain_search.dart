import 'package:collection/collection.dart';
import '../models/directory_person.dart';
import 'arabic_search.dart';

class AncestralChainSearch {
  /// البحث بالسلسلة النسبية
  /// مثال: "محمد عبدالله سعد" = محمد بن عبدالله بن سعد
  static List<DirectoryPerson> searchByAncestralChain({
    required String query,
    required List<DirectoryPerson> allPeople,
  }) {
    // تقسيم الاستعلام لأسماء
    final names = query.trim().split(' ').where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return allPeople;

    // البحث عن الاسم الأول (قد يكون أي شخص)
    var candidates = allPeople.where((p) {
      final normalizedName = ArabicSearch.normalize(p.name);
      final normalizedQuery = ArabicSearch.normalize(names[0]);
      return normalizedName.contains(normalizedQuery);
    }).toList();

    // التحقق من تطابق سلسلة الأجداد
    if (names.length > 1) {
      candidates = candidates.where((person) {
        return _checkAncestralChain(person, names);
      }).toList();
    }

    return candidates;
  }

  /// التحقق من تطابق سلسلة الأجداد
  /// names[0] = اسم الشخص
  /// names[1] = fatherName
  /// names[2] = grandfatherName
  static bool _checkAncestralChain(
    DirectoryPerson person,
    List<String> names,
  ) {
    // التحقق من اسم الشخص (names[0])
    final normalizedPersonName = ArabicSearch.normalize(person.name);
    final normalizedQueryName = ArabicSearch.normalize(names[0]);
    if (!normalizedPersonName.contains(normalizedQueryName)) {
      return false;
    }

    // التحقق من اسم الأب (names[1])
    if (names.length > 1) {
      if (person.fatherName == null || person.fatherName!.isEmpty) {
        return false;
      }
      final normalizedFatherName = ArabicSearch.normalize(person.fatherName!);
      final normalizedQueryFather = ArabicSearch.normalize(names[1]);
      if (!normalizedFatherName.contains(normalizedQueryFather)) {
        return false;
      }
    }

    // التحقق من اسم الجد (names[2])
    if (names.length > 2) {
      if (person.grandfatherName == null || person.grandfatherName!.isEmpty) {
        return false;
      }
      final normalizedGrandfatherName = ArabicSearch.normalize(person.grandfatherName!);
      final normalizedQueryGrandfather = ArabicSearch.normalize(names[2]);
      if (!normalizedGrandfatherName.contains(normalizedQueryGrandfather)) {
        return false;
      }
    }

    return true;
  }

  /// بناء سلسلة الأجداد كنص
  /// مثال: "محمد بن عبدالله بن سعد"
  static String buildAncestralPath({
    required DirectoryPerson person,
    required List<DirectoryPerson> allPeople,
    int levels = 3,
  }) {
    final names = [person.name];
    final peopleMap = <String, DirectoryPerson>{};
    
    for (var p in allPeople) {
      peopleMap[p.id] = p;
    }
    
    var current = person;
    
    for (var i = 0; i < levels; i++) {
      if (current.fatherId == null) break;
      
      final father = peopleMap[current.fatherId];
      if (father == null) break;
      
      names.add(father.name);
      current = father;
    }
    
    return names.join(' بن ');
  }
}
