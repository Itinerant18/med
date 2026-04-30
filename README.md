# MediFlow 🏥

**A Skeuomorphic Medical Management Platform**

MediFlow is a role-based healthcare management application built with Flutter, designed to streamline patient data management, inter-team communication, and clinical workflows. The platform uses a three-tier role system to ensure secure, organized, and efficient healthcare operations.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Role-Based Access Control](#role-based-access-control)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Development Guidelines](#development-guidelines)
- [Design System](#design-system)
- [Database & Backend](#database--backend)
- [Security](#security)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [Support](#support)

---

## 🎯 Overview

MediFlow is a comprehensive healthcare management system that bridges the gap between patients, medical professionals, and healthcare administrators. It provides a unified platform where:

- **Head Doctors** manage user approvals and maintain oversight
- **Doctors** review patient data and assign clinical follow-ups
- **Agents** handle patient data entry and task management

The application features a **skeuomorphic design** with organic shapes, natural colors, and a warm, human-centered interface that brings familiarity and trust to healthcare management.

---

## ✨ Key Features

### 🔐 Multi-Role System
- **Three distinct user roles** with clearly defined permissions
- **Pending approval workflow** for all new registrations
- **Role-based access control (RBAC)** enforced at every level

### 👥 Head Doctor (Administrator)
- Approval dashboard for new Doctor and Agent registrations
- Real-time registration alerts
- User management console (activate/deactivate accounts)
- Full access to Doctor features
- Comprehensive audit logging

### 🩺 Doctor (Clinical Professional)
- Unified dashboard for patient data access
- Full patient database search and management
- Medical record management with clinical notes
- Follow-up task assignment to Agents
- Patient record finalization capabilities

### 🧑‍💼 Agent (Data Entry)
- Private patient view (only their uploaded records)
- Structured patient data entry portal
- Follow-up task inbox with status management
- Task completion tracking (In Progress / Completed)
- Real-time notification system

### 🌍 Platform-Wide Capabilities
- **Role-Based Access Control**: Every user sees only permitted data
- **Patient Ownership Tracking**: Permanent attribution to uploading Agent
- **Smart Notification Routing**: Alerts delivered to correct recipients
- **Real-Time Updates**: Live task status and notifications
- **Offline Support**: Connectivity awareness and offline mode
- **Push Notifications**: Firebase Cloud Messaging integration

---

## 🏗️ Architecture

### Frontend
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Routing**: GoRouter for navigation
- **UI Components**: Custom skeuomorphic design system

### Backend & Services
- **Authentication**: Firebase Auth + Supabase
- **Database**: Supabase PostgreSQL
- **Cloud Functions**: Supabase Edge Functions
- **Messaging**: Firebase Cloud Messaging (FCM)
- **Notifications**: flutter_local_notifications

### Key Architectural Patterns
- **Provider Pattern**: Riverpod for state management
- **Repository Pattern**: Separation of data access logic
- **Clean Architecture**: Clear separation of concerns
- **MVVM**: Model-View-ViewModel for UI layers

---

## 🔐 Role-Based Access Control

### Access Matrix

| Feature | Head Doctor | Doctor | Agent |
|---------|:-----------:|:------:|:-----:|
| Approve Registrations | ✅ | ❌ | ❌ |
| View All Patients | ✅ | ✅ | ❌ |
| View Own Patients | ✅ | ✅ | ✅ |
| Add Clinical Notes | ✅ | ✅ | ❌ |
| Assign Follow-Up Tasks | ✅ | ✅ | ❌ |
| Receive Follow-Up Tasks | ❌ | ❌ | ✅ |
| Upload Patient Data | ❌ | ❌ | ✅ |
| Deactivate Users | ✅ | ❌ | ❌ |
| View Registration Alerts | ✅ | ❌ | ❌ |

For detailed role specifications, see [user_roles_permissions.md](user_roles_permissions.md) and [feature-list-implementation-plan.md](feature-list-implementation-plan.md).

---

## 💻 Tech Stack

### Mobile & Frontend
```
Flutter/Dart 3.2.0+
├── flutter_riverpod: ^2.5.1        (State management)
├── go_router: ^13.2.0              (Navigation)
├── image_picker: ^1.2.1            (Image selection)
├── cached_network_image: ^3.3.1    (Image caching)
└── google_fonts: ^6.2.1            (Typography)
```

### Backend Services
```
Supabase
├── PostgreSQL Database
└── Edge Functions (Deno)

Firebase
├── Firebase Auth
├── Firebase Messaging (FCM)
└── Cloud Functions
```

### Notifications & Connectivity
```
├── firebase_core: ^3.6.0
├── firebase_auth: ^5.3.0
├── firebase_messaging: ^15.1.3
├── flutter_local_notifications: ^17.1.2
├── connectivity_plus: ^6.0.3
└── permission_handler: ^12.0.1
```

### UI & Design
```
├── google_fonts: ^6.2.1
├── font_awesome_flutter: ^10.7.0
├── fl_chart: ^0.69.0
└── Custom Skeuomorphic Design System
```

### Utilities
```
├── http: ^1.2.0                (HTTP client for Edge Functions)
├── share_plus: ^12.0.2         (Share functionality)
├── url_launcher: ^6.3.2        (Deep linking)
└── intl: ^0.19.0               (Internationalization)
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.2.0+)
- Dart SDK (included with Flutter)
- XCode (for iOS development)
- Android Studio (for Android development)
- Git

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/Itinerant18/med.git
cd med
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure environment variables**

Create a `.env.local` file in the root directory with your configuration:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
FIREBASE_PROJECT_ID=your_firebase_project_id
# Additional configuration as needed
```

4. **Setup Firebase** (for iOS and Android)

For iOS:
```bash
cd ios
pod install
cd ..
```

Run FlutterFire CLI:
```bash
flutterfire configure
```

5. **Run the application**

```bash
# Development
flutter run

# Specific platform
flutter run -d ios        # iOS device/simulator
flutter run -d android    # Android device/emulator
```

### Initial Setup Checklist
- [ ] Flutter SDK installed and in PATH
- [ ] Firebase project created and configured
- [ ] Supabase project created and credentials obtained
- [ ] `.env.local` configured with API keys
- [ ] FlutterFire configured for your platform
- [ ] Emulator/physical device available
- [ ] Dependencies installed (`flutter pub get`)

---

## 📁 Project Structure

```
med/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── core/
│   │   ├── app_config.dart       # Configuration management
│   │   ├── router.dart           # GoRouter setup
│   │   ├── theme.dart            # Theme definitions
│   │   ├── fcm_service.dart      # Firebase messaging
│   │   ├── notification_service.dart
│   │   └── connectivity_wrapper.dart
│   ├── features/
│   │   ├── auth/                 # Authentication flows
│   │   ├── head_doctor/          # Admin dashboard
│   │   ├── doctor/               # Doctor features
│   │   ├── agent/                # Agent features
│   │   └── shared/               # Common components
│   └── models/                   # Data models
├── test/
│   └── widget_test.dart          # Widget tests
├── ios/                          # iOS native code
├── android/                      # Android native code
├── web/                          # Web platform support
├── pubspec.yaml                  # Dependencies
├── pubspec.lock                  # Locked versions
├── firebase.json                 # Firebase config
└── analysis_options.yaml         # Dart analysis rules
```

---

## 🛠️ Development Guidelines

### Code Style & Standards
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Keep functions small and focused
- Document public APIs with dartdoc comments

### File Organization
- **Models**: Define data structures
- **Services**: Handle business logic and API calls
- **Providers**: Riverpod state management
- **Widgets**: UI components

### Naming Conventions
- Classes: PascalCase (`UserModel`, `AuthService`)
- Variables/Functions: camelCase (`currentUser`, `fetchPatients()`)
- Constants: camelCase with const keyword (`const maxRetries = 3`)
- Files: snake_case (`user_model.dart`, `auth_service.dart`)

### Best Practices
1. **State Management**: Use Riverpod providers for all state
2. **Error Handling**: Implement comprehensive try-catch blocks
3. **Async Operations**: Use async/await, avoid callback chains
4. **Widget Rebuilds**: Leverage Riverpod's selector to prevent unnecessary rebuilds
5. **Performance**: Use const constructors and cache images

### Example Provider Structure
```dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(supabaseProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  // Implementation
}
```

---

## 🎨 Design System

MediFlow implements a **skeuomorphic design system** emphasizing warmth, natural forms, and human connection.

### Design Philosophy
- **Core Signature**: Soft, amorphous blob shapes with organic border radii
- **Texture**: Paper-like quality with subtle grain overlay (3-4% opacity)
- **Color Palette**: Earth-inspired palette (moss green, terracotta, stone)
- **Shadow Philosophy**: Soft, diffused shadows with natural color tints
- **Typography**: Fraunces serif (headings) + Nunito (body)

### Color Palette (Light Mode)
```dart
// Core Colors
const background = Color(0xFFFDFCF8);        // Off-white, Rice Paper
const foreground = Color(0xFF2C2C24);        // Deep Loam
const primary = Color(0xFF5D7052);           // Moss Green
const secondary = Color(0xFFC18C5D);         // Terracotta
const accent = Color(0xFFE6DCCD);            // Sand/Beige
const destructive = Color(0xFFA85448);       // Burnt Sienna
```

### Component Styling
- **Buttons**: Fully rounded pills with moss green primary style
- **Cards**: Rounded containers with soft shadows and grain texture
- **Inputs**: Pill-shaped with semi-transparent backgrounds
- **Navigation**: Sticky floating pill with glassmorphism effect

### Design Resources
- Full design system documentation: [DESIGNE.md](DESIGNE.md)
- Color specs, typography, spacing, shadows, animations, icons, accessibility

### Responsive Strategy
- **Mobile-first**: Base styles optimized for mobile
- **Breakpoints**: sm (640px), md (768px), lg (1024px)
- **Layout**: Single column on mobile, multi-column at larger breakpoints
- **Text Scaling**: Responsive typography adjustments

---

## 🗄️ Database & Backend

### Supabase PostgreSQL Schema

Key tables structure:
- **users**: User accounts with role assignments
- **patients**: Patient records with ownership tracking
- **medical_records**: Clinical notes and patient data
- **follow_up_tasks**: Task assignments and tracking
- **audit_logs**: Activity tracking for compliance

### Authentication Flow
1. User self-registers (Doctor or Agent)
2. Account created in **"Pending"** state
3. Head Doctor reviews in Approval Dashboard
4. Head Doctor approves → Account activated
5. User gains role-specific access

### Real-Time Features
- Supabase Realtime subscriptions for live updates
- FCM for push notifications
- Local notifications for critical alerts

### API Integration
- Edge Functions for custom server logic
- HTTP client for REST API calls
- Automatic retry logic for failed requests

---

## 🔒 Security

### Authentication & Authorization
- **Firebase Auth**: Secure user authentication
- **Role-Based Access Control**: Fine-grained permission system
- **JWT Tokens**: Secure API authentication
- **Session Management**: Automatic session validation

### Data Protection
- **HIPAA Compliance**: Healthcare data privacy standards
- **Encryption**: Data encrypted in transit and at rest
- **Audit Logging**: All actions logged for compliance
- **Data Privacy Rules**: Applied to all user roles

### Security Best Practices
1. Never commit API keys or secrets
2. Use environment variables for sensitive data
3. Validate all user inputs
4. Implement rate limiting on API calls
5. Regular security audits and updates

### Sensitive Data Handling
```dart
// ✅ Good: Use environment variables
final apiKey = AppConfig.supabaseAnonKey;

// ❌ Avoid: Hardcoding secrets
final apiKey = 'sk_live_...';
```

---

## ✅ Testing

### Running Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/widget_test.dart

# With coverage
flutter test --coverage
```

### Test Structure
- **Widget Tests**: UI component behavior
- **Unit Tests**: Business logic and utilities
- **Integration Tests**: End-to-end user flows

### Example Test
```dart
void main() {
  group('Authentication', () {
    test('User login with valid credentials', () async {
      // Arrange
      final auth = AuthService();
      
      // Act
      final result = await auth.login('user@example.com', 'password');
      
      // Assert
      expect(result, isNotNull);
    });
  });
}
```

---

## 🚢 Deployment

### iOS Deployment

1. **Update version**
```bash
# Update in pubspec.yaml
version: 1.0.1+2
```

2. **Create build**
```bash
flutter build ios --release
```

3. **Submit to App Store**
   - Use Xcode or Transporter
   - Requires Apple Developer Account

### Android Deployment

1. **Generate signing key**
```bash
keytool -genkey -v -keystore ~/key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

2. **Configure signing in android/app/build.gradle**

3. **Build APK/AAB**
```bash
flutter build apk --release
flutter build appbundle --release
```

4. **Upload to Google Play Store**

### Web Deployment

```bash
flutter build web --release
# Deploy build/web/ to your hosting service
```

### Environment-Specific Configuration
```dart
// Using flavor-specific configurations
enum Flavor { development, staging, production }

class AppConfig {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'development');
  
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```

---

## 📝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
```bash
git clone https://github.com/yourusername/med.git
cd med
```

2. **Create a feature branch**
```bash
git checkout -b feature/your-feature-name
```

3. **Make your changes**
   - Follow code style guidelines
   - Write tests for new functionality
   - Update documentation as needed

4. **Commit with clear messages**
```bash
git commit -m "feat: Add patient follow-up notifications"
```

5. **Push to your fork**
```bash
git push origin feature/your-feature-name
```

6. **Open a Pull Request**
   - Describe your changes clearly
   - Reference related issues
   - Request review from maintainers

### Commit Message Format
```
<type>(<scope>): <subject>

<body>

Closes #<issue-number>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## 📚 Documentation

- **[User Roles & Permissions](user_roles_permissions.md)** - Detailed role specifications
- **[Feature Implementation Plan](feature-list-implementation-plan.md)** - User flows and feature matrix
- **[Design System](DESIGNE.md)** - Complete design specifications
- **[Security Guidelines](SECURITY.md)** - Security policies and best practices

---

## 🤝 Support

### Getting Help
- **Documentation**: Review project documentation files
- **Issues**: Check GitHub Issues for similar problems
- **Discussions**: Use GitHub Discussions for questions
- **Community**: Connect with other developers

### Reporting Bugs
1. Check if issue already exists
2. Provide detailed reproduction steps
3. Include error messages and logs
4. Specify device and Flutter version
5. Attach screenshots if UI-related

### Feature Requests
1. Describe the feature clearly
2. Explain the use case
3. Suggest implementation approach
4. Reference related issues

---

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

---

## 👨‍💻 Authors

**Developed by**: Itinerant18

**Repository**: [Itinerant18/med](https://github.com/Itinerant18/med)

---

## 🎯 Roadmap

### Current Version (1.0.0)
- [x] Three-tier role system
- [x] Patient data management
- [x] Follow-up task system
- [x] Push notifications
- [x] Skeuomorphic design

### Planned Features
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] Voice-to-text patient notes
- [ ] Prescription management
- [ ] Appointment scheduling integration
- [ ] Video consultation capabilities
- [ ] Mobile offline mode enhancement

---

## 🔗 Quick Links

- **GitHub Repository**: https://github.com/Itinerant18/med
- **Issue Tracker**: https://github.com/Itinerant18/med/issues
- **Discussions**: https://github.com/Itinerant18/med/discussions
- **Flutter Documentation**: https://flutter.dev
- **Supabase Documentation**: https://supabase.com/docs
- **Firebase Documentation**: https://firebase.google.com/docs

---

**Last Updated**: April 25, 2026  
**Version**: 1.0.3

For questions or updates, please open an issue or discussion on GitHub.
Auto commit 1 - 2026-04-30 16:26:55
Auto commit 2 - 2026-04-30 16:26:55
Auto commit 3 - 2026-04-30 16:26:55
Auto commit 4 - 2026-04-30 16:26:56
Auto commit 5 - 2026-04-30 16:26:56
Auto commit 6 - 2026-04-30 16:26:56
Auto commit 7 - 2026-04-30 16:26:56
Auto commit 8 - 2026-04-30 16:26:56
Auto commit 9 - 2026-04-30 16:26:56
Auto commit 10 - 2026-04-30 16:26:56
Auto commit 11 - 2026-04-30 16:26:56
Auto commit 12 - 2026-04-30 16:26:56
Auto commit 13 - 2026-04-30 16:26:57
Auto commit 14 - 2026-04-30 16:26:57
Auto commit 15 - 2026-04-30 16:26:57
Auto commit 16 - 2026-04-30 16:26:57
Auto commit 17 - 2026-04-30 16:26:57
Auto commit 18 - 2026-04-30 16:26:57
Auto commit 19 - 2026-04-30 16:26:57
Auto commit 20 - 2026-04-30 16:26:57
Auto commit 21 - 2026-04-30 16:26:57
Auto commit 22 - 2026-04-30 16:26:58
