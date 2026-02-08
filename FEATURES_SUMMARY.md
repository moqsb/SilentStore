  # ملخص مميزات تطبيق SilentStore

> مستند مرجعي لإعادة بناء التطبيق في مشروع جديد — يحتوي على كل المميزات والوظائف والتقنيات المستخدمة.

---

## 1. نظرة عامة

**SilentStore** تطبيق **مخزن ملفات مشفّر** على iPhone يعتمد على:
- تشفير محلي AES-256 مع مفتاح رئيسي محمي بـ **Secure Enclave**
- فتح التطبيق بـ **Face ID / Touch ID / كلمة مرور الجهاز**
- واجهة SwiftUI حديثة، دعم عربي/إنجليزي، وضع عمودي فقط، iPhone فقط (بدون iPad)

---

## 2. الأمان والتشفير

### 2.1 المصادقة (AuthManager)
- فتح التطبيق يتطلب **Face ID أو Touch ID أو كلمة مرور الجهاز** (`.deviceOwnerAuthentication`)
- حالة مصادقة: `isAuthenticated` تُحدَّث بعد نجاح/فشل المصادقة
- إذا لم يتوفر بيومتري/كلمة مرور: يُسمح بالدخول لتجنب حبس المستخدم
- مهلة احتياطية (مثلاً 8 ثوانٍ) إذا لم يرد النظام لتجنب بقاء الشاشة عالقة

### 2.2 إدارة المفتاح (KeyManager)
- **مفتاح رئيسي (Master Key)**: مفتاح متماثل 256 بت (CryptoKit `SymmetricKey`)
- **التخزين**: المفتاح الرئيسي يُغلَّف (wrapped) بالمفتاح العام لـ Secure Enclave ويُحفظ في Keychain
- **الاسترجاع**: فك التغليف عبر Secure Enclave (قد يطلب Face ID/Touch ID)
- **مفتاح الاسترداد (Recovery Key)**:
  - إنشاء مفتاح استرداد عشوائي (Base64) وعرضه للمستخدم مرة واحدة
  - تشفير المفتاح الرئيسي به وحفظ الـ blob في Keychain
  - استرداد المفتاح الرئيسي لاحقاً بإدخال مفتاح الاسترداد (استعادة بعد فقدان الجهاز/إعادة تثبيت)
- **مسح الذاكرة**: عند خروج التطبيق للخلفية أو عدم النشاط يُمسح المفتاح الرئيسي من الذاكرة (`clearMasterKeyFromMemory`)

### 2.3 Secure Enclave (SecureEnclaveHelper)
- زوج مفاتيح منحني إهليلجي (P-256) داخل **Secure Enclave**
- إنشاء المفتاح مع `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` و `.userPresence`
- تغليف المفتاح الرئيسي بالمفتاح العام؛ فك التغليف بالمفتاح الخاص (يتطلب حضور المستخدم)

### 2.4 التشفير (Crypto)
- **خوارزمية**: AES-GCM (CryptoKit)
- تشفير/فك تشفير البيانات بالمفتاح الرئيسي
- مسح بيانات حساسة من الذاكرة بعد الاستخدام (`zeroOut`)

### 2.5 Keychain (KeychainHelper)
- تخزين واسترجاع بيانات حساسة (المفتاح المغلف، blob الاسترداد) في Keychain

---

## 3. المخزن (Vault) والبيانات

### 3.1 نموذج البيانات
- **VaultItem**: معرف، اسم أصلي، MIME، حجم، تاريخ إنشاء، اسم الملف على القرص، فئة/مجلد، SHA256، هل صورة
- **FolderNode**: مجلدات افتراضية (اسم، عناصر، مجلدات فرعية) مع حجم وعدد العناصر
- **تصنيف الملفات**: صورة، فيديو، مستند (pdf, doc, txt, …)، أخرى — مع أيقونة مناسبة

### 3.2 التخزين الفعلي
- **ملفات مشفّرة**: داخل `Application Support/SilentStore/EncryptedFiles/` بأسماء UUID
- **البيانات الوصفية**: Core Data (VaultEntity) — نفس الحقول مثل VaultItem
- **هاش SHA256** لكل ملف (للكشف عن التكرارات لاحقاً)
- **حماية الملفات**: `FileProtectionType.complete`، استبعاد من النسخ الاحتياطي

