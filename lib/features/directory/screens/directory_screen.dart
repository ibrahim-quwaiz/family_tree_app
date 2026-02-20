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

  // Controllers للحقول الخمسة:
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
      
      // فلتر بالاسم:
      final nameQuery = _nameController.text.trim();
      if (nameQuery.isNotEmpty) {
        results = results.where((p) {
          final name = ArabicSearch.normalize(p.name);
          final query = ArabicSearch.normalize(nameQuery);
          return name.contains(query);
        }).toList();
      }
      
      // فلتر بالأب:
      final fatherQuery = _fatherController.text.trim();
      if (fatherQuery.isNotEmpty) {
        results = results.where((p) {
          final fatherName = ArabicSearch.normalize(p.fatherName ?? '');
          final query = ArabicSearch.normalize(fatherQuery);
          return fatherName.contains(query);
        }).toList();
      }
      
      // فلتر بالجد:
      final grandfatherQuery = _grandfatherController.text.trim();
      if (grandfatherQuery.isNotEmpty) {
        results = results.where((p) {
          final grandfatherName = ArabicSearch.normalize(p.grandfatherName ?? '');
          final query = ArabicSearch.normalize(grandfatherQuery);
          return grandfatherName.contains(query);
        }).toList();
      }
      
      // فلتر بأب الجد:
      final greatGrandfatherQuery = _greatGrandfatherController.text.trim();
      if (greatGrandfatherQuery.isNotEmpty) {
        results = results.where((p) {
          final greatGrandfatherName = ArabicSearch.normalize(p.greatGrandfatherName ?? '');
          final query = ArabicSearch.normalize(greatGrandfatherQuery);
          return greatGrandfatherName.contains(query);
        }).toList();
      }
      
      // فلتر بالرقم:
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
      print('📡 جلب بيانات الدليل من Supabase...');

      // جلب البيانات من people
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
            spouse_id,
            spouse_external_name,
            mother_external_name,
            birth_date,
            death_date,
            birth_city,
            birth_country,
            residence_city,
            education,
            job,
            is_vip,
            contact_info(
              mobile_phone,
              email,
              photo_url,
              instagram,
              twitter,
              snapchat,
              facebook
            )
          ''')
          .order('generation')
          .order('name')
          .limit(1000);

      print('📊 تم استلام ${response.length} سجل من people');

      if (response.isEmpty) {
        print('⚠️ الاستجابة فارغة');
        setState(() {
          _allPeople = [];
          _filteredPeople = [];
          _isLoading = false;
        });
        return;
      }

      // خطوة 1: ابنِ Map من id → Map كامل
      final Map<String, Map<String, dynamic>> peopleMap = {};
      for (var p in response) {
        final personJson = p as Map<String, dynamic>;
        peopleMap[personJson['id'] as String] = personJson;
      }

      // خطوة 2: لكل شخص أضف father_name و grandfather_name و great_grandfather_name و great_great_grandfather_name
      final enrichedPeople = response.map((p) {
        final personJson = Map<String, dynamic>.from(p as Map<String, dynamic>);
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
        
        final enriched = {
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
        
        // Log للأشخاص الذين لديهم 4 أجيال (للاختبار)
        if (enriched['great_great_grandfather_name'] != null) {
          print('📋 شخص لديه 4 أجيال: ${enriched['name']} → ${enriched['father_name']} → ${enriched['grandfather_name']} → ${enriched['great_grandfather_name']} → ${enriched['great_great_grandfather_name']}');
        }
        
        return enriched;
      }).toList();

      // خطوة 3: حوّل enrichedPeople لـ DirectoryPerson
      final people = enrichedPeople
          .map((json) {
            try {
              return DirectoryPerson.fromJson(json);
            } catch (e, stackTrace) {
              print('❌ خطأ في تحويل JSON: $e');
              print('📋 Stack trace: $stackTrace');
              print('📄 JSON: $json');
              return null;
            }
          })
          .whereType<DirectoryPerson>()
          .toList();

      print('✅ تم بناء ${people.length} شخص');
      if (people.isNotEmpty) {
        print('👤 أول شخص: ${people.first.name}, fatherName: ${people.first.fatherName ?? "null"}');
      }

      setState(() {
        _allPeople = people;
        _filteredPeople = people;
        _isLoading = false;
      });
      
      // تطبيق البحث بعد تحميل البيانات
      _performSearch();
    } catch (e, stackTrace) {
      print('❌ خطأ في جلب البيانات: $e');
      print('📋 Stack trace: $stackTrace');
      setState(() {
        _allPeople = [];
        _filteredPeople = [];
        _isLoading = false;
      });
    }
  }

  // جلب الزوجات (للرجال) — نطلب wife_external_name صراحةً
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
      
      final result = List<Map<String, dynamic>>.from(marriages);
      
      return result;
    } catch (e, stackTrace) {
      print('❌ خطأ في جلب الزوجات: $e');
      print('📋 Stack trace: $stackTrace');
      return [];
    }
  }

  // جلب الأبناء
  List<DirectoryPerson> _getChildren(String personId) {
    return _allPeople.where((p) => p.fatherId == personId).toList();
  }

  // جلب أبناء من أم معينة
  List<DirectoryPerson> _getChildrenByMother(String fatherId, String? motherId) {
    return _allPeople.where((p) => 
      p.fatherId == fatherId && p.motherId == motherId
    ).toList();
  }

  // جلب معلومات الزوج (للنساء)
  DirectoryPerson? _getSpouse(String? spouseId) {
    if (spouseId == null) return null;
    try {
      return _allPeople.firstWhere((p) => p.id == spouseId);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String?>> _getContactInfo(String personId) async {
    try {
      final response = await SupabaseConfig.client
          .from('contact_info')
          .select('instagram, twitter, snapchat, facebook')
          .eq('person_id', personId)
          .maybeSingle();
      if (response != null) {
        return {
          'instagram': response['instagram'] as String?,
          'twitter': response['twitter'] as String?,
          'snapchat': response['snapchat'] as String?,
          'facebook': response['facebook'] as String?,
        };
      }
    } catch (e) {
      print('خطأ في جلب معلومات التواصل: $e');
    }
    return {};
  }

  Color _getPersonColor(DirectoryPerson person) {
    if (!person.isAlive) return Colors.grey;
    if (person.gender == 'female') return const Color(0xFFE91E8C);
    return AppColors.primaryGreen;
  }

  String _buildPersonFullName(DirectoryPerson person) {
    final connector = person.gender == 'female' ? 'بنت' : 'بن';
    final suffix = person.isAlive ? '' : ' رحمه الله';
    
    final parts = [person.name];
    if (person.fatherName != null && person.fatherName!.isNotEmpty) {
      parts.add(person.fatherName!);
    }
    if (person.grandfatherName != null && person.grandfatherName!.isNotEmpty) {
      parts.add(person.grandfatherName!);
    }
    
    return parts.join(' $connector ') + suffix;
  }

  Widget _buildAdvancedSearchTab() {
    return Column(
      children: [
        // قسم البحث
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'بحث متقدم',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // حقل الاسم
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    hintText: 'محمد',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                
                // حقل الأب
                TextField(
                  controller: _fatherController,
                  decoration: InputDecoration(
                    labelText: 'الأب',
                    hintText: 'عبدالله',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                
                // حقل الجد
                TextField(
                  controller: _grandfatherController,
                  decoration: InputDecoration(
                    labelText: 'الجد',
                    hintText: 'سعد',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                
                // حقل أب الجد
                TextField(
                  controller: _greatGrandfatherController,
                  decoration: InputDecoration(
                    labelText: 'أب الجد',
                    hintText: 'إبراهيم',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                
                // حقل الرقم
                TextField(
                  controller: _legacyIdController,
                  decoration: InputDecoration(
                    labelText: 'الرقم (QF)',
                    hintText: 'QF07023',
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 16),
                
                // عدد النتائج
                Text(
                  '${_filteredPeople.length} نتيجة',
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        
        // قائمة النتائج
        Expanded(
          child: _filteredPeople.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('لا توجد نتائج', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredPeople.length,
                  itemBuilder: (context, index) {
                    return _buildPersonCard(_filteredPeople[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPersonCard(DirectoryPerson person) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPersonColor(person),
          child: Text(
            person.name.isNotEmpty ? person.name[0] : '؟',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          _buildPersonFullName(person),
          style: const TextStyle(fontWeight: FontWeight.bold),
          textDirection: TextDirection.rtl,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'الجيل ${person.generation}',
              style: const TextStyle(fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
            if (person.residenceCity != null)
              Text(
                person.residenceCity!,
                style: const TextStyle(fontSize: 12),
              ),
            if (person.legacyUserId != null)
              Text(
                person.legacyUserId!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: person.mobilePhone != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppColors.primaryGreen),
                    onPressed: () => _callPhone(person.mobilePhone),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.green),
                    onPressed: () => _openWhatsApp(person.mobilePhone),
                  ),
                ],
              )
            : null,
        onTap: () => _showPersonDetails(person),
      ),
    );
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    // إزالة أي رموز غير رقمية
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInstagram(String? username) async {
    if (username == null || username.isEmpty) return;
    final uri = Uri.parse('https://instagram.com/$username');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showPersonDetails(DirectoryPerson person) async {
    final children = _getChildren(person.id);

    List<Map<String, dynamic>> wives = [];
    if (person.gender == 'male') {
      wives = await _getWives(person.id);
      
      // إذا لم نجد زوجات في marriages ووجدنا spouse_external_name في الشخص نفسه، أضفه كزوجة خارجية
      if (wives.isEmpty && person.spouseExternalName != null && person.spouseExternalName!.isNotEmpty) {
        wives = [
          {
            'husband_id': person.id,
            'wife_id': null,
            'wife_external_name': person.spouseExternalName,
            'marriage_order': 1,
            'wife': null,
          }
        ];
      }
    }
    final spouse = _getSpouse(person.spouseId);
    // استخراج contactInfo من person مباشرة (تم جلبه في _loadPeople)
    final contactInfo = {
      'instagram': person.instagram,
      'twitter': person.twitter,
      'snapchat': person.snapchat,
      'facebook': person.facebook,
    };
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonProfileScreen(
          person: person,
          wives: wives,
          children: children,
          spouse: spouse,
          contactInfo: contactInfo,
          allPeople: _allPeople,
          onPersonTap: (selectedPerson) {
            Navigator.pop(context);
            _showPersonDetails(selectedPerson);
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
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
            title: Column(
              children: [
                const Text('دليل العائلة'),
                if (!_isLoading)
                  Text(
                    '${_allPeople.length} شخص',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPeople,
                tooltip: 'تحديث البيانات',
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.search),
                  text: 'بحث',
                ),
                Tab(
                  icon: Icon(Icons.account_tree),
                  text: 'تصفح',
                ),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
              : TabBarView(
                  children: [
                    // Tab 1: البحث المتقدم
                    _buildAdvancedSearchTab(),
                    // Tab 2: التصفح التسلسلي
                    AncestralBrowser(
                      allPeople: _allPeople,
                      onPersonSelected: _showPersonDetails,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

}

class DirectoryCard extends StatelessWidget {
  final DirectoryPerson person;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final Color Function(DirectoryPerson) getColor;

  const DirectoryCard({
    super.key,
    required this.person,
    this.searchQuery = '',
    required this.onTap,
    this.onCall,
    this.onWhatsApp,
    required this.getColor,
  });

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    final normalizedText = ArabicSearch.normalize(text);
    final normalizedQuery = ArabicSearch.normalize(query);
    final index = normalizedText.indexOf(normalizedQuery);

    if (index == -1) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    // البحث عن النص المطابق في النص الأصلي
    // نسخة مبسطة: نبحث عن أول تطابق ممكن
    int originalIndex = 0;
    int normalizedIndex = 0;
    
    // البحث عن الموضع في النص الأصلي
    for (int i = 0; i < text.length && normalizedIndex < index; i++) {
      final char = text[i];
      final normalizedChar = ArabicSearch.normalize(char);
      if (normalizedChar.isNotEmpty) {
        normalizedIndex++;
      }
      if (normalizedIndex == index) {
        originalIndex = i;
        break;
      }
    }

    // البحث عن نهاية المطابقة
    int matchLength = query.length;
    int normalizedMatchLength = 0;
    int originalMatchLength = 0;
    
    for (int i = originalIndex; i < text.length && normalizedMatchLength < matchLength; i++) {
      final char = text[i];
      final normalizedChar = ArabicSearch.normalize(char);
      if (normalizedChar.isNotEmpty) {
        normalizedMatchLength++;
      }
      originalMatchLength++;
    }

    final beforeText = text.substring(0, originalIndex);
    final matchText = text.substring(originalIndex, originalIndex + originalMatchLength);
    final afterText = text.substring(originalIndex + originalMatchLength);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        children: [
          TextSpan(text: beforeText),
          TextSpan(
            text: matchText,
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B), // أصفر فاتح
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: afterText),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(person);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
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
        title: _highlightText(person.name, searchQuery),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(
              'الجيل ${person.generation}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (person.residenceCity != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      person.residenceCity!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
            if (person.job != null) ...[
              const SizedBox(height: 2),
              Text(
                person.job!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ],
        ),
        isThreeLine: false,
        trailing: person.hasPhone
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppColors.primaryGreen),
                    onPressed: onCall,
                    tooltip: 'اتصال',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                    onPressed: onWhatsApp,
                    tooltip: 'واتساب',
                  ),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

class PersonDetailSheet extends StatelessWidget {
  final DirectoryPerson person;
  final List<Map<String, dynamic>> wives;
  final List<DirectoryPerson> children;
  final DirectoryPerson? spouse;
  final List<DirectoryPerson> allPeople;
  final Function(DirectoryPerson) onPersonTap;

  const PersonDetailSheet({
    super.key,
    required this.person,
    required this.wives,
    required this.children,
    this.spouse,
    required this.allPeople,
    required this.onPersonTap,
  });

  Color _getPersonColor() {
    if (!person.isAlive) return Colors.grey;
    if (person.gender == 'female') return const Color(0xFFE91E8C);
    return AppColors.primaryGreen;
  }

  String _buildPersonFullName() {
    final firstConnector = person.gender == 'female' ? 'بنت' : 'بن';
    final suffix = person.isAlive ? '' : ' رحمه الله';
    
    final parts = [person.name];
    if (person.fatherName != null && person.fatherName!.isNotEmpty) {
      parts.add(firstConnector);
      parts.add(person.fatherName!);
    }
    if (person.grandfatherName != null && person.grandfatherName!.isNotEmpty) {
      parts.add('بن');
      parts.add(person.grandfatherName!);
    }
    
    return parts.join(' ') + suffix;
  }

  Future<void> _callPhone(BuildContext context) async {
    if (person.mobilePhone == null || person.mobilePhone!.isEmpty) return;
    final uri = Uri.parse('tel:${person.mobilePhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    if (person.mobilePhone == null || person.mobilePhone!.isEmpty) return;
    final cleanPhone = person.mobilePhone!.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    if (person.email == null || person.email!.isEmpty) return;
    final uri = Uri.parse('mailto:${person.email}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInstagram(BuildContext context) async {
    if (person.instagram == null || person.instagram!.isEmpty) return;
    final username = person.instagram!.replaceAll('@', '');
    final uri = Uri.parse('https://instagram.com/$username');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 16),
                
                // معلومات أساسية
                _buildBasicInfo(),
                
                // الأب
                if (person.fatherName != null)
                  _buildFatherSection(),
                
                // الأم
                if (person.motherName != null)
                  _buildMotherSection(),
                
                // للرجل: الزوجات + أبناء كل زوجة أو الأبناء فقط
                if (person.gender == 'male' && children.isNotEmpty && wives.isNotEmpty)
                  _buildWivesSection(),

                if (person.gender == 'male' && children.isNotEmpty && wives.isEmpty)
                  _buildChildrenWithExternalWifeSection(),
                
                // للمرأة: الزوج + الأبناء
                if (person.gender == 'female')
                  _buildSpouseSection(),
                
                // أزرار التواصل
                _buildContactButtons(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: _getPersonColor(),
            backgroundImage: person.photoUrl != null
                ? NetworkImage(person.photoUrl!)
                : null,
            child: person.photoUrl == null
                ? Text(
                    person.name.isNotEmpty ? person.name[0] : '؟',
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _buildPersonFullName(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          if (person.legacyUserId != null)
            Text(
              person.legacyUserId!,
              style: const TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      children: [
        _buildInfoRow(Icons.people, 'الجيل', '${person.generation}'),
        if (person.residenceCity != null)
          _buildInfoRow(Icons.location_city, 'الإقامة', person.residenceCity!),
        if (person.job != null)
          _buildInfoRow(Icons.work, 'العمل', person.job!),
      ],
    );
  }

  Widget _buildFatherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '👨 الأب',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: AppColors.primaryGreen),
            title: Text(
              person.fatherName!,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              final father = allPeople.firstWhere(
                (p) => p.id == person.fatherId,
                orElse: () => person,
              );
              if (father.id != person.id) {
                onPersonTap(father);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMotherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '👩 الأم',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: Color(0xFFE91E8C)),
            title: Text(
              person.motherName!,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              final mother = allPeople.firstWhere(
                (p) => p.id == person.motherId,
                orElse: () => person,
              );
              if (mother.id != person.id) {
                onPersonTap(mother);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChildrenWithExternalWifeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '👨‍👩‍👦 الأبناء (${children.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...children.map((child) => _buildChildTile(child)),
      ],
    );
  }

  Widget _buildWivesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '💍 الزوجات (${wives.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ...wives.map((wifeData) => _buildWifeCard(wifeData)),
      ],
    );
  }

  Widget _buildWifeCard(Map<String, dynamic> wifeData) {
    final isInternal = wifeData['wife_id'] != null;
    final wifeName = isInternal 
        ? ((wifeData['wife'] as Map<String, dynamic>?)?['name'] as String?) ?? ''
        : (wifeData['wife_external_name'] as String?) ?? '';
    final wifeId = isInternal ? wifeData['wife_id'] : null;
    
    // جلب الأبناء من هذه الزوجة
    final childrenFromWife = children.where((child) {
      if (isInternal && wifeId != null) {
        return child.motherId == wifeId;
      } else {
        // للزوجات الخارجيات، نفترض أن الأبناء بدون mother_id من العائلة
        return child.motherId == null;
      }
    }).toList();
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم الزوجة
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE91E8C),
                child: Text(
                  wifeName.isNotEmpty ? wifeName[0] : '؟',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                wifeName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              subtitle: Text(
                isInternal ? 'من العائلة' : 'من خارج العائلة',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: isInternal 
                  ? const Icon(Icons.arrow_forward_ios, size: 16)
                  : null,
              onTap: isInternal && wifeId != null ? () {
                final wife = allPeople.firstWhere(
                  (p) => p.id == wifeId,
                  orElse: () => person,
                );
                if (wife.id != person.id) {
                  onPersonTap(wife);
                }
              } : null,
            ),
            
            // الأبناء
            if (childrenFromWife.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 4),
                child: Text(
                  '👨‍👩‍👦 الأبناء (${childrenFromWife.length}):',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              ...childrenFromWife.map((child) => _buildChildTile(child)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpouseSection() {
    if (person.spouseId != null && spouse != null) {
      // الزوج من العائلة
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '💍 الزوج',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  spouse!.name.isNotEmpty ? spouse!.name[0] : '؟',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                spouse!.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              subtitle: const Text('من العائلة', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => onPersonTap(spouse!),
            ),
          ),
          
          // الأبناء
          if (children.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                '👨‍👩‍👦 الأبناء (${children.length}):',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...children.map((child) => _buildChildTile(child)),
          ],
        ],
      );
    } else if (person.spouseExternalName != null) {
      // الزوج من خارج العائلة
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '💍 الزوج',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                person.spouseExternalName!,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              subtitle: const Text('من خارج العائلة', style: TextStyle(fontSize: 12)),
            ),
          ),
          
          // الأبناء (أسماء فقط)
          if (children.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                '👨‍👩‍👦 الأبناء:',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...children.map((child) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                '• ${child.name}',
                style: const TextStyle(fontSize: 14),
                textDirection: TextDirection.rtl,
              ),
            )),
          ],
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildChildTile(DirectoryPerson child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: child.gender == 'female' 
              ? const Color(0xFFE91E8C) 
              : AppColors.primaryGreen,
          child: Text(
            child.name.isNotEmpty ? child.name[0] : '؟',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
        title: Text(
          child.name,
          style: const TextStyle(fontSize: 14),
          textDirection: TextDirection.rtl,
        ),
        subtitle: child.legacyUserId != null
            ? Text(child.legacyUserId!, style: const TextStyle(fontSize: 11))
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => onPersonTap(child),
      ),
    );
  }

  Widget _buildContactButtons(BuildContext context) {
    if (person.mobilePhone == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _callPhone(context),
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
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.chat),
                label: const Text('واتساب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
