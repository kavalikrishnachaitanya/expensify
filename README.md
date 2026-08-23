# 💳 Expensify & Splitwise

An all-in-one, privacy-first personal finance tracker and group bill-splitting application built with **Flutter**, **Firebase Cloud Firestore**, and **Google Drive API**.

---

## 🚀 Features

### 📊 Personal Expense & Income Management
- **Transactions & Categories**: Log daily income and expenses with customizable categories.
- **Savings Vault**: Track savings progress and manage financial goals.
- **Analytics & Filters**: Filter transactions by date range, category, or type.
- **Dark / Light Theme**: Dynamic Material 3 UI with dark mode support.

### ☁️ Private Google Drive Cloud Sync
- **Private Data Storage**: Personal transaction data is backed up directly to your own private Google Drive `appDataFolder` (`expenditure_backup.json`).
- **Zero Third-Party Storage**: Personal financial records never hit external servers.

### 👥 Splitwise Group Expense Sharing
- **Group Creation & Management**: Create groups for roommates, trips, or events.
- **Member Management**: Add group members via email, inspect member roles, or remove members (group creator).
- **Shared Expense Logging**: Add group expenses and specify payer and split participants.
- **Smart Debt Settlement**: Automated optimal settlement calculation using a greedy debt simplification algorithm.
- **Real-Time Synchronization**: Instant live updates across all group members using Cloud Firestore.

### 🔐 Unified Authentication & Profile
- **Single Sign-On (SSO)**: Seamless Google OAuth & Firebase Authentication.
- **Firestore Sync**: User profiles (display name, email, avatar) sync automatically across group screens.
- **Account Protection**: Built-in verification preventing account deletion if outstanding dues exist in any group.

---

## 🛠️ Tech Stack

| Component | Technology / Package |
|---|---|
| **Framework** | Flutter / Dart |
| **State Management** | Provider |
| **Authentication** | Firebase Auth & Google Sign-In (`google_sign_in`) |
| **Cloud Database** | Cloud Firestore (`cloud_firestore`) |
| **Personal Backup** | Google Drive API (`googleapis`) |
| **UI & Styling** | Material 3 Design & Google Fonts |

---

## 📁 Project Structure

```text
lib/
├── main.dart                   # App entry point, theme & route configuration
├── models.dart                 # Personal expense & category data models
├── settings_screen.dart        # Profile management & application settings
├── login_screen.dart           # Authentication & Google SSO screen
├── savings_vault_view.dart     # Savings goals & vault tracking
├── categories_screen.dart      # Custom category management
├── firebase_options.dart       # Firebase platform configuration
├── services/
│   └── google_drive_service.dart # Private Drive backup & sync service
└── splitwise/                  # Group bill-splitting module
    ├── models/                 # Group, Expense, & User models
    ├── providers/              # AuthProvider, GroupProvider, ExpenseProvider
    ├── screens/                # HomeScreen, GroupDetailScreen, CreateGroupScreen, AddExpenseScreen
    ├── services/               # FirestoreService & AuthService
    ├── utils/                  # Constants & formatting helpers
    └── widgets/                # GroupCard, ExpenseTile, SettlementCard, UserAvatar, BalanceSummary
```

---

## ⚙️ Setup & Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.12.2` or later)
- Android Studio / Xcode for device emulation
- Firebase project configured with Firestore & Authentication enabled
- Google Cloud OAuth 2.0 Credentials (for Google Sign-In and Drive API)

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/your-username/expensify.git
cd expensify
flutter pub get
```

### 2. Configure Environment Variables
Create a `.env` file in the root directory:
```env
WEB_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
IOS_CLIENT_ID=your_ios_client_id.apps.googleusercontent.com
```

### 3. Run the Application
```bash
flutter run
```

---

## 🔒 Security & Privacy

- **Personal Tracker Privacy**: Personal expenses are isolated in your personal Google Drive app folder.
- **Group Firestore Privacy**: Shared expense data is scoped strictly to group members via Firestore Security Rules.
