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
~/Documents/Projects/family_tree_app/
```
> نُقل من المشاريع/ لتجنب مشاكل Gradle مع المسارات العربية

## GitHub
```
github.com/ibrahim-quwaiz/family_tree_app
```

## Tags المحفوظة
- `v1.0-before-home-update` - قبل تحديث الصفحة الرئيسية
- `v1.2-contact-marital` - تواصل معنا + حالة اجتماعية + تسجيل خروج

## هيكل المشروع
```
lib/
├── main.dart
├── screens/
│   └── home_screen.dart                    # الصفحة الرئيسية + البار السفلي (5 عناصر)
├── core/
│   ├── config/supabase_config.dart
│   ├── theme/app_theme.dart                # الألوان والثيم الداكن الذهبي
│   ├── constants/current_user.dart         # المستخدم الحالي (legacyUserId)
│   └── navigation/main_navigation.dart     # (قديم - غير مستخدم)
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart       # تسجيل دخول بـ QF ID + PIN
│   │   └── services/auth_service.dart      # login(), logout(), isAdmin(), getCurrentQfId()
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
│   │   └── screens/news_screen.dart        # أخبار بـ 4 أنواع (عامة، مناسبات، ولادات، وفيات)
│   ├── stats/
│   │   └── screens/stats_screen.dart       # إحصائيات (عامة، أجيال، حالة اجتماعية، مواليد، مدن)
│   ├── profile/
│   │   └── screens/my_profile_screen.dart  # حسابي + تسجيل خروج
│   ├── contact/
│   │   └── screens/contact_screen.dart     # تواصل معنا (نموذج + واتساب + إيميل)
│   ├── notifications/
│   │   └── screens/notifications_screen.dart
│   ├── admin/
│   │   └── screens/admin_screen.dart       # لوحة تحكم (أشخاص، زواجات، أبناء بنات، أخبار، مستخدمين)
│   └── about/
│       └── screens/about_screen.dart       # عن العائلة + تواصل
```

## بنية قاعدة البيانات (Supabase)

### جدول people (الأفراد - 837 سجل)
```
id                  uuid        PK, uuid_generate_v4()
legacy_user_id      text        NULL - رقم QF (مثل QF07023)
name                text        NOT NULL
gender              text        NULL - male/female
is_alive            boolean     DEFAULT true
generation          integer     NOT NULL - رقم الجيل
birth_date          date        NULL
death_date          date        NULL
birth_date_hijri    text        NULL
death_date_hijri    text        NULL
father_id           uuid        NULL → FK people.id
mother_id           uuid        NULL → FK people.id
mother_external_name text       NULL - اسم الأم إذا مو من العائلة
birth_city          text        NULL
birth_country       text        NULL
residence_city      text        NULL
education           text        NULL
job                 text        NULL
marital_status      text        NULL - متزوج/أعزب/مطلق/أرمل
is_vip              boolean     DEFAULT false
sort_order          integer     DEFAULT 0
pin_code            text        NULL - رمز الدخول
is_admin            boolean     DEFAULT false
auth_user_id        uuid        NULL - Supabase Auth ID
created_at          timestamptz DEFAULT now()
```

### جدول contact_info (بيانات التواصل)
```
id                  uuid        PK, uuid_generate_v4()
person_id           uuid        NOT NULL → FK people.id
mobile_phone        text        NULL
email               text        NULL
instagram           text        NULL
twitter             text        NULL
snapchat            text        NULL
facebook            text        NULL
photo_url           text        NULL
created_at          timestamptz DEFAULT now()
```

### جدول marriages (الزواجات - 35 سجل)
```
id                  uuid        PK, uuid_generate_v4()
husband_id          uuid        NOT NULL → FK people.id
wife_id             uuid        NULL → FK people.id (من العائلة)
wife_external_name  text        NULL - اسم الزوجة إذا مو من العائلة
marriage_order      integer     DEFAULT 1 - رقم الزواج (1، 2، 3...)
marriage_date       text        NULL
is_current          boolean     DEFAULT true - حالية أو سابقة
created_at          timestamptz DEFAULT now()
```

### جدول girls_children (أبناء البنات)
```
id                  uuid        PK, gen_random_uuid()
mother_id           uuid        NOT NULL → FK people.id
father_name         text        NULL
child_name          text        NOT NULL
child_gender        text        NULL - male/female
child_birthdate     text        NULL
created_at          timestamptz DEFAULT now()
```

### جدول news (الأخبار)
```
id                  uuid        PK, uuid_generate_v4()
news_type           text        NOT NULL - general/events/births/deaths
title               text        NOT NULL
content             text        NULL
image_url           text        NULL
is_approved         boolean     DEFAULT false
author_name         text        NULL
author_id           text        NULL
created_at          timestamptz DEFAULT now()
```

### جدول notifications (الإشعارات)
```
id                  uuid        PK, gen_random_uuid()
title               text        NOT NULL
body                text        NULL
type                text        NOT NULL, DEFAULT 'admin_message'
related_id          uuid        NULL
created_at          timestamptz DEFAULT now()
```

### جدول family_info (معلومات العائلة)
```
id                  uuid        PK, gen_random_uuid()
type                text        NOT NULL - النسب/عن التطبيق/whatsapp/sms/email
content             text        NOT NULL
created_at          timestamptz DEFAULT now()
```

### جدول support_requests (طلبات الدعم)
```
id                  uuid        PK, gen_random_uuid()
sender_id           uuid        NULL → FK people.id
sender_name         text        NULL
request_type        text        NOT NULL - تعديل بيانات/إبلاغ عن خطأ/إضافة خبر/اقتراح/أخرى
subject             text        NOT NULL
message             text        NOT NULL
status              text        DEFAULT 'جديد' - جديد/قيد المراجعة/تم الرد/مغلق
admin_reply         text        NULL
created_at          timestamptz DEFAULT now()
updated_at          timestamptz DEFAULT now()
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
accentAmber: #D4A44A   // كهرماني
accentTeal: #4ABDD4    // تركوازي
```

## نظام تسجيل الدخول
- يسجل بـ **legacy_user_id** (مثل QF07023) + **pin_code**
- يحوّل QF ID لإيميل وهمي: qf07023@alquwaiz.family
- يستخدم Supabase Auth + SharedPreferences
- `CurrentUser.loadFromSession()` يُنادى بعد الدخول لتحديث legacyUserId
- `AuthService.isAdmin()` للتحقق من صلاحية المدير

## البار السفلي (5 عناصر)
1. الرئيسية (home)
2. الشجرة (tree)
3. الدليل (directory)
4. التنبيهات (notifications)
5. حسابي (profile)

## الصفحة الرئيسية تحتوي
- هيدر ترحيب مع gradient
- إحصائيات سريعة (إجمالي، ذكور، إناث، أحياء) من Supabase
- شبكة أقسام (شجرة، دليل، أخبار، إحصائيات، تواصل معنا، عن العائلة، لوحة تحكم للأدمن فقط)
- آخر 3 أخبار فعلية من قاعدة البيانات
- Pull to refresh

## صفحة الإحصائيات
- إحصائيات عامة (إجمالي، ذكور، إناث، أحياء، متوفين)
- توزيع الحالة الاجتماعية (من حقل marital_status)
- توزيع الأجيال (رسم بياني)
- المواليد حسب السنة (رسم بياني عمودي + تجميع بالعقود)
- توزيع المدن

## صفحة تواصل معنا
- زر واتساب مباشر (966555113730)
- زر إيميل (ibrahim.sec@gmail.com)
- نموذج إرسال طلب (يحفظ في support_requests)
- عرض الطلبات السابقة مع حالتها ورد الإدارة

## لوحة التحكم (5 تابات)
1. الأشخاص (إضافة/تعديل/حذف + بحث + حقل الحالة الاجتماعية)
2. الزواجات
3. أبناء البنات
4. الأخبار والإشعارات
5. المستخدمين (تعيين مدير/إزالة + بحث)

## بناء APK
```bash
cd ~/Documents/Projects/family_tree_app && JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" flutter build apk --release
```
> يجب استخدام JAVA_TOOL_OPTIONS لتجنب مشكلة الأرقام العربية في Gradle

## ملاحظات مهمة
- التطبيق يدعم RTL بالكامل
- كل الشاشات تستخدم AppColors من app_theme.dart
- لوحة التحكم تظهر فقط للمدير (is_admin = true)
- بيانات الحالة الاجتماعية: 209 متزوج + 619 أعزب (تم نقلها من القاعدة القديمة)
- أسماء المدن تم توحيدها (Dawadimi → الدوادمي، Riyadh → الرياض)
- التعليم "أمي" تم تنظيفه وتحويله لـ NULL
- يفضل حفظ git + tag قبل أي تعديل كبير كنقطة رجوع
- يستخدم Cursor IDE ويفضل توجيهات مباشرة للـ agent بدل تغيير ملفات كاملة
