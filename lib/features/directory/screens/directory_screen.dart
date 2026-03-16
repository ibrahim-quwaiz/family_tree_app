import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/directory_person.dart';
import '../utils/arabic_search.dart';
import '../widgets/ancestral_browser.dart';
import 'person_profile_screen.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<DirectoryPerson> _allPeople = [];
  List<DirectoryPerson> _filteredPeople = [];
  bool _isLoading = true;
  bool _isSearchExpanded = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _grandfatherController = TextEditingController();
  final TextEditingController _greatGrandfatherController = TextEditingController();
  final TextEditingController _legacyIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPeople();
    _nameController.addListener(_performSearch);
    _fatherController.addListener(_performSearch);
    _grandfatherController.addListener(_performSearch);
    _greatGrandfatherController.addListener(_performSearch);
    _legacyIdController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherController.dispose();
    _grandfatherController.dispose();
    _greatGrandfatherController.dispose();
    _legacyIdController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      var results = _allPeople;
      
      final nameQuery = _nameController.text.trim();
      if (nameQuery.isNotEmpty) {
        results = results.where((p) {
          final name = ArabicSearch.normalize(p.name);
          final query = ArabicSearch.normalize(nameQuery);
          return name.contains(query);
        }).toList();
      }
      
      final fatherQuery = _fatherController.text.trim();
      if (fatherQuery.isNotEmpty) {
        results = results.where((p) {
          final fatherName = ArabicSearch.normalize(p.fatherName ?? '');
          final query = ArabicSearch.normalize(fatherQuery);
          return fatherName.contains(query);
        }).toList();
      }
      
      final grandfatherQuery = _grandfatherController.text.trim();
      if (grandfatherQuery.isNotEmpty) {
        results = results.where((p) {
          final grandfatherName = ArabicSearch.normalize(p.grandfatherName ?? '');
          final query = ArabicSearch.normalize(grandfatherQuery);
          return grandfatherName.contains(query);
        }).toList();
      }
      
      final greatGrandfatherQuery = _greatGrandfatherController.text.trim();
      if (greatGrandfatherQuery.isNotEmpty) {
        results = results.where((p) {
          final greatGrandfatherName = ArabicSearch.normalize(p.greatGrandfatherName ?? '');
          final query = ArabicSearch.normalize(greatGrandfatherQuery);
          return greatGrandfatherName.contains(query);
        }).toList();
      }
      
      final legacyIdQuery = _legacyIdController.text.trim();
      if (legacyIdQuery.isNotEmpty) {
        results = results.where((p) {
          final legacyId = (p.legacyUserId ?? '').toLowerCase();
          final query = legacyIdQuery.toLowerCase();
          return legacyId.contains(query);
        }).toList();
      }
      
      _filteredPeople = results;
    });
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);

    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('''
            id,
            legacy_user_id,
            name,
            gender,
            is_alive,
            generation,
            father_id,
            mother_id,
            mother_external_name,
            birth_date,
            death_date,
            birth_city,
            birth_country,
            residence_city,
            education,
            job,
            is_vip,
            photo_url,
            contact_info(
              mobile_phone,
              email,
              instagram,
              twitter,
              snapchat,
              facebook,
              is_contact_public,
              show_mobile,
              show_email,
              show_instagram,
              show_twitter,
              show_snapchat,
              show_facebook
            )
          ''')
          .order('generation')
          .order('name')
          .limit(1000);

      if (response.isEmpty) {
        setState(() {
          _allPeople = [];
          _filteredPeople = [];
          _isLoading = false;
        });
        return;
      }

      final Map<String, Map<String, dynamic>> peopleMap = {};
      for (var p in response) {
        final personJson = Map<String, dynamic>.from(p as Map);
        peopleMap[personJson['id'] as String] = personJson;
      }

      final enrichedPeople = response.map((p) {
        final personJson = Map<String, dynamic>.from(p as Map);
        final fatherId = personJson['father_id'] as String?;
        final father = fatherId != null ? peopleMap[fatherId] : null;
        
        final grandfatherId = father?['father_id'] as String?;
        final grandfather = grandfatherId != null ? peopleMap[grandfatherId] : null;
        
        final greatGrandfatherId = grandfather?['father_id'] as String?;
        final greatGrandfather = greatGrandfatherId != null ? peopleMap[greatGrandfatherId] : null;
        
        final greatGreatGrandfatherId = greatGrandfather?['father_id'] as String?;
        final greatGreatGrandfather = greatGreatGrandfatherId != null ? peopleMap[greatGreatGrandfatherId] : null;
        
        final motherId = personJson['mother_id'] as String?;
        final mother = motherId != null ? peopleMap[motherId] : null;
        
        return {
          ...personJson,
          'father_name': father?['name'],
          'grandfather_name': grandfather?['name'],
          'mother_name': mother?['name'] ?? personJson['mother_external_name'],
          'great_grandfather_name': greatGrandfather?['name'],
          'great_great_grandfather_name': greatGreatGrandfather?['name'],
          'mother_external_name': personJson['mother_external_name'],
          'birth_date': personJson['birth_date'],
          'death_date': personJson['death_date'],
          'birth_city': personJson['birth_city'],
          'birth_country': personJson['birth_country'],
          'education': personJson['education'],
          'is_vip': personJson['is_vip'],
        };
      }).toList();

      final people = enrichedPeople
          .map((json) {
            try {
              return DirectoryPerson.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<DirectoryPerson>()
          .toList();

      setState(() {
        _allPeople = people;
        _filteredPeople = people;
        _isLoading = false;
      });
      
      _performSearch();
    } catch (e) {
      setState(() {
        _allPeople = [];
        _filteredPeople = [];
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getWives(String personId) async {
    try {
      final marriages = await SupabaseConfig.client
          .from('marriages')
          .select('''
            husband_id,
            wife_id,
            wife_external_name,
            marriage_order,
            wife:people!marriages_wife_id_fkey(
              id,
              name,
              legacy_user_id
            )
          ''')
          .eq('husband_id', personId)
          .order('marriage_order');
      
      return List<Map<String, dynamic>>.from(marriages);
    } catch (e) {
      return [];
    }
  }

  List<DirectoryPerson> _getChildren(String personId) {
    final person = _allPeople.firstWhere(
      (p) => p.id == personId,
      orElse: () => _allPeople.first,
    );
    List<DirectoryPerson> children;
    if (person.gender == 'female') {
      children = _allPeople.where((p) => p.motherId == personId).toList();
    } else {
      children = _allPeople.where((p) => p.fatherId == personId).toList();
    }

    children.sort((a, b) {
      final aDate = a.birthDate;
      final bDate = b.birthDate;
      if (aDate != null && bDate != null) return aDate.compareTo(bDate);
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return (a.legacyUserId ?? '').compareTo(b.legacyUserId ?? '');
    });

    return children;
  }

  /// استنتاج أزواج البنت من أبنائها (من داخل العائلة)
  List<Map<String, dynamic>> _getHusbandsFromChildren(String motherId) {
    final children = _allPeople.where((p) => p.motherId == motherId).toList();
    if (children.isEmpty) return [];

    final Map<String, List<DirectoryPerson>> grouped = {};
    for (var child in children) {
      final fId = child.fatherId ?? 'unknown';
      if (!grouped.containsKey(fId)) {
        grouped[fId] = [];
      }
      grouped[fId]!.add(child);
    }

    final result = <Map<String, dynamic>>[];
    for (var entry in grouped.entries) {
      DirectoryPerson? father;
      try {
        father = _allPeople.firstWhere((p) => p.id == entry.key);
      } catch (e) {
        // father not found
      }
      result.add({
        'father_id': entry.key,
        'father': father,
        'father_name': father?.name ?? 'غير معروف',
        'is_internal': father != null,
        'children': entry.value,
      });
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _getGirlsChildren(String personId) async {
    try {
      final response = await SupabaseConfig.client
          .from('girls_children')
          .select()
          .eq('mother_id', personId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Color _getPersonColor(DirectoryPerson person) {
    if (!person.isAlive) return AppColors.neutralGray;
    if (person.gender == 'female') return const Color(0xFFE91E8C);
    return AppColors.primaryGreen;
  }

  String _buildPersonFullName(DirectoryPerson person) {
    final connector = person.gender == 'female' ? 'بنت' : 'بن';
    final suffix = person.isAlive ? '' : ' رحمه الله';
    final parts = [person.name];
    if (person.fatherName != null && person.fatherName!.isNotEmpty) {
      parts.add(connector);
      parts.add(person.fatherName!);
    }
    if (person.grandfatherName != null && person.grandfatherName!.isNotEmpty) {
      parts.add('بن');
      parts.add(person.grandfatherName!);
    }
    return parts.join(' ') + suffix;
  }

  Widget _buildAdvancedSearchTab() {
    final activeFilters = <String>[];
    if (_nameController.text.trim().isNotEmpty) activeFilters.add('الاسم: ${_nameController.text.trim()}');
    if (_fatherController.text.trim().isNotEmpty) activeFilters.add('الأب: ${_fatherController.text.trim()}');
    if (_grandfatherController.text.trim().isNotEmpty) activeFilters.add('الجد: ${_grandfatherController.text.trim()}');
    if (_greatGrandfatherController.text.trim().isNotEmpty) activeFilters.add('جد الأب: ${_greatGrandfatherController.text.trim()}');
    if (_legacyIdController.text.trim().isNotEmpty) activeFilters.add('رقم العضوية: ${_legacyIdController.text.trim()}');

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isSearchExpanded = !_isSearchExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: _isSearchExpanded ? AppColors.gold.withOpacity(0.08) : AppColors.bgCard,
                          border: Border.all(
                            color: _isSearchExpanded ? AppColors.gold : AppColors.borderLight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'بحث متقدم',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isSearchExpanded ? AppColors.gold : AppColors.textSecondary,
                              ),
                            ),
                            if (activeFilters.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${activeFilters.length}',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.bgDeep),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: _isSearchExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: _isSearchExpanded ? AppColors.gold : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      _buildSearchField(
                        controller: _nameController,
                        label: 'الاسم',
                        hint: 'اسم الشخص...',
                        isHighlighted: true,
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      _buildSearchField(controller: _fatherController, label: 'الأب', hint: 'اسم الأب...'),
                      const SizedBox(height: 8),
                      _buildSearchField(controller: _grandfatherController, label: 'الجد', hint: 'اسم الجد...'),
                      const SizedBox(height: 8),
                      _buildSearchField(controller: _greatGrandfatherController, label: 'جد الأب', hint: 'اسم جد الأب...'),
                      const SizedBox(height: 8),
                      _buildSearchField(
                        controller: _legacyIdController,
                        label: 'رقم العضوية',
                        hint: 'QF07023...',
                        isLtr: true,
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isSearchExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 350),
              ),
              if (activeFilters.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _nameController.clear();
                          _fatherController.clear();
                          _grandfatherController.clear();
                          _greatGrandfatherController.clear();
                          _legacyIdController.clear();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Text('مسح الكل', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: activeFilters
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.1),
                              border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (f.startsWith('الاسم')) {
                                      _nameController.clear();
                                    } else if (f.startsWith('الأب')) {
                                      _fatherController.clear();
                                    } else if (f.startsWith('الجد') && !f.startsWith('جد')) {
                                      _grandfatherController.clear();
                                    } else if (f.startsWith('جد الأب')) {
                                      _greatGrandfatherController.clear();
                                    } else if (f.startsWith('رقم')) {
                                      _legacyIdController.clear();
                                    }
                                  },
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withOpacity(0.25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.close, size: 9, color: AppColors.gold),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(f, style: TextStyle(fontSize: 10, color: AppColors.goldLight)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_filteredPeople.length} نتيجة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredPeople.isEmpty
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text('لا توجد نتائج', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredPeople.length,
                  itemBuilder: (context, index) => _buildPersonCard(_filteredPeople[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isHighlighted = false,
    bool isLtr = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? AppColors.goldLight : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
            style: TextStyle(fontSize: isHighlighted ? 13 : 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.bgCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isHighlighted ? AppColors.gold.withOpacity(0.25) : AppColors.borderLight,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.gold),
              ),
              suffixIcon: ValueListenableBuilder(
                valueListenable: controller,
                builder: (_, value, __) => value.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => controller.clear(),
                        child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonCard(DirectoryPerson person) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _getPersonColor(person), child: Text(person.name.isNotEmpty ? person.name[0] : '؟', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(_buildPersonFullName(person), style: TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('الجيل ${person.generation}', style: TextStyle(fontSize: 12), textDirection: TextDirection.rtl),
          if (person.residenceCity != null) Text(person.residenceCity!, style: TextStyle(fontSize: 12)),
          if (person.legacyUserId != null) Text(person.legacyUserId!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        trailing: person.mobilePhone != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: Icon(Icons.phone, color: AppColors.primaryGreen), onPressed: () => _callPhone(person.mobilePhone)),
                IconButton(icon: Icon(Icons.chat, color: Colors.green), onPressed: () => _openWhatsApp(person.mobilePhone)),
              ])
            : null,
        onTap: () => _showPersonDetails(person),
      ),
    );
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showPersonDetails(DirectoryPerson person) async {
    final children = _getChildren(person.id);

    List<Map<String, dynamic>> wives = [];
    if (person.gender == 'male') {
      wives = await _getWives(person.id);
    }

    final contactInfo = {'instagram': person.instagram, 'twitter': person.twitter, 'snapchat': person.snapchat, 'facebook': person.facebook};

    // للبنات: استنتاج الأزواج من الأبناء + جلب أبناء من خارج العائلة
    List<Map<String, dynamic>> husbandsFromChildren = [];
    List<Map<String, dynamic>> girlsChildren = [];
    if (person.gender == 'female') {
      husbandsFromChildren = _getHusbandsFromChildren(person.id);
      girlsChildren = await _getGirlsChildren(person.id);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonProfileScreen(
          person: person,
          wives: wives,
          children: children,
          contactInfo: contactInfo,
          husbandsFromChildren: husbandsFromChildren,
          girlsChildren: girlsChildren,
          allPeople: _allPeople,
          onPersonTap: (selectedPerson) {
            Navigator.pop(context);
            _showPersonDetails(selectedPerson);
          },
          privacySettings: {
            'show_mobile': person.showMobile ?? true,
            'show_email': person.showEmail ?? true,
            'show_instagram': person.showInstagram ?? true,
            'show_twitter': person.showTwitter ?? true,
            'show_snapchat': person.showSnapchat ?? true,
            'show_facebook': person.showFacebook ?? true,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_forward_rounded),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Column(children: [
              Text('دليل العائلة'),
              if (!_isLoading) Text('${_allPeople.length} شخص', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
            ]),
            actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadPeople, tooltip: 'تحديث البيانات')],
            bottom: TabBar(
              tabs: const [Tab(icon: Icon(Icons.search), text: 'بحث'), Tab(icon: Icon(Icons.account_tree), text: 'تصفح')],
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.gold,
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : TabBarView(children: [_buildAdvancedSearchTab(), AncestralBrowser(allPeople: _allPeople, onPersonSelected: _showPersonDetails)]),
        ),
      ),
    );
  }
}