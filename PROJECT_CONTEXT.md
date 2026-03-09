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

### المطلوب لإكمال النشر
- [ ] Google Play: جمع 12 مختبر وإضافتهم للاختبار المغلق + انتظار 14 يوم
- [ ] Google Play: بعد الاختبار المغلق → تقديم طلب الإصدار العلني
- [ ] App Store: انتظار نتيجة مراجعة Apple (24-48 ساعة)
- [ ] App Store: حل مشكلة عدم التثبيت من TestFlight
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
│   └── home_screen.dart                    # الصفحة الرئيسية + البار السفلي (5 عناصر) + initialIndex + highlightPersonId
├── core/
│   ├── config/supabase_config.dart
│   ├── theme/app_theme.dart                # الألوان والثيم الداكن الذهبي
│   ├── constants/current_user.dart         # المستخدم الحالي (legacyUserId)
│   └── navigation/main_navigation.dart     # (قديم - غير مستخدم)
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart       # تسجيل دخول بـ QF ID + PIN + شعار التطبيق + زر واتساب للمساعدة
│   │   └── services/auth_service.dart      # login(), logout(), isAdmin(), getCurrentQfId()
│   ├── tree/
│   │   ├── screens/tree_screen.dart        # شجرة العائلة + بحث + ترتيب الأبناء حسب تاريخ الميلاد
│   │   ├── models/person.dart
│   │   ├── layout/tree_layout.dart
│   │   └── widgets/ (tree_painter, person_card, tree_filters)
│   ├── directory/
│   │   ├── screens/directory_screen.dart   # دليل الأعضاء + بحث متعدد الحقول + ترتيب حسب تاريخ الميلاد
│   │   ├── screens/person_profile_screen.dart  # الملف الشخصي + زر "عرض في شجرة العائلة"
│   │   ├── models/directory_person.dart
│   │   ├── utils/ (arabic_search, ancestral_chain_search)
│   │   └── widgets/ (chain_search_tab, ancestral_browser)
│   ├── news/
│   │   └── screens/news_screen.dart        # أخبار بـ 4 أنواع + رفع صورة لـ Supabase Storage
│   ├── stats/
│   │   └── screens/stats_screen.dart       # إحصائيات شاملة
│   ├── profile/
│   │   └── screens/my_profile_screen.dart  # حسابي + خصوصية + ترتيب أبناء حسب تاريخ الميلاد
│   ├── contact/
│   │   └── screens/contact_screen.dart     # تواصل معنا - يجلب البيانات من family_info
│   ├── notifications/
│   │   └── screens/notifications_screen.dart  # إشعارات بـ 4 أنواع
│   ├── admin/
│   │   └── screens/admin_screen.dart       # لوحة تحكم (7 تابات)
│   └── about/
│       └── screens/about_screen.dart       # عن العائلة
├── assets/images/app_logo.png
└── docs/index.html
```

## بنية قاعدة البيانات (Supabase)
- **people** (837 سجل) - الأفراد
- **contact_info** (317 سجل) - بيانات التواصل مع حقول خصوصية لكل حقل
- **marriages** (116 سجل) - الزواجات
- **girls_children** - أبناء البنات
- **news** - الأخبار (4 أنواع + صور)
- **notifications** - الإشعارات (4 أنواع)
- **family_info** - معلومات العائلة (واتساب، إيميل، SMS)
- **support_requests** - طلبات الدعم

## Supabase Storage
- **Bucket: images** (public) - لصور الأخبار

## الألوان (AppColors)
```dart
gold: #C8A45C, bgDeep: #0A1628, bgCard: #111E36
```

## أوامر البناء
```bash
# APK
JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" flutter build apk --release

# AAB (Google Play)
JAVA_TOOL_OPTIONS="-Duser.language=en -Duser.country=US" flutter build appbundle --release

# IPA (App Store)
flutter build ipa --release
```

## ملاحظات مهمة
- ترتيب الأبناء حسب تاريخ الميلاد (الأكبر أولاً) ثم legacy_user_id
- جميع بيانات التواصل مخفية افتراضياً (show_* = false)
- Bundle ID مختلف: iOS (yit.familytree.com) و Android (com.alquwaiz.familytree)
- يفضل حفظ git + tag قبل أي تعديل كبير
- يستخدم Cursor IDE ويفضل توجيهات مباشرة للـ agent
- Claude Code مثبّت على الجهاز
- المطوّر: إبراهيم بن عبدالله القويز
