class DirectoryPerson {
  final String id;
  final String? legacyUserId;
  final String name;
  final String? gender;
  final int generation;
  final bool isAlive;
  final String? residenceCity;
  final String? job;
  final String? fatherId;
  final String? fatherName;
  final String? motherId;
  final String? motherName;
  final String? motherExternalName;
  final String? spouseId;
  final String? spouseExternalName;
  final String? grandfatherName;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String? birthCity;
  final String? birthCountry;
  final String? education;
  final bool isVip;
  final String? greatGrandfatherName;
  final String? greatGreatGrandfatherName;
  final String? mobilePhone;
  final String? email;
  final String? photoUrl;
  final String? instagram;
  final String? twitter;
  final String? snapchat;
  final String? facebook;

  DirectoryPerson({
    required this.id,
    this.legacyUserId,
    required this.name,
    this.gender,
    required this.generation,
    required this.isAlive,
    this.residenceCity,
    this.job,
    this.fatherId,
    this.fatherName,
    this.motherId,
    this.motherName,
    this.motherExternalName,
    this.spouseId,
    this.spouseExternalName,
    this.grandfatherName,
    this.birthDate,
    this.deathDate,
    this.birthCity,
    this.birthCountry,
    this.education,
    this.isVip = false,
    this.greatGrandfatherName,
    this.greatGreatGrandfatherName,
    this.mobilePhone,
    this.email,
    this.photoUrl,
    this.instagram,
    this.twitter,
    this.snapchat,
    this.facebook,
  });

  factory DirectoryPerson.fromJson(Map<String, dynamic> json) {
    // معالجة contact_info (قد يكون List أو Map أو null)
    Map<String, dynamic>? contactMap;
    final contact = json['contact_info'];
    
    if (contact != null) {
      if (contact is List && contact.isNotEmpty) {
        try {
          contactMap = contact.first as Map<String, dynamic>?;
        } catch (e) {
          print('⚠️ خطأ في تحويل contact_info من List: $e');
        }
      } else if (contact is Map<String, dynamic>) {
        contactMap = contact;
      }
    }

    return DirectoryPerson(
      id: json['id'] as String? ?? '',
      legacyUserId: json['legacy_user_id'] as String?,
      name: (json['name'] as String?) ?? '',
      gender: json['gender'] as String?,
      generation: (json['generation'] as int?) ?? 0,
      isAlive: (json['is_alive'] as bool?) ?? true,
      residenceCity: json['residence_city'] as String?,
      job: json['job'] as String?,
      fatherId: json['father_id'] as String?,
      fatherName: json['father_name'] as String?,
      motherId: json['mother_id'] as String?,
      motherName: json['mother_name'] as String?,
      motherExternalName: json['mother_external_name'] as String?,
      spouseId: json['spouse_id'] as String?,
      spouseExternalName: json['spouse_external_name'] as String?,
      grandfatherName: json['grandfather_name'] as String?,
      greatGrandfatherName: json['great_grandfather_name'] as String?,
      greatGreatGrandfatherName: json['great_great_grandfather_name'] as String?,
      birthDate: json['birth_date'] != null ? DateTime.tryParse(json['birth_date']) : null,
      deathDate: json['death_date'] != null ? DateTime.tryParse(json['death_date']) : null,
      birthCity: json['birth_city'] as String?,
      birthCountry: json['birth_country'] as String?,
      education: json['education'] as String?,
      isVip: json['is_vip'] as bool? ?? false,
      mobilePhone: contactMap?['mobile_phone'] as String?,
      email: contactMap?['email'] as String?,
      photoUrl: contactMap?['photo_url'] as String?,
      instagram: contactMap?['instagram'] as String?,
      twitter: contactMap?['twitter'] as String?,
      snapchat: contactMap?['snapchat'] as String?,
      facebook: contactMap?['facebook'] as String?,
    );
  }

  String get firstLetter => name.isNotEmpty ? name[0] : '؟';
  bool get hasPhone => mobilePhone != null && mobilePhone!.isNotEmpty;
  bool get hasEmail => email != null && email!.isNotEmpty;

  /// بناء سلسلة الأجداد
  String buildAncestralPath(List<DirectoryPerson> allPeople, {int levels = 3}) {
    final names = [name];
    final peopleMap = <String, DirectoryPerson>{};
    
    for (var p in allPeople) {
      peopleMap[p.id] = p;
    }
    
    var current = this;
    
    for (var i = 0; i < levels; i++) {
      if (current.fatherId == null) break;
      
      final father = peopleMap[current.fatherId];
      if (father == null) break;
      
      names.add(father.name);
      current = father;
    }
    
    return names.join(' بن ');
  }
}
