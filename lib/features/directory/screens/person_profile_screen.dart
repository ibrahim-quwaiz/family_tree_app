import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/directory_person.dart';
import '../../../core/theme/app_theme.dart';

class PersonProfileScreen extends StatelessWidget {
  final DirectoryPerson person;
  final List<Map<String, dynamic>> wives;
  final List<DirectoryPerson> children;
  final DirectoryPerson? spouse;
  final Map<String, String?> contactInfo;
  final List<DirectoryPerson> allPeople;
  final Function(DirectoryPerson) onPersonTap;

  const PersonProfileScreen({
    Key? key,
    required this.person,
    required this.wives,
    required this.children,
    this.spouse,
    required this.contactInfo,
    required this.allPeople,
    required this.onPersonTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfoSection(),
            const SizedBox(height: 16),
            _buildFamilySection(),
            const SizedBox(height: 16),
            if (person.gender == 'male' && (wives.isNotEmpty || children.isNotEmpty))
              _buildMarriageSection(),
            if (person.gender == 'female' && children.isNotEmpty)
              _buildChildrenOnlySection(),
            const SizedBox(height: 16),
            _buildContactSection(),
            const SizedBox(height: 16),
            _buildSocialMediaSection(),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Header مع الصورة والاسم
  // ═══════════════════════════════════════════
  Widget _buildHeader() {
    return Column(
      children: [
        // الصورة مع VIP Badge
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: _getPersonColor(),
              backgroundImage: person.photoUrl != null ? NetworkImage(person.photoUrl!) : null,
              child: person.photoUrl == null
                  ? Text(
                      person.name.isNotEmpty ? person.name[0] : '؟',
                      style: const TextStyle(fontSize: 48, color: Colors.white),
                    )
                  : null,
            ),
            if (person.isVip)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // الاسم الكامل
        Text(
          _buildPersonFullName(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        // QF + الجيل
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (person.legacyUserId != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  person.legacyUserId!,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'الجيل ${person.generation}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // المعلومات الشخصية
  // ═══════════════════════════════════════════
  Widget _buildPersonalInfoSection() {
    final hasInfo = person.birthDate != null ||
        person.birthCity != null ||
        person.birthCountry != null ||
        person.residenceCity != null ||
        person.education != null ||
        person.job != null ||
        person.deathDate != null;
    if (!hasInfo) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'المعلومات الشخصية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // تاريخ الميلاد + العمر
            if (person.birthDate != null)
              _buildInfoRow(
                Icons.cake,
                'تاريخ الميلاد',
                '${_formatDate(person.birthDate!)} (${_calculateAge(person.birthDate!)} سنة)',
              ),
            // تاريخ الوفاة
            if (!person.isAlive && person.deathDate != null)
              _buildInfoRow(
                Icons.favorite,
                'تاريخ الوفاة',
                '${_formatDate(person.deathDate!)} رحمه الله',
              ),
            // مكان الميلاد
            if (person.birthCity != null || person.birthCountry != null)
              _buildInfoRow(
                Icons.location_city,
                'مكان الميلاد',
                '${person.birthCity ?? ''}${person.birthCity != null && person.birthCountry != null ? '، ' : ''}${person.birthCountry ?? ''}',
              ),
            // مكان الإقامة
            if (person.residenceCity != null)
              _buildInfoRow(
                Icons.home,
                'الإقامة',
                person.residenceCity!,
              ),
            // التعليم
            if (person.education != null)
              _buildInfoRow(
                Icons.school,
                'التعليم',
                person.education!,
              ),
            // العمل
            if (person.job != null)
              _buildInfoRow(
                Icons.work,
                'العمل',
                person.job!,
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // الأب والأم
  // ═══════════════════════════════════════════
  Widget _buildFamilySection() {
    final hasFather = person.fatherName != null;
    final hasMother = person.motherName != null;
    if (!hasFather && !hasMother) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'العائلة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // الأب
            if (hasFather)
              _buildFamilyMemberCard(
                name: person.fatherName!,
                relation: 'الأب',
                icon: Icons.person,
                color: AppColors.primaryGreen,
                onTap: () {
                  if (person.fatherId != null) {
                    try {
                      final father = allPeople.firstWhere(
                        (p) => p.id == person.fatherId,
                      );
                      onPersonTap(father);
                    } catch (e) {
                      // Person not found
                    }
                  }
                },
              ),
            if (hasFather && hasMother) const SizedBox(height: 12),
            // الأم
            if (person.motherName != null)
              _buildFamilyMemberCard(
                name: person.motherName!,
                relation: 'الأم',
                icon: Icons.person,
                color: const Color(0xFFE91E8C),
                onTap: () {
                  if (person.motherId != null) {
                    try {
                      final mother = allPeople.firstWhere(
                        (p) => p.id == person.motherId,
                      );
                      onPersonTap(mother);
                    } catch (e) {
                      // Person not found
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // الزوجات والأبناء (للرجال)
  // ═══════════════════════════════════════════
  Widget _buildMarriageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  wives.isNotEmpty ? 'الزوجات والأبناء' : 'الأبناء',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (wives.isNotEmpty)
              ...wives.map((wifeData) => _buildWifeCard(wifeData))
            else if (children.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final groups = _groupChildrenByExternalMother();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: groups.entries
                        .map((entry) => _buildExternalWifeWithChildren(entry.key, entry.value))
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWifeCard(Map<String, dynamic> wifeData) {
    final isInternal = wifeData['wife_id'] != null;
    String getWifeName() {
      if (isInternal) {
        final wife = wifeData['wife'];
        if (wife != null && wife is Map<String, dynamic>) {
          return wife['name'] as String? ?? '';
        }
        return '';
      } else {
        return wifeData['wife_external_name'] as String? ?? 'زوجة من خارج العائلة';
      }
    }

    final wifeName = getWifeName();
    final wifeId = isInternal ? wifeData['wife_id'] : null;

    // جلب الأبناء من هذه الزوجة
    final childrenFromWife = children.where((child) {
      if (isInternal) {
        return child.motherId == wifeId;
      } else {
        return child.motherId == null;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم الزوجة
        InkWell(
          onTap: isInternal
              ? () {
                  try {
                    final wife = allPeople.firstWhere(
                      (p) => p.id == wifeId,
                    );
                    onPersonTap(wife);
                  } catch (e) {
                    // Person not found
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E8C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE91E8C),
                  child: Text(
                    wifeName.isNotEmpty ? wifeName[0] : '؟',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        wifeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      Text(
                        isInternal ? 'من العائلة' : 'من خارج العائلة',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isInternal) const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
        // الأبناء
        if (childrenFromWife.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '👨‍👩‍👦 الأبناء (${childrenFromWife.length}):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...childrenFromWife.map((child) => _buildChildTile(child)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // دالة جديدة لتجميع الأبناء حسب mother_external_name
  // ═══════════════════════════════════════════
  Map<String, List<DirectoryPerson>> _groupChildrenByExternalMother() {
    final groups = <String, List<DirectoryPerson>>{};

    for (var child in children) {
      final motherName = child.motherExternalName ?? 'غير معروفة';
      
      if (!groups.containsKey(motherName)) {
        groups[motherName] = [];
      }
      groups[motherName]!.add(child);
    }

    return groups;
  }

  // ═══════════════════════════════════════════
  // Widget جديد لعرض الأم الخارجية مع أبنائها
  // ═══════════════════════════════════════════
  Widget _buildExternalWifeWithChildren(String motherName, List<DirectoryPerson> kids) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // بطاقة الأم
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E8C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE91E8C),
                child: Text(
                  motherName.isNotEmpty ? motherName[0] : '؟',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      motherName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    Text(
                      'من خارج العائلة',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // الأبناء
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            '👨‍👩‍👦 الأبناء (${kids.length}):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...kids.map((child) => _buildChildTile(child)),
        const SizedBox(height: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // الأبناء فقط (للنساء)
  // ═══════════════════════════════════════════
  Widget _buildChildrenOnlySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.child_care, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'الأبناء',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              '👨‍👩‍👦 الأبناء (${children.length}):',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...children.map((child) => _buildChildTile(child)),
          ],
        ),
      ),
    );
  }

  Widget _buildChildTile(DirectoryPerson child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: child.gender == 'female' ? const Color(0xFFE91E8C) : AppColors.primaryGreen,
          child: Icon(
            child.gender == 'female' ? Icons.girl : Icons.boy,
            size: 16,
            color: Colors.white,
          ),
        ),
        title: Text(
          child.name,
          style: const TextStyle(fontSize: 14),
          textDirection: TextDirection.rtl,
        ),
        subtitle: child.legacyUserId != null
            ? Text(
                child.legacyUserId!,
                style: const TextStyle(fontSize: 11),
              )
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => onPersonTap(child),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // التواصل (هاتف، إيميل)
  // ═══════════════════════════════════════════
  Widget _buildContactSection() {
    final hasContact = person.mobilePhone != null || person.email != null;
    if (!hasContact) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_phone, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'التواصل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                if (person.mobilePhone != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(person.mobilePhone!),
                      icon: const Icon(Icons.phone),
                      label: const Text('اتصال'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(person.mobilePhone!),
                      icon: const Icon(Icons.chat),
                      label: const Text('واتساب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (person.email != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _sendEmail(person.email!),
                  icon: const Icon(Icons.email),
                  label: const Text('إيميل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // وسائل التواصل الاجتماعي
  // ═══════════════════════════════════════════
  Widget _buildSocialMediaSection() {
    final instagram = contactInfo['instagram'];
    final twitter = contactInfo['twitter'];
    final snapchat = contactInfo['snapchat'];
    final facebook = contactInfo['facebook'];
    final hasSocial = instagram != null || twitter != null || snapchat != null || facebook != null;
    if (!hasSocial) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.public, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'وسائل التواصل الاجتماعي',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (instagram != null)
                  _buildSocialButton(
                    'Instagram',
                    Icons.camera_alt,
                    const Color(0xFFE1306C),
                    () => _openUrl('https://instagram.com/$instagram'),
                  ),
                if (twitter != null)
                  _buildSocialButton(
                    'Twitter',
                    Icons.chat_bubble,
                    const Color(0xFF1DA1F2),
                    () => _openUrl('https://twitter.com/$twitter'),
                  ),
                if (snapchat != null)
                  _buildSocialButton(
                    'Snapchat',
                    Icons.camera,
                    const Color(0xFFFFFC00),
                    () => _openUrl('https://snapchat.com/add/$snapchat'),
                  ),
                if (facebook != null)
                  _buildSocialButton(
                    'Facebook',
                    Icons.facebook,
                    const Color(0xFF1877F2),
                    () => _openUrl('https://facebook.com/$facebook'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // أزرار الإجراءات
  // ═══════════════════════════════════════════
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: فتح الشجرة
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ميزة الشجرة قريباً')),
              );
            },
            icon: const Icon(Icons.account_tree),
            label: const Text('عرض في شجرة العائلة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // Helper Widgets
  // ═══════════════════════════════════════════
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMemberCard({
    required String name,
    required String relation,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    relation,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Helper Functions
  // ═══════════════════════════════════════════
  String _buildPersonFullName() {
    final connector = person.gender == 'female' ? 'بنت' : 'بن';
    final suffix = person.isAlive ? '' : ' رحمه الله';
    final parts = [person.name];
    if (person.fatherName != null) {
      parts.add(connector);
      parts.add(person.fatherName!);
    }
    if (person.grandfatherName != null) {
      parts.add('بن');
      parts.add(person.grandfatherName!);
    }
    return parts.join(' ') + suffix;
  }

  Color _getPersonColor() {
    if (!person.isAlive) return Colors.grey;
    if (person.gender == 'female') return const Color(0xFFE91E8C);
    return AppColors.primaryGreen;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _openWhatsApp(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$cleaned';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _sendEmail(String email) async {
    final url = 'mailto:$email';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _openUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
