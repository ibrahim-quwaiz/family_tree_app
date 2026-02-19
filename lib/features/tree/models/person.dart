import '../../../core/config/supabase_config.dart';

class Person {
  final String id;
  final String? legacyUserId;
  final String name;
  final String? gender;
  final int generation;
  final bool isAlive;
  final int childrenCount;
  final String? photoUrl;
  final String? fatherId;
  final String? motherId;
  final String? mobilePhone;

  const Person({
    required this.id,
    this.legacyUserId,
    required this.name,
    this.gender,
    required this.generation,
    required this.isAlive,
    required this.childrenCount,
    this.photoUrl,
    this.fatherId,
    this.motherId,
    this.mobilePhone,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      legacyUserId: json['legacy_user_id'] as String?,
      name: json['name'] as String,
      gender: json['gender'] as String?,
      generation: json['generation'] as int,
      isAlive: json['is_alive'] as bool? ?? true,
      childrenCount: json['children_count'] as int? ?? 0,
      photoUrl: json['photo_url'] as String?,
      fatherId: json['father_id'] as String?,
      motherId: json['mother_id'] as String?,
      mobilePhone: json['mobile_phone'] as String?,
    );
  }

  // جلب من Supabase
  static Future<List<Person>> fetchFromSupabase() async {
    try {
      print('🔄 جلب البيانات من Supabase...');
      
      final response = await SupabaseConfig.client
          .from('people_with_children')
          .select()
          .order('generation')
          .order('name')
          .limit(1000);
      
      print('📊 تم استلام ${response.length} سجل');
      
      if (response.isEmpty) {
        print('⚠️ الاستجابة فارغة');
        return [];
      }
      
      final people = (response as List)
          .map((json) {
            try {
              return Person.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              print('❌ خطأ في تحويل JSON: $e');
              return null;
            }
          })
          .whereType<Person>()
          .toList();
      
      print('✅ تم تحميل ${people.length} شخص بنجاح');
      
      return people;
    } catch (e) {
      print('❌ خطأ في جلب البيانات: $e');
      return [];
    }
  }

  // بيانات تجريبية
  static List<Person> getSampleFamily() {
    return [
      const Person(
        id: 'p1',
        legacyUserId: 'QF00001',
        name: 'عبدالله القويز',
        generation: 0,
        isAlive: false,
        childrenCount: 870,
      ),
      const Person(
        id: 'p2',
        legacyUserId: 'QF01001',
        name: 'محمد',
        generation: 1,
        isAlive: true,
        childrenCount: 235,
        fatherId: 'p1',
      ),
      const Person(
        id: 'p3',
        legacyUserId: 'QF01002',
        name: 'أحمد',
        generation: 1,
        isAlive: true,
        childrenCount: 184,
        fatherId: 'p1',
      ),
      const Person(
        id: 'p4',
        legacyUserId: 'QF01003',
        name: 'سعد',
        generation: 1,
        isAlive: false,
        childrenCount: 221,
        fatherId: 'p1',
      ),
      const Person(
        id: 'p5',
        legacyUserId: 'QF02001',
        name: 'عبدالله',
        generation: 2,
        isAlive: true,
        childrenCount: 12,
        fatherId: 'p3',
      ),
      const Person(
        id: 'p6',
        legacyUserId: 'QF02002',
        name: 'إبراهيم',
        generation: 2,
        isAlive: true,
        childrenCount: 87,
        fatherId: 'p3',
      ),
      const Person(
        id: 'p7',
        legacyUserId: 'QF02003',
        name: 'فاطمة',
        generation: 2,
        isAlive: true,
        childrenCount: 45,
        fatherId: 'p6',
      ),
      const Person(
        id: 'p8',
        legacyUserId: 'QF02004',
        name: 'خالد',
        generation: 2,
        isAlive: true,
        childrenCount: 23,
        fatherId: 'p6',
        photoUrl: 'https://i.pravatar.cc/150?img=12',
        mobilePhone: '0512345678',
      ),
    ];
  }
}