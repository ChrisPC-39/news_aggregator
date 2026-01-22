# News Aggregator (Romanian Edition)

A Flutter-based news aggregation platform inspired by Ground News, specifically tailored for the Romanian media landscape. This app provides users with a comprehensive view of news stories, highlighting different perspectives and source reliability.

## 🚀 Features

- **Multi-Source Aggregation**: Fetches news from various Romanian news outlets.
- **Story Grouping**: Groups similar articles from different sources into a single "story" to provide a balanced view.
- **Local Persistence**: Uses Hive for fast, offline access to previously loaded news.
- **Cloud Integration**: Powered by Firebase (Firestore) for real-time updates and backend services.
- **Dynamic Search**: Search for specific topics or keywords across multiple news sources.
- **Dark/Light Mode**: Full support for Material 3 design with a sleek dark theme.

## 🛠 Tech Stack

- **Frontend**: [Flutter](https://flutter.dev/) (Material 3)
- **Database (Local)**: [Hive](https://docs.hivedb.dev/)
- **Backend/Database (Cloud)**: [Firebase Firestore](https://firebase.google.com/docs/firestore)
- **Networking**: [Http](https://pub.dev/packages/http)
- **State Management**: (Add your state management here, e.g., Provider/Riverpod)
- **Utilities**: `intl`, `url_launcher`, `html`, `crypto`

## 📦 Getting Started

### Prerequisites

- Flutter SDK: `^3.7.0`
- Dart SDK
- Android Studio / VS Code
- A Firebase Project

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/news_aggregator.git
    cd news_aggregator
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Setup Environment Variables:**
    Create a `.env` file in the root directory and add your API keys:
    ```env
    NEWS_API_KEY=your_key_here
    ```

4.  **Firebase Setup:**
    - Initialize Firebase using the FlutterFire CLI:
      ```bash
      flutterfire configure
      ```
    - Ensure your Android SHA-1 fingerprint is added to the Firebase Console to avoid `DEVELOPER_ERROR` issues.

5.  **Run the app:**
    ```bash
    flutter run
    ```

## 📁 Project Structure

```text
lib/
├── models/       # Data models and Hive adapters
├── screens/      # UI Screens (News Results, Story Details, etc.)
├── services/     # API and Firebase service logic
├── widgets/      # Reusable UI components
├── globals.dart  # App-wide constants
└── main.dart     # Entry point and Firebase initialization
```

---

*Note: This project is a work in progress aiming to improve media literacy and transparency in the Romanian digital space.*
