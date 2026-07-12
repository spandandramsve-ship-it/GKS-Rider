# GKS Rider — Delivery Partner Mobile Application

GKS Rider is a complete, production-grade Flutter mobile application built for delivery partners working with the GKS logistics backend. It enables riders to manage their availability, receive real-time automated order assignments, quote store handoff IDs, share live-tracking coordinates over WebSockets, and process doorstep settlements (Cash or UPI QR).

---

## 📱 App Overview & Features

- **No Self-Signup (Admin-Onboarded)**: Riders are onboarded securely by administrators. Credentials are sent via email. 
- **Two-Factor Authentication**: Security is enforced via phone + password login followed by a mandatory 6-digit email OTP verification.
- **Strict State-Machine Workflow**: The app state is strictly driven by the active order status. Riders are guided step-by-step from pickup to delivery.
- **Visual Store Handoff**: No manual verification code is required at the store. Collection is visual and secure using a daily unique `pickupToken` (e.g. `#0421`).
- **Live Location Tracking**: Real-time GPS tracking stream emits coords over WebSockets (`rider:location`) starting at pickup through delivery, updating the customer's map and logging distance.
- **Flexible Doorstep Settlements**: For Cash-on-Delivery (COD) orders, riders can collect cash or render a dynamic Razorpay UPI QR code, complete with expiration countdowns and payment status polling.

---

## 🛠️ Tech Stack & Architecture

- **Core Framework**: Flutter (Dart)
- **State Management**: Provider (composed via `MultiProvider` at the app root)
- **Real-Time Sockets**: `socket_io_client` (WebSockets)
- **HTTP Client**: `Dio` (fully equipped with auth, envelope unwrapping, and global `401` logout interceptors)
- **Secure Persistence**: `flutter_secure_storage` (Keychain/EncryptedSharedPreferences for JWT and PII data)
- **Mapping & Coords**: `flutter_map` (OpenStreetMap integration) and `geolocator`
- **Navigation**: `go_router` (declarative routing with auth redirect guards)

---

## 🔄 The Delivery State Machine

The interface automatically branches based on the status of the rider's active job (`activeOrder.status`):

| Order Status | Interface State | Primary Action | Endpoint Invoked |
| :--- | :--- | :--- | :--- |
| **No Active Job** | Waiting Dashboard | Slides toggle to go online/offline | `POST /rider/auth/location` |
| **PACKING / PACKED** | Reached Store Screen | Shows map to merchant. Tap when arrived | `PATCH /reached-store` |
| **REACHED_STORE** | Collection Screen | Quotes Handoff ID card. Tap to collect | `PATCH /picked-up` |
| **PICKED_UP (Unpaid)** | Doorstep Map & COD | Select Cash or generate UPI QR | `POST /collect-cash` or `POST /payment-qr` |
| **PICKED_UP (Paid)** | OTP Verification | Asks customer for delivery code | `POST /complete` |
| **DELIVERED** | Completed Summary | Taps finish to return home | Resets dashboard state |

---

## 📂 Project Structure

```
lib/
  main.dart                    # App bootstrap, Router, Providers, Theme
  config/
    env.dart                   # Environment-flavored URLs (dev, local, prod)
  core/
    api_client.dart            # Dio singleton, interceptors, error conversion
    api_exception.dart         # Custom exception wrapping backend message
    session.dart               # Keychain/Storage wrapper for JWT & profile
    location_service.dart      # Geolocator handler, background location loop
    socket_service.dart        # Socket.io handshake, listeners & emitters
  models/
    rider.dart                 # Rider details model (Aadhaar, PAN, vehicle)
    active_order.dart          # Primary active job model
    history_item.dart          # Paginated history order list model
    * (nested models)          # pricing, payments, address, QR, summary, auth
  services/
    auth_service.dart          # Login, OTP verification, Profile retrieval
    order_service.dart         # Active status, Store arrival, Pickup, Completion
    payment_service.dart       # COD cash collection, Razorpay QR generation, polling
    dashboard_service.dart     # Summary statistics, cursor-paginated history
  state/
    auth_state.dart            # Handles sessions, countdowns, logouts
    online_state.dart          # Handles online/offline status, homepage earnings
    active_order_state.dart    # Coordinates state machine, sockets & polling
  screens/                     # All visual layouts (splash, auth, home, job, QR, etc.)
  widgets/                     # Shared UI components (status chips, overlays, etc.)
```

---

## ⚙️ Environment Configuration

The app base URL resolves dynamically via `--dart-define=ENV=<value>` builds:

| Flavor | Target Platform | Base URL | Socket URL |
| :--- | :--- | :--- | :--- |
| `dev` | Android Emulator | `http://10.0.2.2:5000/api/v1` | `http://10.0.2.2:5000` |
| `ios` | iOS Simulator | `http://localhost:5000/api/v1` | `http://localhost:5000` |
| `local` | Physical Device (LAN) | `http://192.168.1.100:5000/api/v1` | `http://192.168.1.100:5000` |
| `prod` | Production Server | `http://187.127.171.117/api/v1` | `http://187.127.171.117` |

> **Setup LAN IP**: If testing on a physical device in local dev mode, edit your PC's IP address in [lib/config/env.dart](file:///c:/Users/Asus/Documents/Dramsve%20Solutions/GKS%20Rider/lib/config/env.dart) on lines 20 and 35.

---

## 🚀 How to Run the Project

### Prerequisites
1. Ensure the Flutter SDK is installed and configured on your machine.
2. Confirm your target device/emulator is running and connected (`flutter devices`).

### Installation
Run this command from the project root to fetch dependencies:
```bash
flutter pub get
```

### Running the App
* **Start on Android Emulator (Default Dev):**
  ```bash
  flutter run
  ```

* **Start on iOS Simulator:**
  ```bash
  flutter run --dart-define=ENV=ios
  ```

* **Start on Physical Device (Local Wi-Fi):**
  ```bash
  flutter run --dart-define=ENV=local
  ```

* **Start pointing to Production Server (`187.127.171.117`):**
  ```bash
  flutter run --dart-define=ENV=prod
  ```

### Building the Production Release APK
Compile the optimized, tree-shaken, production-ready APK package:
```bash
flutter build apk --release --dart-define=ENV=prod
```
The compiled bundle will be saved to:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🔒 Platform Permissions

### Android (`AndroidManifest.xml`)
- `ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION` (GPS tracking)
- `INTERNET` (Network communication)
- `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_LOCATION` (Background coordinate streaming)
- `usesCleartextTraffic="true"` (Enabled for local `http` dev flavor builds)

### iOS (`Info.plist`)
- `NSLocationWhenInUseUsageDescription` (Foreground location tracking)
- `NSLocationAlwaysAndWhenInUseUsageDescription` (Background tracking during active delivery)
