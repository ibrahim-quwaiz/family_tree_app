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
      print('📡 جلب بيانات الدليل من Supabase...');

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
        setState(() {
          _allPeople = [];
          _filteredPeople = [];
          _isLoading = false;
        });
        return;
      }

      final Map<String, Map<String, dynamic>> peopleMap = {};
      for (var p in response) {
        final personJson = p as Map<String, dynamic>;
        peopleMap[personJson['id'] as String] = personJson;
      }

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
            } catch (e, stackTrace) {
              print('❌ خطأ في تحويل JSON: $e');
              return null;
            }
          })
          .whereType<DirectoryPerson>()
          .toList();

      print('✅ تم بناء ${people.length} شخص');

      setState(() {
        _allPeople = people;
        _filteredPeople = people;
        _isLoading = false;
      });
      
      _performSearch();
    } catch (e, stackTrace) {
      print('❌ خطأ في جلب البيانات: $e');
      setState(() {
        _allPeople = [];
        _filteredPeople = [];
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getWives(String personId) async {
    try {
      // تجنب الاعتماد على اسم FK في PostgREST (قد يسبب 400 إذا اختلف الاسم)
      final response = await SupabaseConfig.client
          .from('marriages')
          .select('id, husband_id, wife_id, wife_external_name, marriage_order, marriage_date, is_current')
          .eq('husband_id', personId)
          .order('marriage_order');

      final wives = <Map<String, dynamic>>[];
      for (final m in response) {
        final marriage = Map<String, dynamic>.from(m);
        final wifeId = marriage['wife_id'] as String?;
        if (wifeId != null) {
          final wife = await SupabaseConfig.client
              .from('people')
              .select('id, name, legacy_user_id')
              .eq('id', wifeId)
              .maybeSingle();
          marriage['wife'] = wife;
        }
        wives.add(marriage);
      }

      return wives;
    } catch (e) {
      print('❌ خطأ في جلب الزوجات: $e');
      return [];
    }
  }

  List<DirectoryPerson> _getChildren(String personId) {
    final person = _allPeople.firstWhere(
      (p) => p.id == personId,
      orElse: () => _allPeople.first,
    );
    if (person.gender == 'female') {
      return _allPeople.where((p) => p.motherId == personId).toList();
    }
    return _allPeople.where((p) => p.fatherId == personId).toList();
  }

  DirectoryPerson? _getSpouse(String? spouseId) {
    if (spouseId == null) return null;
    try {
      return _allPeople.firstWhere((p) => p.id == spouseId);
    } catch (e) {
      return null;
    }
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

  Future<List<Map<String, dynamic>>> _getGirlsChildren(String personId) async {
    try {
      final response = await SupabaseConfig.client
          .from('girls_children')
          .select()
          .eq('mother_id', personId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('خطأ في جلب أبناء البنات: $e');
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
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('بحث متقدم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(controller: _nameController, decoration: InputDecoration(labelText: 'الاسم', hintText: 'محمد', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(controller: _fatherController, decoration: InputDecoration(labelText: 'الأب', hintText: 'عبدالله', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(controller: _grandfatherController, decoration: InputDecoration(labelText: 'الجد', hintText: 'سعد', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(controller: _greatGrandfatherController, decoration: InputDecoration(labelText: 'أب الجد', hintText: 'إبراهيم', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                TextField(controller: _legacyIdController, decoration: InputDecoration(labelText: 'الرقم (QF)', hintText: 'QF07023', prefixIcon: const Icon(Icons.tag), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textDirection: TextDirection.ltr),
                const SizedBox(height: 16),
                Text('${_filteredPeople.length} نتيجة', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        Expanded(
          child: _filteredPeople.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_off, size: 64, color: AppColors.textSecondary), const SizedBox(height: 16), const Text('لا توجد نتائج', style: TextStyle(fontSize: 18, color: AppColors.textPrimary))]))
              : ListView.builder(itemCount: _filteredPeople.length, itemBuilder: (context, index) => _buildPersonCard(_filteredPeople[index])),
        ),
      ],
    );
  }

  Widget _buildPersonCard(DirectoryPerson person) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _getPersonColor(person), child: Text(person.name.isNotEmpty ? person.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(_buildPersonFullName(person), style: const TextStyle(fontWeight: FontWeight.bold), textDirection: TextDirection.rtl),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('الجيل ${person.generation}', style: const TextStyle(fontSize: 12), textDirection: TextDirection.rtl),
          if (person.residenceCity != null) Text(person.residenceCity!, style: const TextStyle(fontSize: 12)),
          if (person.legacyUserId != null) Text(person.legacyUserId!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        trailing: person.mobilePhone != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.phone, color: AppColors.primaryGreen), onPressed: () => _callPhone(person.mobilePhone)),
                IconButton(icon: const Icon(Icons.chat, color: Colors.green), onPressed: () => _openWhatsApp(person.mobilePhone)),
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
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Column(children: [
              const Text('دليل العائلة'),
              if (!_isLoading) Text('${_allPeople.length} شخص', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
            ]),
            actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPeople, tooltip: 'تحديث البيانات')],
            bottom: TabBar(
              tabs: const [Tab(icon: Icon(Icons.search), text: 'بحث'), Tab(icon: Icon(Icons.account_tree), text: 'تصفح')],
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.gold,
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : TabBarView(children: [_buildAdvancedSearchTab(), AncestralBrowser(allPeople: _allPeople, onPersonSelected: _showPersonDetails)]),
        ),
      ),
    );
  }
}