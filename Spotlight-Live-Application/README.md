# Spotlight Live iOS Uygulaması – Firebase Entegrasyonu

Bu depo, Spotlight Live SwiftUI uygulamasının Firebase ile **tam entegre** çalışan sürümünü içerir. Tüm kimlik doğrulama, veri okuma/yazma ve durum yönetimi artık Firebase servisleri üzerinden ilerler; ayrı bir backend ihtiyacı yoktur. Aşağıdaki adımları izleyerek projeyi Firebase ile uçtan uca çalışır hale getirebilirsiniz.

## 1. Firebase kurulumu
1. [Firebase Console](https://console.firebase.google.com) üzerinden yeni bir iOS uygulaması oluşturun.
2. `GoogleService-Info.plist` dosyasını indirin ve Xcode projesine (Target > Runner) ekleyin.
3. Firebase SDK'larını Swift Package Manager ile ekleyin: `File > Add Packages` menüsünden `https://github.com/firebase/firebase-ios-sdk` adresini girin ve aşağıdaki paketleri dahil edin:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFirestoreSwift`
4. Eğer daha önce CocoaPods kullanıyorsanız, Podfile'daki Firebase bağımlılıklarını güncelleyin ve `pod install` çalıştırın (SPM önerilir).
5. Uygulama açıldığında `Spotlight_Live_ApplicationApp` içinde `FirebaseService.shared.configureIfNeeded()` çağrısı otomatik yapılır; ek konfigürasyon gerektirmez.

## 2. Firestore veri şeması
Aşağıdaki koleksiyonları Firestore'da oluşturun (güvenlik kuralları bölümüne bakmayı unutmayın):

### `users`
Her kullanıcı için `uid` dokümanında şu alanlar bulunur:
- `displayName`: String
- `avatarUrl`: String? (opsiyonel)
- `city`: String
- `createdAtUtc`: Timestamp

### `categories`
Kategori dokümanları manuel veya script ile eklenir. Örnek veri:
```
{ id: "culture", key: "culture", name: "Culture", colorHex: "#7E57C2" }
{ id: "sports",  key: "sports",  name: "Sports",  colorHex: "#42A5F5" }
{ id: "lifestyle", key: "lifestyle", name: "Lifestyle", colorHex: "#FB8C00" }
{ id: "night", key: "night", name: "Night", colorHex: "#EF5350" }
```
Eğer koleksiyon boş ise uygulama otomatik olarak `EventCategory.sample` değerleriyle çalışır.

### `events`
- Otomatik doküman ID'si kullanılır.
- Alanlar: `title`, `description`, `categoryKey`, `latitude`, `longitude`, `startTimeUtc`, `endTimeUtc`, `createdAtUtc`, `createdByUserId`, `isPublic`.
- `MapTabView` ve `DiscoverView` tarafında yarıçap filtresi uygulama içinde hesaplandığı için ek geo-hash kütüphanesi gerekmez.

### `attendance`
- Doküman ID'si `"<eventId>-<userId>"` formatındadır.
- Alanlar: `eventId`, `userId`, `status` (`going`, `maybe`, `notGoing`), `createdAtUtc`.

## 3. Güvenlik kuralları (özet)
Kendi ihtiyacınıza göre güncelleyin, ancak en temel haliyle kayıtlı kullanıcının sadece kendi verisini yazabildiğinden emin olun:
```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    match /categories/{document=**} {
      allow read: if true;
      allow write: if false; // kategorileri manuel yönetiyorsanız
    }

    match /events/{eventId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && request.resource.data.createdByUserId == request.auth.uid;
    }

    match /attendance/{attendanceId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

## 4. Uygulama davranışı ve akış
- **Kimlik doğrulama**: `AuthView` Firebase Authentication ile e-posta/şifre girişi yapar. Başarılı giriş veya kayıt sonrası Firestore'daki kullanıcı profili okunur ve `TokenStore` ile kimlik bilgisi saklanır.
- **Etkinlik oluşturma**: `CreateEventView` Firebase'deki `events` koleksiyonuna yazma yapar. Kullanıcı giriş yapmamışsa işlem engellenir.
- **Harita ve keşfet**: `MapTabView` ve `DiscoverView` Firestore'dan çekilen etkinlikleri cihazda mesafe filtresi uygulayarak gösterir. Artık veri doğrudan Firebase'den gelir; lokal mock veya farklı backend yoktur.
- **Katılım durumu**: `EventDetailView` içerisindeki katılım butonları `attendance` koleksiyonundaki ilgili dokümanı günceller ve aynı anda UI'da status rozetini yeniler.
- **Oturum devamlılığı**: Uygulama açılışında `AppState` Firebase'deki mevcut oturumu tespit eder ve kullanıcıyı otomatik tanır.

## 5. Bilinen sorun gidermeleri
- **Haritadaki etkinlik detayının açılıp hemen kapanması**: Harita seçimi artık etkinlik ID'si üzerinden yönetiliyor ve kamera hareketleri sadece sürükleme bittiğinde yeni veri çekiyor. Bu sayede aynı pine tekrar tıkladığınızda detay sayfası kararlı şekilde açık kalır.

## 6. Geliştirme ipuçları
- Firestore sorgularında coğrafi indeks kullanmıyoruz; ihtiyaç duyarsanız `GeoFire` veya Firestore'un konum indekslerini entegre edebilirsiniz.
- `EventCategory.sample` uygulamayı boş kategorilerle dahi çalışır halde tutar; prod ortamında mutlaka gerçek kategori dokümanlarını ekleyin.
- Test cihazınızda konum izinlerini verdiğinizden emin olun; aksi halde yakın çevre etkinlik sorguları boş dönebilir.

