import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/person.dart';

class TreeLayout {
  static const double cardWidth = 160.0;
  static const double cardHeight = 180.0;
  static const double hGap = 20.0; // المسافة الأفقية بين البطاقات
  static const double vGap = 80.0; // المسافة العمودية بين الأجيال
  static const double padding = 50.0; // Padding حول الشجرة

  /// حساب مواقع جميع الأشخاص في الشجرة
  Map<String, Offset> calculatePositions(List<Person> people) {
    if (people.isEmpty) {
      return {};
    }

    final positions = <String, Offset>{};
    
    // تجميع الأشخاص حسب الجيل
    final byGeneration = <int, List<Person>>{};
    for (var person in people) {
      byGeneration.putIfAbsent(person.generation, () => []).add(person);
    }

    // ترتيب الأجيال من الأصغر للأكبر
    final generations = byGeneration.keys.toList()..sort();

    // حساب المواقع لكل جيل
    double currentY = padding;
    
    for (var generation in generations) {
      final generationPeople = byGeneration[generation]!;
      
      // ترتيب الأشخاص في الجيل حسب الاسم
      generationPeople.sort((a, b) => a.name.compareTo(b.name));
      
      // حساب عدد الأعمدة المطلوبة (تقريبي)
      final itemsPerRow = math.max(1, math.sqrt(generationPeople.length).ceil());
      final totalWidth = (itemsPerRow * cardWidth) + ((itemsPerRow - 1) * hGap);
      double startX = padding + (totalWidth / 2) - ((generationPeople.length * (cardWidth + hGap) - hGap) / 2);
      
      // توزيع الأشخاص في صف أفقي
      double currentX = startX;
      for (var person in generationPeople) {
        positions[person.id] = Offset(currentX, currentY);
        currentX += cardWidth + hGap;
      }
      
      // الانتقال للجيل التالي
      currentY += cardHeight + vGap;
    }

    return positions;
  }

  /// حساب حجم الشجرة بناءً على المواقع
  Size getTreeSize(Map<String, Offset> positions) {
    if (positions.isEmpty) {
      return const Size(800, 600);
    }

    double maxX = 0;
    double maxY = 0;

    for (var position in positions.values) {
      maxX = math.max(maxX, position.dx + cardWidth);
      maxY = math.max(maxY, position.dy + cardHeight);
    }

    return Size(
      maxX + padding,
      maxY + padding,
    );
  }
}
