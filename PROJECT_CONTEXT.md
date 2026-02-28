# سياق مشروع شجرة عائلة القويز

## نظرة عامة
تطبيق Flutter لعائلة القويز - شجرة عائلة إلكترونية مع دليل أعضاء وأخبار وإحصائيات.
تم الترحيل من Laravel/MySQL إلى Flutter/Supabase.

## التقنيات
- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL)
- **الخط:** Tajawal (Google Fonts)
- **الثيم:** داكن ذهبي (Dark Gold)
- **الاتجاه:** RTL (عربي)

## مسار المشروع
```
/Users/ibrahimalquwaiz/Documents/المشاريع/family_tree_app/
```

## هيكل المشروع
```
lib/
├── main.dart
├── screens/
│   └── home_screen.dart              # الصفحة الرئيسية + البار السفلي (5 عناصر)
├── core/
│   ├── config/supabase_config.dart
│   ├── theme/app_theme.dart          # الألوان والثيم الداكن الذهبي
│   ├── constants/current_user.dart
│   └── navigation/main_navigation.dart  # (قديم - غير مستخدم)
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart    # تسجيل دخول بـ QF ID + PIN
│   │   └── services/auth_service.dart
│   ├── tree/
│   │   ├── screens/tree_screen.dart
│   │   ├── models/person.dart
│   │   ├── layout/tree_layout.dart
│   │   └── widgets/ (tree_painter, person_card, tree_filters)
│   ├── directory/
│   │   ├── screens/ (directory_screen, person_profile_screen)
│   │   ├── models/directory_person.dart
│   │   ├── utils/ (arabic_search, ancestral_chain_search)
│   │   └── widgets/ (chain_search_tab, ancestral_browser)
│   ├── news/
│   │   └── screens/news_screen.dart     # أخبار بـ 4 أنواع (عامة، مناسبات، ولادات، وفيات)
│   ├── stats/
│   │   └── screens/stats_screen.dart    # إحصائيات (عامة، أجيال، حالة اجتماعية، مواليد، مدن)
│   ├── profile/
│   │   └── screens/my_profile_screen.dart
│   ├── notifications/
│   │   └── screens/notifications_screen.dart
│   ├── admin/
│   │   └── screens/admin_screen.dart
│   └── about/
│       └── screens/about_screen.dart
```

## جداول Supabase
```
people          - الأفراد (487+) مع: name, gender, is_alive, generation, father_id, mother_id,
                  birth_date, birth_city, birth_country, residence_city, education, job,
                  legacy_user_id (QF ID), pin_code, is_admin, auth_user_id, is_vip, sort_order
contact_info    - بيانات التواصل (mobile, email, instagram, twitter, snapchat, facebook, photo_url)
marriages       - الزواجات (husband_id, wife_id, wife_external_name, marriage_order, is_current)
girls_children  - أبناء البنات (mother_id, father_name, child_name, child_gender)
news            - الأخبار (news_type, title, content, image_url, is_approved, author_name)
notifications   - الإشعارات (title, body, type, related_id)
family_info     - معلومات العائلة (type, content)
```

## الألوان الرئيسية (AppColors)
```dart
gold: #C8A45C          // اللون الذهبي الأساسي
bgDeep: #0A1628        // خلفية عميقة
bgCard: #111E36        // خلفية البطاقات
textPrimary: #F0EDE6   // نص أساسي
textSecondary: #8A9BB5  // نص ثانوي
accentGreen: #4CAF7D   // أخضر
accentBlue: #4A8FD4    // أزرق
accentRed: #D4654A     // أحمر
accentPurple: #8B6AC2  // بنفسجي
```

## نظام تسجيل الدخول
- يسجل بـ **legacy_user_id** (مثل QF07023) + **pin_code**
- يحوّل QF ID لإيميل وهمي: qf07023@alquwaiz.family
- يستخدم Supabase Auth + SharedPreferences

## البار السفلي (5 عناصر)
1. الرئيسية (home)
2. الشجرة (tree)
3. الدليل (directory)
4. التنبيهات (notifications)
5. حسابي (profile)

## الصفحة الرئيسية تحتوي
- هيدر ترحيب مع gradient
- إحصائيات سريعة (إجمالي، ذكور، إناث، أحياء) من Supabase
- شبكة 6 أقسام (شجرة، دليل، أخبار، إحصائيات، عن العائلة، لوحة تحكم للأدمن)
- آخر 3 أخبار فعلية من قاعدة البيانات
- Pull to refresh

## قاعدة البيانات القديمة
- ملف: u264448118_familyapp.sql
- جدول profiles فيه بيانات الأفراد
- جدول connection_details فيه بيانات التواصل والعناوين
- تم نقل بيانات الإقامة (residence_city) والميلاد (birth_city, birth_country) بنجاح

## Git
- GitHub repo: github.com/ibrahim-quwaiz/family_tree_app
- Tag: v1.0-before-home-update (نقطة رجوع قبل تحديث الصفحة الرئيسية)

## ملاحظات مهمة
- التطبيق يدعم RTL بالكامل
- الخط المستخدم Tajawal من Google Fonts
- كل الشاشات تستخدم AppColors من app_theme.dart
- الأخبار لها 4 أنواع: general, events, births, deaths
- التعليم "أمي" تم تنظيفه وتحويله لـ NULL
- أسماء المدن تم توحيدها (Dawadimi → الدوادمي، Riyadh → الرياض)
