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
> ملاحظة: تمت إزالة مزامنة iCloud من المستندات — في حال ضياع الملفات تحقق من ~/‏iCloud Drive (الأرشيف)/Documents/Projects/

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

## حالة النشر على المتاجر

### Google Play
- **اسم التطبيق:** عائلة القويز
- **Package Name:** com.alquwaiz.familytree
- **الحالة:** إعداد التطبيق مكتمل — يحتاج اختبار مغلق (12 مختبر + 14 يوم)
- **الإصدار:** 2.0.0+10
- **Keystore:** android/app/upload-keystore.jks (alias: upload)
- **Key Properties:** android/key.properties (محمي من Git)
- **بطاقة المتجر:** مكتملة (وصف + لقطات شاشة + أيقونة + رسم مميز)
- **سياسة الخصوصية + أمان البيانات + تقييم المحتوى:** مكتمل

### Apple App Store
- **اسم التطبيق:** عائلة القويز
- **Bundle ID (iOS):** yit.familytree.com (Bundle ID القديم من 2020)
- **Bundle ID (Android):** com.alquwaiz.familytree (مختلف عن iOS)
- **Apple ID:** 1530972790
- **SKU:** FamilyTree
- **الحالة:** الإصدار 2.0.0 مرسل لمراجعة Apple (Waiting for Review)
- **TestFlight:** Build 2.0.0 (10) متاح للاختبار الداخلي
- **مشكلة معلقة:** التطبيق لا يتثبت من TestFlight على iOS 26 — يحتاج تحقيق
- **تنبيه:** قبل 28 أبريل 2026 يجب رفع build مبني بـ Xcode 26

### المطلوب لإكمال النشر
- [ ] Google Play: جمع 12 مختبر وإضافتهم للاختبار المغلق + انتظار 14 يوم
- [ ] Google Play: بعد الاختبار المغلق → تقديم طلب الإصدار العلني
- [ ] App Store: انتظار نتيجة مراجعة Apple
- [ ] App Store: حل مشكلة عدم التثبيت من TestFlight على iOS 26
- [ ] تغيير Display Name لـ "عائلة القويز" في iOS و Android (التحديث القادم)

## Tags المحفوظة
- `v1.0-before-home-update` - قبل تحديث الصفحة الرئيسية
- `v1.2-contact-marital` - تواصل معنا + حالة اجتماعية + تسجيل خروج
- `v1.3-news-image` - إضافة صور الأخبار
- `v-before-news-image` - قبل إضافة صور الأخبار

## هيكل المشروع
```
lib/
├── main.dart
├── screens/
│   └── home_screen.dart
├── core/
│   ├── config/supabase_config.dart
│   ├── theme/app_theme.dart
│   ├── constants/current_user.dart         # loadFromSession() يُستدعى في main.dart
│   └── navigation/main_navigation.dart
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart
│   │   └── services/auth_service.dart
│   ├── tree/screens/tree_screen.dart
│   ├── directory/
│   │   ├── screens/directory_screen.dart
│   │   └── screens/person_profile_screen.dart
│   ├── news/screens/news_screen.dart
│   ├── stats/screens/stats_screen.dart
│   ├── profile/screens/my_profile_screen.dart
│   ├── contact/screens/contact_screen.dart
│   ├── notifications/screens/notifications_screen.dart
│   ├── admin/screens/admin_screen.dart
│   └── about/screens/about_screen.dart
```

## بنية قاعدة البيانات (Supabase)
- **people** (838 سجل) - الأفراد
- **contact_info** - بيانات التواصل مع حقول خصوصية لكل حقل
- **marriages** - الزواجات
- **girls_children** - أبناء البنات
- **news** - الأخبار (4 أنواع + صور)
- **notifications** - الإشعارات (4 أنواع)
- **family_info** - معلومات العائلة
- **support_requests** - طلبات الدعم

## Supabase Storage Buckets
- **photos** (public) ← الصحيح لصور الملفات الشخصية
  - المسار: `profiles/profile_<person_id>.jpg`
- **profile-photos** (public) - قديم، الصور القديمة فيه
- **images** (public) - لصور الأخبار

## RLS Policies على contact_info
```sql
-- SELECT
"select_own_or_admin": person_id IN (SELECT id FROM people WHERE auth_user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM people WHERE auth_user_id = auth.uid() AND is_admin = true)

-- INSERT
"insert_own": person_id IN (SELECT id FROM people WHERE auth_user_id = auth.uid())

-- UPDATE
"update_own_or_admin": person_id IN (SELECT id FROM people WHERE auth_user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM people WHERE auth_user_id = auth.uid() AND is_admin = true)
```

## معلومات المستخدم التجريبي (QF07023 - إبراهيم)
- **person_id:** ecf5a51e-d9c6-400b-ad00-1a0e98b14ba2
- **auth_user_id:** 7fe94cca-f6fe-4ccd-8f19-33803c2fa69d (محدّث)
- **PIN:** 4897
- **حساب مراجعة Apple:** QF08180 / 1234

## الألوان (AppColors)
```dart
gold: #C8A45C, bgDeep: #0A1628, bgCard: #111E36
```

## أوامر البناء
```bash
# تشغيل للتطوير
cd ~/Documents/Projects/family_tree_app && flutter run -d chrome

# APK
JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" flutter build apk --release

# AAB (Google Play)
JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" flutter build appbundle --release

# IPA (App Store)
flutter build ipa --release
```

## المهام المكتملة في آخر جلسة
- [x] إصلاح RLS على contact_info (with_check كانت null)
- [x] إضافة CurrentUser.loadFromSession() في main.dart
- [x] إصلاح تسجيل الدخول بـ PIN (حذف auth user القديم وإعادة الدخول)
- [x] رفع صورة الملف الشخصي في my_profile_screen.dart — يعمل بنجاح
  - bucket: photos، مسار: profiles/profile_<person_id>.jpg
  - update يعمل لأن _contactData غير null
  - auth_user_id في people محدّث ليطابق JWT الحالي

## المهام المعلقة
- [ ] حذف print statements المؤقتة من my_profile_screen.dart
- [ ] تغيير PIN من my_profile_screen.dart
- [ ] تعديل مدينة وبلد الميلاد
- [ ] حذف ابن/زوجة
- [ ] حقول البحث في الدليل - Expandable

## ملاحظات مهمة
- ترتيب الأبناء حسب تاريخ الميلاد (الأكبر أولاً) ثم legacy_user_id
- جميع بيانات التواصل مخفية افتراضياً (show_* = false)
- Bundle ID مختلف: iOS (yit.familytree.com) و Android (com.alquwaiz.familytree)
- يفضل حفظ git + tag قبل أي تعديل كبير
- يستخدم Cursor IDE ويفضل توجيهات مباشرة للـ agent
- المطوّر: إبراهيم بن عبدالله القويز
