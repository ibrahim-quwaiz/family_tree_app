# سياق مشروع شجرة عائلة القويز

## نظرة عامة
تطبيق Flutter لعائلة القويز - شجرة عائلة إلكترونية مع دليل أعضاء وأخبار وإحصائيات.
تم الترحيل من Laravel/MySQL إلى Flutter/Supabase.

## التقنيات
- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL)
- **الخط:** Tajawal (Google Fonts)
- **الثيم:** داكن ذهبي + دعم Dark/Light/System
- **الاتجاه:** RTL (عربي)
- **IDE:** Cursor (يفضل توجيهات مباشرة للـ agent)

## مسار المشروع
```
~/Documents/Projects/family_tree_app/
```
> في حال ضياع الملفات: ~/iCloud Drive (الأرشيف)/Documents/Projects/

## GitHub
```
github.com/ibrahim-quwaiz/family_tree_app
```

## سياسة الخصوصية
```
https://ibrahim-quwaiz.github.io/family_tree_app/
```
- مستضافة على GitHub Pages من مجلد /docs
- بالعربي والإنجليزي مع زر تبديل اللغة

## حالة النشر

### Google Play
- **Package Name:** com.alquwaiz.familytree
- **الحالة:** قيد المراجعة للإنتاج (2.0.2+12)
- **الإصدار:** 2.0.2+12
- **الدول:** المملكة العربية السعودية
- **Keystore:** android/app/upload-keystore.jks (alias: upload)
- **Key Properties:** android/key.properties (محمي من Git)
- **Fastlane:** مضبوط — الرفع بأمر `fastlane deploy`
- **Service Account:** android/play-store-credentials.json (محمي من Git)

### Apple App Store
- **Bundle ID (iOS):** yit.familytree.com
- **Bundle ID (Android):** com.alquwaiz.familytree
- **Apple ID:** 1530972790
- **الحالة:** مرسل لمراجعة Apple
- **تنبيه:** قبل 28 أبريل 2026 يجب رفع build مبني بـ Xcode 26
- **مشكلة معلقة:** TestFlight لا يعمل على iOS 26

### المطلوب لإكمال النشر
- [ ] Google Play: جمع 12 مختبر + اختبار مغلق 14 يوم ثم طلب الإصدار العلني
- [ ] App Store: انتظار مراجعة Apple + حل مشكلة TestFlight على iOS 26
- [ ] تغيير Display Name لـ "عائلة القويز" (التحديث القادم)

## معلومات للاختبار
- **QF07023** (إبراهيم - أدمن): person_id: `ecf5a51e-d9c6-400b-ad00-1a0e98b14ba2`
- **QF08180** (حساب مراجعة Apple)
- الـ PIN لأي حساب موجود في جدول `people.pin_code`

## أوامر التشغيل والبناء
```bash
# تشغيل
flutter run -d chrome
flutter run -d 00008120-000449023660C01E   # iPhone

# إصدار
JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" flutter build appbundle --release   # Google Play
flutter build ipa --release        # App Store

# نشر على Google Play (تلقائي)
fastlane deploy
```

## هيكل المشروع
```
lib/
├── main.dart
├── core/
│   ├── config/supabase_config.dart
│   ├── theme/app_theme.dart
│   ├── constants/current_user.dart
│   └── navigation/main_navigation.dart
├── features/
│   ├── auth/ (login_screen, auth_service)
│   ├── tree/, directory/, news/, stats/
│   ├── profile/screens/my_profile_screen.dart
│   ├── contact/, notifications/, admin/, about/
```

## بنية قاعدة البيانات

### people (الرئيسي - 840+ سجل)
- id: UUID
- legacy_user_id: رقم QF
- name, gender, generation
- father_id, mother_id: بدون FK
- auth_user_id: → auth.users.id
- pin_code, is_admin
- photo_url: رابط الصورة (مُنقول من contact_info)
- birth_date, death_date, birth_city, birth_country, residence_city, job, education
- is_alive, is_vip

### contact_info
- person_id → people.id ON DELETE CASCADE
- mobile_phone, email, instagram, twitter, snapchat, facebook
- show_* حقول خصوصية (مخفية افتراضياً)

### marriages
- husband_id → people.id ON DELETE RESTRICT
- wife_id → people.id ON DELETE RESTRICT
- wife_external_name إذا خارجية
- marriage_order, is_current, marriage_date

### girls_children
- mother_id → people.id ON DELETE RESTRICT

### notifications
- recipient_id → people.id ON DELETE CASCADE
- null = عام، person_id = خاص
- أنواع: new_member, news, admin_message, support_reply

