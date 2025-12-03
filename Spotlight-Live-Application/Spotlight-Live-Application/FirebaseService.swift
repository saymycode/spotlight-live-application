import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import MapKit

struct FirestoreKeys {
    static let users = "users"
    static let events = "events"
    static let categories = "categories"
    static let attendance = "attendance"
}

final class FirebaseService {
    static let shared = FirebaseService()
    private var isConfigured = false

    private init() {}

    func configureIfNeeded() {
        if FirebaseApp.app() != nil {
            print("[FirebaseService] Firebase already configured.")
            // Yüklü olan options ve plist doğrulamasını yine de yapalım:
            logFirebaseOptionsAndPlist()
            return
        }
        print("[FirebaseService] FirebaseApp.configure() starting...")
        FirebaseApp.configure()
        isConfigured = true
        print("[FirebaseService] FirebaseApp.configure() finished. isConfigured=\(isConfigured)")
        logFirebaseOptionsAndPlist()
    }

    // MARK: - Deep Config Logging

    private func logFirebaseOptionsAndPlist() {
        print("========== [FirebaseService] CONFIG CHECK BEGIN ==========")

        // 1) FirebaseApp options
        if let app = FirebaseApp.app() {
            let opts = app.options
            print("[FirebaseService] FirebaseApp.options.projectID      = \(opts.projectID ?? "nil")")
            print("[FirebaseService] FirebaseApp.options.googleAppID     = \(opts.googleAppID)")
            print("[FirebaseService] FirebaseApp.options.bundleID        = \(opts.bundleID)")
            print("[FirebaseService] FirebaseApp.options.gcmSenderID     = \(opts.gcmSenderID ?? "nil")")
            print("[FirebaseService] FirebaseApp.options.clientID        = \(opts.clientID ?? "nil")")
            print("[FirebaseService] FirebaseApp.options.databaseURL     = \(opts.databaseURL ?? "nil")")
            print("[FirebaseService] FirebaseApp.options.storageBucket   = \(opts.storageBucket ?? "nil")")
        } else {
            print("[FirebaseService] FirebaseApp.app() is nil after configure! Check GoogleService-Info.plist.")
        }

        // 2) App Bundle Identifier
        let runtimeBundleID = Bundle.main.bundleIdentifier ?? "nil"
        print("[FirebaseService] Bundle.main.bundleIdentifier         = \(runtimeBundleID)")

        // 3) GoogleService-Info.plist'ı bundle'dan bulmayı dene
        if let plistURL = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") {
            print("[FirebaseService] GoogleService-Info.plist found at   = \(plistURL.path)")
            do {
                let data = try Data(contentsOf: plistURL)
                if let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    // Önemli alanları logla
                    let plistBundleID = dict["BUNDLE_ID"] as? String ?? "nil"
                    let plistGoogleAppID = dict["GOOGLE_APP_ID"] as? String ?? "nil"
                    let plistProjectID = dict["PROJECT_ID"] as? String ?? "nil"
                    let plistGcmSenderID = dict["GCM_SENDER_ID"] as? String ?? "nil"
                    print("[FirebaseService] Plist.BUNDLE_ID                  = \(plistBundleID)")
                    print("[FirebaseService] Plist.GOOGLE_APP_ID              = \(plistGoogleAppID)")
                    print("[FirebaseService] Plist.PROJECT_ID                 = \(plistProjectID)")
                    print("[FirebaseService] Plist.GCM_SENDER_ID              = \(plistGcmSenderID)")

                    // 4) Eşleşme kontrolleri
                    if let app = FirebaseApp.app() {
                        let opts = app.options
                        let optionsBundleID = opts.bundleID
                        if optionsBundleID != plistBundleID {
                            print("[FirebaseService][WARN] options.bundleID != Plist.BUNDLE_ID -> \(optionsBundleID) vs \(plistBundleID)")
                        } else {
                            print("[FirebaseService] options.bundleID matches Plist.BUNDLE_ID")
                        }
                        if runtimeBundleID != plistBundleID {
                            print("[FirebaseService][WARN] Bundle.main.bundleIdentifier != Plist.BUNDLE_ID -> \(runtimeBundleID) vs \(plistBundleID)")
                        } else {
                            print("[FirebaseService] Bundle.main.bundleIdentifier matches Plist.BUNDLE_ID")
                        }
                    }
                } else {
                    print("[FirebaseService][ERROR] GoogleService-Info.plist could not be parsed as dictionary.")
                }
            } catch {
                print("[FirebaseService][ERROR] Failed to read GoogleService-Info.plist: \(error)")
            }
        } else {
            print("[FirebaseService][ERROR] GoogleService-Info.plist NOT FOUND in app bundle.")
            print("[FirebaseService][HINT] Ensure the file is added to the project and target membership is checked.")
        }

        // 5) Copy Bundle Resources doğrulaması (dolaylı)
        // Doğrudan build phase’i okuyamayız ama en azından varlığını ve path’ini logladık.
        // Eğer bulunamadıysa, Target Membership ve Build Phases > Copy Bundle Resources kontrol edilmeli.

        print("========== [FirebaseService] CONFIG CHECK END   ==========")
    }

    // MARK: - Auth

    func register(email: String, password: String, displayName: String, city: String) async throws -> AuthResponse {
        print("[FirebaseService] register called. email=\(email), displayName=\(displayName), city=\(city), pwdLen=\(password.count)")
        do {
            print("[FirebaseService] -> Auth.createUser")
            let result = try await auth.createUser(withEmail: email, password: password)
            print("[FirebaseService] <- Auth.createUser OK. uid=\(result.user.uid) emailVerified=\(result.user.isEmailVerified)")

            let profile = User(
                id: result.user.uid,
                displayName: displayName,
                avatarUrl: nil,
                city: city,
                createdAtUtc: Date()
            )

            print("[FirebaseService] -> saveUserProfile")
            try await saveUserProfile(profile)
            print("[FirebaseService] <- saveUserProfile OK.")

            print("[FirebaseService] -> user.getIDToken")
            let token = try await result.user.getIDToken()
            print("[FirebaseService] <- user.getIDToken OK. token.len=\(token.count)")

            let response = AuthResponse(token: token, user: profile)
            print("[FirebaseService] register success. user.id=\(response.user.id)")
            return response
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] register failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        print("[FirebaseService] login called. email=\(email), pwdLen=\(password.count)")
        do {
            print("[FirebaseService] -> Auth.signIn")
            let result = try await auth.signIn(withEmail: email, password: password)
            print("[FirebaseService] <- Auth.signIn OK. uid=\(result.user.uid)")

            print("[FirebaseService] -> fetchUserProfile")
            let profile = try await fetchUserProfile(uid: result.user.uid)
            print("[FirebaseService] <- fetchUserProfile OK. user.id=\(profile.id)")

            print("[FirebaseService] -> user.getIDToken")
            let token = try await result.user.getIDToken()
            print("[FirebaseService] <- user.getIDToken OK. token.len=\(token.count)")

            let response = AuthResponse(token: token, user: profile)
            print("[FirebaseService] login success. user.id=\(response.user.id)")
            return response
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] login failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    func restoreSession() async -> AuthResponse? {
        print("[FirebaseService] restoreSession called.")
        guard let user = auth.currentUser else {
            print("[FirebaseService] restoreSession: no currentUser.")
            return nil
        }
        do {
            print("[FirebaseService] -> fetchUserProfile uid=\(user.uid)")
            let profile = try await fetchUserProfile(uid: user.uid)
            print("[FirebaseService] <- fetchUserProfile OK.")

            print("[FirebaseService] -> user.getIDToken")
            let token = try await user.getIDToken()
            print("[FirebaseService] <- user.getIDToken OK. token.len=\(token.count)")

            let response = AuthResponse(token: token, user: profile)
            print("[FirebaseService] restoreSession success.")
            return response
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] restoreSession failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            return nil
        }
    }

    func logout() async {
        print("[FirebaseService] logout called.")
        do {
            try auth.signOut()
            print("[FirebaseService] signOut OK.")
        } catch {
            print("[FirebaseService] signOut failed: \(error)")
        }
    }

    // MARK: - Catalog

    func fetchCategories() async throws -> [EventCategory] {
        print("[FirebaseService] fetchCategories called.")
        do {
            let snapshot = try await db.collection(FirestoreKeys.categories).getDocuments()
            print("[FirebaseService] fetchCategories snapshot.count=\(snapshot.documents.count)")
            if snapshot.documents.isEmpty {
                print("[FirebaseService] No categories found. Returning sample.")
                return EventCategory.sample
            }
            let items: [EventCategory] = try snapshot.documents.compactMap { document in
                try document.data(as: EventCategory.self)
            }
            print("[FirebaseService] fetchCategories decoded.count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] fetchCategories failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    // MARK: - Events

    func fetchNearbyEvents(lat: Double, lng: Double, radiusKm: Double) async throws -> [Event] {
        print("[FirebaseService] fetchNearbyEvents called. lat=\(lat), lng=\(lng), radiusKm=\(radiusKm)")
        do {
            let snapshot = try await db.collection(FirestoreKeys.events)
                .order(by: "startTimeUtc")
                .getDocuments()
            print("[FirebaseService] events snapshot.count=\(snapshot.documents.count)")
            let userLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let events: [Event] = snapshot.documents.compactMap { doc in
                guard let event = try? doc.data(as: Event.self) else { return nil }
                let distance = DistanceCalculator.distanceKm(from: userLocation, to: event.coordinate)
                return distance <= radiusKm ? event : nil
            }
            print("[FirebaseService] filtered events.count=\(events.count)")
            return events
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] fetchNearbyEvents failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    func fetchEventDetail(id: String) async throws -> Event {
        print("[FirebaseService] fetchEventDetail called. id=\(id)")
        do {
            let event: Event = try await db.collection(FirestoreKeys.events)
                .document(id)
                .getDocument(as: Event.self)
            print("[FirebaseService] fetchEventDetail OK.")
            return event
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] fetchEventDetail failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    func createEvent(_ request: CreateEventRequest, userId: String) async throws -> Event {
        print("[FirebaseService] createEvent called. userId=\(userId) title=\(request.title)")
        do {
            let docRef = db.collection(FirestoreKeys.events).document()
            let now = Date()
            let event = Event(
                id: docRef.documentID,
                title: request.title,
                description: request.description,
                categoryKey: request.categoryKey,
                latitude: request.latitude,
                longitude: request.longitude,
                startTimeUtc: request.startTimeUtc,
                endTimeUtc: request.endTimeUtc,
                createdAtUtc: now,
                createdByUserId: userId,
                isPublic: request.isPublic
            )
            print("[FirebaseService] Writing event to Firestore... id=\(event.id)")
            try docRef.setData(from: event)
            print("[FirebaseService] createEvent OK.")
            return event
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] createEvent failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    func fetchMyEvents(userId: String) async throws -> [Event] {
        print("[FirebaseService] fetchMyEvents called. userId=\(userId)")
        do {
            let snapshot = try await db.collection(FirestoreKeys.events)
                .whereField("createdByUserId", isEqualTo: userId)
                .order(by: "startTimeUtc", descending: true)
                .getDocuments()
            print("[FirebaseService] fetchMyEvents snapshot.count=\(snapshot.documents.count)")
            let items = snapshot.documents.compactMap { try? $0.data(as: Event.self) }
            print("[FirebaseService] fetchMyEvents decoded.count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] fetchMyEvents failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    // MARK: - Attendance

    func fetchAttendance(eventId: String) async throws -> [EventAttendance] {
        print("[FirebaseService] fetchAttendance called. eventId=\(eventId)")
        do {
            let snapshot = try await db.collection(FirestoreKeys.attendance)
                .whereField("eventId", isEqualTo: eventId)
                .getDocuments()
            print("[FirebaseService] fetchAttendance snapshot.count=\(snapshot.documents.count)")
            let items = snapshot.documents.compactMap { try? $0.data(as: EventAttendance.self) }
            print("[FirebaseService] fetchAttendance decoded.count=\(items.count)")
            return items
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] fetchAttendance failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    func setAttendance(eventId: String, status: AttendanceStatus, userId: String) async throws -> EventAttendance {
        print("[FirebaseService] setAttendance called. eventId=\(eventId), status=\(status.rawValue), userId=\(userId)")
        do {
            let documentId = "\(eventId)-\(userId)"
            let docRef = db.collection(FirestoreKeys.attendance).document(documentId)
            let record = EventAttendance(
                id: documentId,
                eventId: eventId,
                userId: userId,
                status: status,
                createdAtUtc: Date()
            )
            print("[FirebaseService] Writing attendance record id=\(documentId)")
            try docRef.setData(from: record)
            print("[FirebaseService] setAttendance OK.")
            return record
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] setAttendance failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    // MARK: - Private

    private var auth: Auth {
        configureIfNeeded()
        return Auth.auth()
    }

    private var db: Firestore {
        configureIfNeeded()
        return Firestore.firestore()
    }

    private func saveUserProfile(_ profile: User) async throws {
        print("[FirebaseService] saveUserProfile called. uid=\(profile.id)")
        do {
            let ref = db.collection(FirestoreKeys.users).document(profile.id)
            try ref.setData(from: profile)
            print("[FirebaseService] saveUserProfile OK.")
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] saveUserProfile failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }

    private func fetchUserProfile(uid: String) async throws -> User {
        print("[FirebaseService] fetchUserProfile called. uid=\(uid)")
        do {
            let user: User = try await db.collection(FirestoreKeys.users)
                .document(uid)
                .getDocument(as: User.self)
            print("[FirebaseService] fetchUserProfile OK.")
            return user
        } catch {
            let nsError = error as NSError
            print("[FirebaseService] fetchUserProfile failed.")
            print("[FirebaseService] error.localizedDescription = \(error.localizedDescription)")
            print("[FirebaseService] NSError.domain = \(nsError.domain)")
            print("[FirebaseService] NSError.code = \(nsError.code)")
            print("[FirebaseService] NSError.userInfo = \(nsError.userInfo)")
            throw error
        }
    }
}
