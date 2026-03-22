import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class PersonService {
  static final _db = SupabaseConfig.client;

  // ═══════════════════════════════════════════
  // توليد رقم QF
  // ═══════════════════════════════════════════
  static Future<String> generateQfId(int generation) async {
    try {
      final genPrefix = 'QF${generation.toString().padLeft(2, '0')}';
      final response = await _db
          .from('people')
          .select('legacy_user_id')
          .like('legacy_user_id', '$genPrefix%');

      if (response != null && (response as List).isNotEmpty) {
        final ids = (response as List)
            .map((e) => int.tryParse(
                    (e['legacy_user_id'] as String).substring(4)) ?? 0)
            .toList();
        ids.sort();
        final lastSeq = ids.last;
        final newSeq = lastSeq + 1;
        return '$genPrefix${newSeq.toString().padLeft(3, '0')}';
      }
      return '${genPrefix}001';
    } catch (e) {
      final ts = DateTime.now().millisecondsSinceEpoch % 1000;
      return 'QF${generation.toString().padLeft(2, '0')}${ts.toString().padLeft(3, '0')}';
    }
  }

  // ═══════════════════════════════════════════
  // رفع صورة
  // ═══════════════════════════════════════════
  static Future<String?> uploadPhoto(String personId, Uint8List bytes) async {
    try {
      final storagePath = 'profiles/profile_$personId.jpg';
      await _db.storage.from('photos').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = _db.storage.from('photos').getPublicUrl(storagePath);
      await _db.from('people').update({'photo_url': url}).eq('id', personId);
      return url;
    } catch (e) {
      throw Exception('فشل رفع الصورة: $e');
    }
  }

  // ═══════════════════════════════════════════
  // إضافة / تحديث بيانات التواصل
  // ═══════════════════════════════════════════
  static Future<void> upsertContact(String personId, Map<String, dynamic> data) async {
    await _db.from('contact_info').upsert(
      {'person_id': personId, ...data},
      onConflict: 'person_id',
    );
  }

  // ═══════════════════════════════════════════
  // إضافة شخص
  // ═══════════════════════════════════════════
  static Future<String> addPerson({
    required String name,
    required String gender,
    required int generation,
    String? fatherId,
    String? motherId,
    String? motherExternalName,
    DateTime? birthDate,
    String? birthCity,
    String? birthCountry,
    String? residenceCity,
    String? job,
    String? education,
    String? pinCode,
    Map<String, dynamic>? contactData,
    Uint8List? photoBytes,
  }) async {
    final qfId = await generateQfId(generation);

    final insertData = <String, dynamic>{
      'name': name,
      'gender': gender,
      'generation': generation,
      'legacy_user_id': qfId,
      'is_alive': true,
      'is_admin': false,
      'is_vip': false,
      if (fatherId != null) 'father_id': fatherId,
      if (motherId != null) 'mother_id': motherId,
      if (motherExternalName != null) 'mother_external_name': motherExternalName,
      if (birthDate != null) 'birth_date': birthDate.toIso8601String().split('T').first,
      if (birthCity != null && birthCity.isNotEmpty) 'birth_city': birthCity,
      if (birthCountry != null && birthCountry.isNotEmpty) 'birth_country': birthCountry,
      if (residenceCity != null && residenceCity.isNotEmpty) 'residence_city': residenceCity,
      if (job != null && job.isNotEmpty) 'job': job,
      if (education != null && education.isNotEmpty) 'education': education,
      if (pinCode != null && pinCode.isNotEmpty) 'pin_code': pinCode,
    };

    final result = await _db.from('people').insert(insertData).select('id').single();
    final newPersonId = result['id'] as String;

    if (contactData != null && contactData.isNotEmpty) {
      await upsertContact(newPersonId, contactData);
    }

    if (photoBytes != null) {
      final uploadedUrl = await uploadPhoto(newPersonId, photoBytes);
      if (uploadedUrl == null) {
        throw Exception('فشل رفع الصورة');
      }
    }

    return qfId;
  }

  // ═══════════════════════════════════════════
  // تعديل شخص
  // ═══════════════════════════════════════════
  static Future<void> updatePerson({
    required String personId,
    required Map<String, dynamic> personData,
    Map<String, dynamic>? contactData,
    Uint8List? photoBytes,
  }) async {
    await _db.from('people').update(personData).eq('id', personId);

    // مزامنة كلمة المرور في auth.users عند تغيير PIN
    if (personData.containsKey('pin_code') && personData['pin_code'] != null) {
      final pin = (personData['pin_code'] as String).trim();
      if (pin.isNotEmpty) {
        final person = await _db
            .from('people')
            .select('legacy_user_id')
            .eq('id', personId)
            .single();
        final qfId = person['legacy_user_id'] as String;
        final newPassword = '${qfId.toUpperCase()}_$pin';
        try {
          await _db.rpc('admin_update_user_password', params: {
            'target_person_id': personId,
            'new_password': newPassword,
          });
        } catch (e) {
          // people.pin_code محدّث بالفعل — نسجّل الخطأ بدون إيقاف العملية
          // عند أول تسجيل دخول، auth_service.login() سينشئ الحساب بالـ PIN الجديد
          debugPrint('⚠️ فشل مزامنة PIN مع auth.users: $e');
        }
      }
    }

    if (contactData != null) {
      await upsertContact(personId, contactData);
    }

    if (photoBytes != null) {
      final uploadedUrl = await uploadPhoto(personId, photoBytes);
      if (uploadedUrl == null) {
        throw Exception('فشل رفع الصورة');
      }
    }
  }

  // ═══════════════════════════════════════════
  // إضافة زوجة
  // ═══════════════════════════════════════════
  static Future<void> addMarriage({
    required String husbandId,
    String? wifeId,
    String? externalName,
  }) async {
    final existing = await _db
        .from('marriages')
        .select('id')
        .eq('husband_id', husbandId);
    final nextOrder = (existing as List).length + 1;

    final insertData = <String, dynamic>{
      'husband_id': husbandId,
      'marriage_order': nextOrder,
      'is_current': true,
      if (wifeId != null) 'wife_id': wifeId,
      if (externalName != null) 'wife_external_name': externalName,
    };

    await _db.from('marriages').insert(insertData);
  }

  // ═══════════════════════════════════════════
  // حذف زواج
  // ═══════════════════════════════════════════
  static Future<String?> deleteMarriage({
    required String marriageId,
    required String husbandId,
    String? wifeId,
    String? wifeExternalName,
  }) async {
    int childrenCount = 0;

    if (wifeId != null) {
      final children = await _db
          .from('people')
          .select('id')
          .eq('father_id', husbandId)
          .eq('mother_id', wifeId);
      childrenCount = (children as List).length;
    } else if (wifeExternalName != null) {
      final children = await _db
          .from('people')
          .select('id')
          .eq('father_id', husbandId)
          .eq('mother_external_name', wifeExternalName);
      childrenCount = (children as List).length;
    }

    if (childrenCount > 0) return 'مرتبط بـ $childrenCount ابن/بنت، يجب حذف الأبناء أولاً';

    await _db.from('marriages').delete().eq('id', marriageId);
    return null;
  }

  // ═══════════════════════════════════════════
  // تعديل زواج
  // ═══════════════════════════════════════════
  static Future<void> updateMarriage({
    required String marriageId,
    bool? isCurrent,
    String? marriageDate,
    String? divorceDate,
  }) async {
    final data = <String, dynamic>{};
    if (isCurrent != null) data['is_current'] = isCurrent;
    if (marriageDate != null) data['marriage_date'] = marriageDate;
    if (divorceDate != null) data['divorce_date'] = divorceDate;
    if (data.isNotEmpty) {
      await _db.from('marriages').update(data).eq('id', marriageId);
    }
  }

  // ═══════════════════════════════════════════
  // جلب زوجات الأب
  // ═══════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getFatherWives(String fatherId) async {
    final response = await _db
        .from('marriages')
        .select('id, wife_id, wife_external_name, marriage_order, is_current')
        .eq('husband_id', fatherId)
        .order('marriage_order');

    final wives = <Map<String, dynamic>>[];
    for (final m in response) {
      final marriage = Map<String, dynamic>.from(m);
      final wifeId = marriage['wife_id'] as String?;
      if (wifeId != null) {
        final wife = await SupabaseConfig.client
            .from('people')
            .select('name')
            .eq('id', wifeId)
            .maybeSingle();
        marriage['wife_name'] = wife?['name'] ?? 'غير معروفة';
        marriage['is_external'] = false;
      } else {
        marriage['wife_name'] = marriage['wife_external_name'] ?? 'غير معروفة';
        marriage['is_external'] = true;
      }
      wives.add(marriage);
    }
    return wives;
  }

  // ═══════════════════════════════════════════
  // حذف شخص (مع التحقق من الارتباطات)
  // ═══════════════════════════════════════════
  static Future<String?> deletePerson(String personId) async {
    final children = await _db
        .from('people')
        .select('id')
        .eq('father_id', personId);

    final marriages = await _db
        .from('marriages')
        .select('id')
        .or('husband_id.eq.$personId,wife_id.eq.$personId');

    final girlsChildren = await _db
        .from('girls_children')
        .select('id')
        .eq('mother_id', personId);

    if ((children as List).isNotEmpty) return 'لديه أبناء مسجلون';
    if ((marriages as List).isNotEmpty) return 'لديه زيجات مسجلة';
    if ((girlsChildren as List).isNotEmpty) return 'لديها أبناء في قسم البنات';

    await _db.from('people').delete().eq('id', personId);
    return null;
  }
}
