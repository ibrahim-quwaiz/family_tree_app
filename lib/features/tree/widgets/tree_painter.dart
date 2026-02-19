import 'package:flutter/material.dart';
import '../models/person.dart';
import '../../../core/theme/app_theme.dart';

class TreePainter extends CustomPainter {
  final Map<String, Offset> positions;
  final List<Person> people;

  TreePainter({
    required this.positions,
    required this.people,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty || people.isEmpty) {
      return;
    }

    // إنشاء خريطة للأشخاص حسب ID
    final personMap = <String, Person>{};
    for (var person in people) {
      personMap[person.id] = person;
    }

    // رسم خطوط الوصل بين الآباء والأبناء
    for (var person in people) {
      final personPosition = positions[person.id];
      if (personPosition == null) continue;

      // إذا كان للشخص أب، ارسم خط من الأب إليه
      if (person.fatherId != null && positions.containsKey(person.fatherId)) {
        final fatherPosition = positions[person.fatherId]!;
        
        // نقطة البداية: منتصف أسفل بطاقة الأب
        final startX = fatherPosition.dx + 80; // منتصف البطاقة (160/2)
        final startY = fatherPosition.dy + 180; // أسفل البطاقة
        
        // نقطة النهاية: منتصف أعلى بطاقة الابن
        final endX = personPosition.dx + 80;
        final endY = personPosition.dy;
        
        // رسم خط منحني (bezier curve)
        final path = Path();
        path.moveTo(startX, startY);
        
        // نقطة تحكم للانحناء
        final controlPoint1 = Offset(startX, startY + (endY - startY) / 2);
        final controlPoint2 = Offset(endX, startY + (endY - startY) / 2);
        
        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          endX,
          endY,
        );
        
        // لون الخط حسب الجنس
        final lineColor = person.gender == 'male'
            ? AppColors.primaryGreen.withOpacity(0.4)
            : person.gender == 'female'
                ? Colors.pink.withOpacity(0.4)
                : AppColors.textSecondary.withOpacity(0.3);
        
        final paint = Paint()
          ..color = lineColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        
        canvas.drawPath(path, paint);
        
        // رسم نقطة صغيرة عند نقطة النهاية
        canvas.drawCircle(
          Offset(endX, endY),
          3,
          Paint()..color = lineColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.people.length != people.length;
  }
}