### support_requests
- sender_id → people.id ON DELETE SET NULL
- status: جديد / قيد المراجعة / تم الرد
- حذف الطلب من لوحة الأدمن متاح (مع تأكيد)

### news
- 4 أنواع + صور في bucket images

### family_info
- معلومات عامة عن العائلة

## RLS المهمة

### contact_info
- SELECT: سجله + الأدمن الكل
- INSERT: سجله + الأدمن أي شخص
- UPDATE: سجله + الأدمن الكل

### notifications
- SELECT: recipient_id IS NULL أو recipient_id = person_id الحالي
- INSERT/DELETE: الأدمن فقط

## Supabase Storage
- **photos** (public): `profiles/profile_<person_id>.jpg` — لصور الملفات الشخصية
- **images** (public): صور الأخبار
- **profile-photos:** قديم ومهجور

## API Keys
- Publishable key: في `lib/core/config/supabase_config.dart`
- Legacy API keys: معطّلة
- Secret key: `family_tree_admin_key` في Supabase Dashboard

## نظام المصادقة
- تسجيل دخول بـ QF + PIN
- auth_service.dart ينشئ حساب Auth ويحدّث people.auth_user_id
- CurrentUser.legacyUserId يبدأ فارغاً ويُحمّل من loadFromSession()
- loadFromSession() يُستدعى في main.dart وفي بداية _loadProfile()

## ما يستطيع المستخدم تعديله
- الصورة الشخصية
- الرقم السري
- البيانات الشخصية: الجنس، تاريخ الميلاد، مدينة/بلد الميلاد، الإقامة، الوظيفة، التعليم
- بيانات التواصل والاجتماعي + إظهار/إخفاء
- إضافة زوجة (برقم QF) وابن/ابنة
- الثيم

## ترتيب الأبناء
- من عنده تاريخ ميلاد أولاً (الأكبر أولاً)
- الباقي برقم legacy_user_id

## الألوان
gold: #C8A45C / bgDeep: #0A1628 / bgCard: #111E36

## Git Tags
- `v1.0-before-home-update` — قبل تحديث الصفحة الرئيسية
- `v1.2-contact-marital` — تواصل معنا + حالة اجتماعية + تسجيل خروج
- `v1.3-news-image` — إضافة صور الأخبار
- `v2.0-before-theme` — قبل إضافة الثيم

## المهام المنجزة مؤخراً
- [x] إعداد Fastlane للنشر التلقائي على Google Play من الترمنل
- [x] تصحيح applicationId إلى com.alquwaiz.familytree في build.gradle.kts
- [x] إعداد release signing config باستخدام upload-keystore
- [x] رفع الإصدار 2.0.2+12 على Google Play (قيد المراجعة)
- [x] إضافة تعديل وحذف الأبناء من صفحة حسابي
- [x] إضافة تعديل وحذف الزوجات من صفحة حسابي
- [x] توحيد `deleteMarriage()` و`deletePerson()` في `PersonService`
- [x] إضافة `updateMarriage()` في `PersonService`
- [x] إصلاح RLS policies على جداول `people` و`marriages` (`INSERT`, `UPDATE`, `DELETE`)
- [x] إصلاح ربط `auth_user_id` عند أول تسجيل دخول (خطأ 422)
- [x] إضافة `maxLength: 4` على حقول PIN في لوحة التحكم
- [x] إضافة رسائل التحقق تحت الحقول في ديالوجات الإضافة والتعديل
- [x] إضافة زر إضافة زوجة في قسم الزوجات في صفحة حسابي
- [x] إصلاح `_showAddMarriageDialog()` لتكون `Future<void>`
- [x] إضافة تعديل الأم عند تعديل بيانات الابن

## المهام المعلقة
- [ ] توحيد بنية `showModalBottomSheet` (مؤجل لما قبل النشر)
- [ ] Push Notifications (FCM + APNs)
- [ ] App Store: انتظار مراجعة Apple
- [ ] تغيير Display Name لـ "عائلة القويز"
- [ ] تنظيف `print` statements المتبقية
- [ ] تحديث Kotlin إلى 2.1.0+ (تحذير من Flutter)

## ملاحظات مهمة
- photo_url مُنقول من contact_info إلى people
- Bundle ID مختلف: iOS (yit.familytree.com) و Android (com.alquwaiz.familytree)
- يفضل git commit + tag قبل أي تعديل كبير
- المطوّر: إبراهيم بن عبدالله القويز
