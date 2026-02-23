import 'package:flutter/material.dart';
import '../models/person.dart';
import '../../../core/theme/app_theme.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const PersonCard({
    super.key,
    required this.person,
    this.isCurrentUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(),
            width: isCurrentUser ? 4 : (person.isAlive ? 3 : 2),
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrentUser ? AppColors.gold.withOpacity(0.3) : Colors.black.withOpacity(0.2),
              blurRadius: isCurrentUser ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            Text(person.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center, maxLines: 2),
            const SizedBox(height: 4),
            Text('الجيل ${person.generation}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(person.isAlive ? '🟢' : '⚪', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(person.isAlive ? 'حي' : 'متوفى', style: TextStyle(fontSize: 12, color: person.isAlive ? AppColors.successGreen : AppColors.neutralGray)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👥', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text('${person.childrenCount}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (person.photoUrl != null) {
      return CircleAvatar(radius: 30, backgroundImage: NetworkImage(person.photoUrl!));
    }
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.primaryGreen,
      child: Text(person.name[0], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Color _getBorderColor() {
    if (isCurrentUser) return AppColors.gold;
    return person.isAlive ? AppColors.successGreen : AppColors.neutralGray;
  }
}