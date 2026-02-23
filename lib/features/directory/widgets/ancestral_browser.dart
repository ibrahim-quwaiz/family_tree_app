import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/directory_person.dart';
import '../../tree/widgets/person_card.dart';
import '../../../core/theme/app_theme.dart';

class AncestralBrowser extends StatefulWidget {
  final List<DirectoryPerson> allPeople;
  final Function(DirectoryPerson)? onPersonSelected;

  const AncestralBrowser({
    super.key,
    required this.allPeople,
    this.onPersonSelected,
  });

  @override
  State<AncestralBrowser> createState() => _AncestralBrowserState();
}

class _AncestralBrowserState extends State<AncestralBrowser> {
  final List<DirectoryPerson> _navigationPath = [];
  DirectoryPerson? _currentPerson;

  List<DirectoryPerson> get _currentChildren {
    if (_currentPerson == null) {
      // الجيل الأول (الأشخاص بدون أب)
      return widget.allPeople
          .where((p) => p.fatherId == null || p.fatherId!.isEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } else {
      // أبناء الشخص الحالي
      return widget.allPeople
          .where((p) => p.fatherId == _currentPerson!.id)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  bool _hasChildren(DirectoryPerson person) {
    return widget.allPeople.any((p) => p.fatherId == person.id);
  }

  Color _getPersonColor(DirectoryPerson person) {
    if (!person.isAlive) return AppColors.neutralGray;
    if (person.gender == 'female') return const Color(0xFFE91E8C);
    return AppColors.primaryGreen;
  }

  void _navigateTo(DirectoryPerson person) {
    setState(() {
      if (_currentPerson != null) {
        _navigationPath.add(_currentPerson!);
      }
      _currentPerson = person;
    });
  }

  void _navigateBackTo(DirectoryPerson person) {
    final index = _navigationPath.indexOf(person);
    if (index == -1) {
      _goToRoot();
      return;
    }

    setState(() {
      _navigationPath.removeRange(index + 1, _navigationPath.length);
      _currentPerson = index == _navigationPath.length - 1 ? null : _navigationPath[index + 1];
    });
  }

  void _goToRoot() {
    setState(() {
      _navigationPath.clear();
      _currentPerson = null;
    });
  }

  void _showPersonDetails(DirectoryPerson person) {
    if (widget.onPersonSelected != null) {
      widget.onPersonSelected!(person);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Breadcrumb: المسار الحالي
          _buildBreadcrumb(),

          const Divider(height: 1),

          // قائمة الأبناء
          Expanded(
            child: _currentChildren.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentPerson == null
                              ? 'لا يوجد أشخاص في الجيل الأول'
                              : '${_currentPerson!.name} لا يملك أبناء',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _currentChildren.length,
                    itemBuilder: (context, index) {
                      final person = _currentChildren[index];
                      final hasChildren = _hasChildren(person);
                      
                      return _PersonTile(
                        person: person,
                        hasChildren: hasChildren,
                        getColor: _getPersonColor,
                        onTap: () {
                          if (hasChildren) {
                            _navigateTo(person);
                          } else {
                            _showPersonDetails(person);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // زر الرجوع للبداية
            TextButton.icon(
              onPressed: _goToRoot,
              icon: const Icon(Icons.home, size: 18),
              label: const Text('الكل'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
            
            // المسار المختار
            ..._navigationPath.map((person) => Row(
                  children: [
                    const Icon(Icons.chevron_left, size: 16, color: AppColors.textSecondary),
                    TextButton(
                      onPressed: () => _navigateBackTo(person),
                      child: Text(person.name),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                )),
            
            // الشخص الحالي
            if (_currentPerson != null) ...[
              const Icon(Icons.chevron_left, size: 16, color: AppColors.textSecondary),
              Text(
                _currentPerson!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final DirectoryPerson person;
  final bool hasChildren;
  final Color Function(DirectoryPerson) getColor;
  final VoidCallback onTap;

  const _PersonTile({
    required this.person,
    required this.hasChildren,
    required this.getColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = getColor(person);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الحرف الأول أو الصورة
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              backgroundImage: person.photoUrl != null
                  ? NetworkImage(person.photoUrl!)
                  : null,
              child: person.photoUrl == null
                  ? Text(
                      person.firstLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            // الاسم
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                person.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // الجيل
            Text(
              'الجيل ${person.generation}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
            // أيقونة إذا عنده أبناء
            if (hasChildren) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: AppColors.primaryGreen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