### 3.3 VaultStore (المنطق الرئيسي)
- تحميل/تهيئة: تحضير المفتاح، ترحيل من metadata.json قديم إن وُجد، تحميل من Core Data، بناء شجرة المجلدات
- **إضافة ملف**: تشفير المحتوى، حفظ على القرص، إنشاء كيان Core Data، (اختياري) تصنيف الصور بـ Core ML
- **حذف عنصر/عناصر**
- **تعيين فئة (مجلد)** لمجموعة عناصر: `assignCategory(forIDs:category:)`
- **فك تشفير لعرض الملف**: `decryptItemData(_:)`
- **فلاتر**: الكل، صور، فيديو، مستندات، أخرى
- **بحث** بالاسم والفئة
- **ترتيب**: الأحدث، الأقدم، الاسم A–Z / Z–A، الحجم تصاعدي/تنازلي
- **تكرارات**: `findExactDuplicates()` بناءً على SHA256
- **حذف أصل من Photos**: `deletePHAsset(localIdentifier:completion:)` بعد استيراد صورة
- **معلومات التخزين**: `totalAppStorageBytes()`، `deviceStorage()` (إجمالي/متاح الجهاز)، `breakdownByType()`

---

## 4. الاستيراد (Import)

### 4.1 ImportManager
- **منتقي الصور (PHPickerViewController)**: صور وفيديو من مكتبة الصور، حد اختيار 1
  - صورة → JPEG، فيديو → قراءة من URL مؤقت وإرجاع Data
  - إرجاع `assetIdentifier` لاحتمال حذف الأصل لاحقاً
- **منتقي المستندات (UIDocumentPickerViewController)**: فتح محتوى بأنواع عامة (UTType.item)، كنسخ
  - قراءة الملف **قبل** إغلاق الـ picker (لضمان صلاحية الرابط)
  - دعم security-scoped resource إن وُجد
  - MIME من امتداد الملف أو `application/octet-stream`
- **Completion**: (Data, اسم الملف, MIME, هل صورة, assetId?) → يُستدعى على Main

### 4.2 AddMenu (قائمة الإضافة)
- استيراد من **الصور** أو **ملف** (مستندات)
- بعد الاستيراد: خيار حذف الأصل من مكتبة الصور (تنبيه ثم استدعاء `deletePHAsset`)

---

## 5. الواجهة (UI) والشاشات

### 5.1 التدفق العام
- **SilentStoreApp**: WindowGroup → ContentView مع بيئة Core Data و VaultStore
- عند الظهور: مصادقة (AuthManager)، تقييم صلاحيات أولية (PermissionsManager)
- Sheet لصلاحيات البداية (Photos، كاميرا، إشعارات) — مرة واحدة لكل تثبيت

### 5.2 ContentView
- NavigationStack → VaultHomeView
- عند الانتقال للخلفية/غير نشط: إظهار طبقة سوداء (إخفاء المحتوى) ومسح المفتاح من الذاكرة
- التخطيط: ملء الشاشة (`frame(maxWidth: .infinity, maxHeight: .infinity)`)

### 5.3 الشاشة الرئيسية (VaultHomeView)
- **فلاتر أفقية**: الكل، صور، فيديو، مستندات، أخرى (Chips)
- **وضع العرض**: شبكة (Grid) أو قائمة (List)
- **ترتيب**: قائمة من القائمة (Newest, Oldest, Name A–Z/Z–A, Size)
- **بحث**: searchable في شريط التنقل
- **شريط أدوات**: إعدادات، قائمة (عرض/ترتيب/مجلدات)، في الأسفل: تحديد، إضافة (AddMenu)
- **وضع التحديد**: تحديد عناصر، نقل لمجلد (CreateFolderSheet)، حذف
- **مجلدات**: Sheet لـ FolderBrowserView (تصفح المجلدات)
- **حالة فارغة**: رسالة وأيقونة عند عدم وجود عناصر

### 5.4 عرض الملف (FileViewer)
- فك تشفير وتحميل المحتوى في `task`
- **صور**: عرض مع Zoom (تكبير/تصغير، نقر مزدوج)
- **فيديو**: AVPlayer
- **نص (txt)**: ScrollView مع نص
- **غير مدعوم**: عرض اسم، نوع، حجم + رسالة "لا يمكن المعاينة"
- **شريط أدوات**: معلومات الملف (FileInfoSheet)، مشاركة (للصور)، حذف
- **تنظيف**: مسح الصورة/رابط الفيديو المؤقت عند الخروج

### 5.5 FileInfoSheet
- تفاصيل: الاسم، النوع، الحجم، الفئة، المجلد، تاريخ الإنشاء، المعرف
- قسم أمان: AES-256، Secure Enclave

### 5.6 الإعدادات (SettingsView)
- **أمان**: تفعيل/تعطيل AI المحلي، إنشاء مفتاح استرداد، استرداد بمفتاح
- **التذكير**: تذكير أسبوعي (تفعيل/إيقاف)، وقت، موعد التذكير التالي
- **التخزين**: سعة الجهاز والمتاحة، حجم التطبيق، رابط لوحة التخزين، رابط سياسة الخصوصية
- **RecoveryModal**: عرض مفتاح الاسترداد مع تحذير، نسخ ومشاركة

