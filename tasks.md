# CartBuddy Frontend Implementation Tasks

## Phase 1: Setup and Dependencies
- [ ] Initialize standard Flutter project structure (clean up default boilerplate in `main.dart`).
- [ ] Update `pubspec.yaml` with necessary dependencies:
  - **State Management**: `flutter_riverpod`, `riverpod_annotation`
  - **Networking**: `dio`
  - **WebSockets**: `web_socket_channel`
  - **Routing**: `go_router`
  - **UI Library**: `forui` (and its required assets/icons)
  - **Payments**: `razorpay_flutter`
  - **Storage/Auth**: `flutter_secure_storage`, `shared_preferences`
- [ ] Run `flutter pub get` to install all dependencies.
- [ ] Setup `assets` folder for images/icons and declare them in `pubspec.yaml`.

## Phase 2: Core Architecture Setup
- [ ] Create folder structure (`lib/core`, `lib/features`, `lib/shared`).
- [ ] **Routing setup:** 
  - [ ] Initialize `GoRouter` instance in a dedicated routing file (`lib/core/router/app_router.dart`).
  - [ ] Define route paths for Login, Home, Create Order, Order Room, Profile, etc.
- [ ] **State Management setup:** 
  - [ ] Wrap `runApp` with `ProviderScope`.
  - [ ] Setup initial authentication provider to check user login status on app start.
- [ ] **Networking core:**
  - [ ] Create a `Dio` client instance.
  - [ ] Setup Dio interceptors for auth tokens and logging.
  - [ ] Create base API service class.
- [ ] **UI Theme setup:**
  - [ ] Configure `Forui` theme in `MaterialApp.router`.
  - [ ] Define global text styles, colors, and constants matching `Forui` design guidelines.

## Phase 3: UI Development (Screens & Components)
- [ ] **Authentication:**
  - [ ] Build Login screen UI.
  - [ ] Build Registration/Sign-up screen UI.
- [ ] **Dashboard / Home:**
  - [ ] Build main layout (bottom navigation or side drawer).
  - [ ] Build "Location-Based Discovery" feed UI (list of active nearby orders).
- [ ] **Order Management:**
  - [ ] Build "Create an Order" form screen (location, time, max participants).
  - [ ] Build "Order Room" UI (real-time chat interface, participants list, status tracker).
- [ ] **User Profile & History:**
  - [ ] Build Profile screen UI.
  - [ ] Build Previous Orders screen UI.
  - [ ] Build Balance & Transactions screen UI.
- [ ] **Order Handover (OTP):**
  - [ ] Build OTP Display component (for Joiners).
  - [ ] Build OTP Input/Scanner component (for Creators).

## Phase 4: Backend Integration & Logic
- [ ] Connect Authentication APIs (Login/Register calls).
- [ ] Connect Dashboard API to fetch live nearby orders.
- [ ] Connect "Create Order" API and test order room creation.
- [ ] **WebSocket Integration:**
  - [ ] Connect `web_socket_channel` to the Order Room for real-time chat.
  - [ ] Listen to real-time status updates (e.g., "Order Placed", "Out for Delivery", "Arrived").
- [ ] **Payment Integration:**
  - [ ] Implement Razorpay SDK flow on joining an order.
- [ ] Implement OTP verification API call for order handover and payout trigger.

## Phase 5: Final Packaging & Polish
- [ ] Conduct end-to-end flow testing (Auth -> Create/Join -> Pay -> Handover -> Payout).
- [ ] Ensure loading states, error states, and empty states are handled gracefully.
- [ ] Finalize app icon and splash screen.
- [ ] Configure iOS and Android specific settings (permissions, Razorpay API keys, deep links).
- [ ] Build release versions for testing (APK / IPA).
