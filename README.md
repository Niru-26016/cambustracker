# 🚌 CambusTracker - Passenger App

A real-time college campus bus tracking application built with Flutter and Firebase. Students can track buses live on a map, get ETA updates, and set arrival alarms.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)

## ✨ Features

### For Students
- **Live Bus Tracking** - Real-time bus location on Google Maps
- **ETA Display** - Estimated time of arrival to your stop
- **Bus Speed** - Current speed of the bus
- **Next Stop Info** - See which stop the bus is approaching
- **Stop Arrival Alarm** - Get notified when bus reaches your stop
- **Multiple Routes** - View all available bus routes
- **Catch Status** - Check if you can catch a specific bus

### For Admins
- **Dashboard** - Overview of all buses and routes
- **Manage Buses** - Add, edit, or remove buses from the system
- **Manage Routes** - Create routes with stops and schedules
- **Manage Drivers** - Assign drivers to buses
- **Route Assignment** - Assign buses to routes
- **Bulk Import** - Import buses, routes, and stops via Excel/CSV
- **Live Map View** - Monitor all active buses in real-time
- **Broadcast Messages** - Send announcements to all users

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Firestore, Authentication)
- **Maps**: Google Maps Flutter
- **Location**: Geolocator, Foreground Task Service
- **Authentication**: Firebase Auth + Google Sign-In

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── bus_model.dart        # Bus entity
│   ├── bus_location.dart     # Real-time bus location
│   ├── route_model.dart      # Route with stops
│   ├── trip_model.dart       # Trip information
│   ├── driver_model.dart     # Driver entity
│   ├── user_model.dart       # User profile
│   └── catch_status.dart     # Bus catch status
├── screens/                  # UI screens
│   ├── splash_screen.dart    # App splash screen
│   ├── login_screen.dart     # Authentication screen
│   ├── student_screen.dart   # Main student interface
│   ├── driver_screen.dart    # Driver view (legacy)
│   └── admin/                # Admin panel screens
│       ├── admin_dashboard.dart
│       ├── manage_buses_screen.dart
│       ├── manage_routes_screen.dart
│       ├── manage_drivers_screen.dart
│       ├── route_assignment_screen.dart
│       ├── bulk_import_screen.dart
│       └── broadcast_screen.dart
├── services/                 # Business logic
│   ├── auth_service.dart     # Authentication handling
│   ├── firestore_service.dart # Firestore operations
│   ├── location_service.dart # GPS location
│   ├── alarm_service.dart    # Stop arrival alerts
│   └── direction_service.dart # Route directions
├── utils/                    # Utility functions
└── widgets/                  # Reusable widgets
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Firebase project with Firestore enabled
- Google Maps API key
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/cambustracker.git
   cd cambustracker
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add Android/iOS apps to your Firebase project
   - Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
   - Place in respective platform directories

4. **Add Google Maps API Key**
   - Get an API key from [Google Cloud Console](https://console.cloud.google.com)
   - Android: Add to `android/app/src/main/AndroidManifest.xml`
   - iOS: Add to `ios/Runner/AppDelegate.swift`

5. **Run the app**
   ```bash
   flutter run
   ```

### Build APK

```bash
flutter build apk --release
```

## 🔥 Firebase Setup

### Firestore Collections

- `users` - User profiles and roles
- `buses` - Bus information
- `routes` - Route details with stops
- `drivers` - Driver profiles
- `bus_locations` - Real-time bus positions (updated by driver app)
- `trips` - Active and completed trips

### Security Rules

See `firestore.rules` for Firestore security configuration.

## 📱 Screenshots

> Add screenshots of your app here

## 🤝 Related Projects

- [CambusTracker Driver](https://github.com/yourusername/cambustracker_driver) - Companion driver app for real-time location sharing

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 👨‍💻 Author

Developed by **Niranjan**

---

⭐ Star this repo if you find it helpful!