### 5.7 لوحة التخزين (StorageDashboard)
- **بطاقة جهاز**: استخدام التخزين (شريط، نسبة، متاح)
- **بطاقة المخزن**: إجمالي الحجم المشفّر، عدد الملفات، نسبة من جهاز
- **تفصيل حسب النوع**: صور، فيديو، مستندات، أخرى (أشرطة ونسب)
- **التكرارات**: مجموعات ملفات مكررة (نفس SHA256)، إمكانية "تنظيف" (حذف النسخ الزائدة)

### 5.8 مجلدات (FolderBrowserView / FolderDetailView)
- قائمة مجلدات مع عدد العناصر والحجم
- الدخول لمجلد وعرض محتوياته (شبكة)، مع إمكانية التنقل لعرض الملف

### 5.9 صلاحيات (PermissionsView)
- رسالة ترحيب بالصلاحيات مع زرَي "السماح" و "تخطي"
- عند السماح: طلب صلاحيات الصور (قراءة/كتابة)، الكاميرا، الإشعارات

### 5.10 الخصوصية (PrivacyView)
- عرض نص سياسة الخصوصية (من ملف PRIVACY إن وُجد، أو نص افتراضي)

### 5.11 التصميم (AppTheme)
- ألوان: accent، تدرجات، خلفية البطاقات
- خطوط: عناوين، body، caption (مع rounded حيث يناسب)
- أنماط أزرار: Primary (تدرج)، Secondary
- زوايا ومسافات موحّدة (cornerRadius، padding)

---

## 6. الذكاء الاصطناعي (اختياري)

### 6.1 CoreMLManager
- نموذج: **ImageClassifier** (ملف `.mlmodelc` في الـ bundle)
- تصنيف الصور محلياً (Vision + Core ML)
- عند إضافة صورة وكون "aiEnabled" مفعّل: تصنيف الصورة وحفظ النتيجة كـ **category** للعنصر (تصنيف تلقائي)

---

## 7. التذكيرات

### 7.1 ReminderManager
- طلب صلاحية الإشعارات
- **تذكير أسبوعي**: تكرار أسبوعي (يوم، ساعة، دقيقة) مع عنوان ونص عربي
- إلغاء/إعادة جدولة عند تفعيل/إيقاف من الإعدادات

---

## 8. التقنيات والمتطلبات

- **اللغة**: Swift، SwiftUI
- **الحد الأدنى**: iOS مناسب للمشروع (مثلاً 26.x في الإعداد الحالي؛ يُضبط حسب الحاجة)
- **الأطر**: Foundation, SwiftUI, CryptoKit, LocalAuthentication, Security, CoreData, Photos, PhotosUI, AVFoundation, UserNotifications, Vision, CoreML, UIKit
- **التوجيه**: Portrait فقط
- **الجهاز**: iPhone فقط (TARGETED_DEVICE_FAMILY = 1)
- **اللغة**: دعم عربي وإنجليزي (ar.lproj, en.lproj مع Localizable.strings و InfoPlist.strings)

---

## 9. هيكل المشروع المقترح (للمشروع الجديد)

```
App/
  SilentStoreApp.swift
  ContentView.swift
Views/
  SplashView.swift
  VaultHomeView.swift
  VaultHomeGrid.swift (اختياري، عرض بديل)
  FileViewer.swift
  SettingsView.swift
  StorageDashboard.swift
  FolderBrowserView.swift
  PermissionsView.swift
  PrivacyView.swift
  AddMenuView.swift
Managers/
  AuthManager.swift
  ImportManager.swift
  PermissionsManager.swift
  ReminderManager.swift
  CoreMLManager.swift (إن وُجد نموذج ML)
Data/
  Persistence.swift (Core Data stack)
  VaultCoreData.swift (نموذج VaultEntity)
  VaultStore.swift
Helpers/
  AppTheme.swift
  Crypto.swift
  KeychainHelper.swift
  KeyManager.swift
  SecureEnclaveHelper.swift
  PickerSheets.swift (PhotoPickerSheet, DocumentPickerSheet)
Resources/
  AppInfo.plist
  Assets.xcassets
  ar.lproj / en.lproj
  ImageClassifier.mlmodelc (إن استخدمت AI)
```

---

## 10. نقاط حرجة عند إعادة البناء

1. **ترتيب الاستيراد**: قراءة ملف المستند **قبل** إغلاق الـ document picker، واستدعاء الـ completion على Main.
2. **المفتاح والذاكرة**: مسح المفتاح الرئيسي عند الخروج للخلفية؛ إعادة استرجاعه عند العودة (مع مصادقة).
3. **الترحيل**: دعم ترحيل من metadata.json قديم إلى Core Data مرة واحدة.
4. **الصلاحيات**: وصف استخدام الصور، الكاميرا، Face ID، في Info.plist.
5. **الوضع العمودي**: UISupportedInterfaceOrientations = Portrait فقط في المشروع و/أو Info.plist.

---

هذا الملخص يغطي كل المميزات والوظائف والتقنيات في SilentStore ويمكن استخدامه كقائمة تحقق ومخطط عند إعادة بناء التطبيق في مشروع جديد.
