<p align="center">
  <img src="logoapp.png" alt="PostX App Logo" width="180"/>
</p>

<h1 align="center">PostX App</h1>

<p align="center">
  <strong>Creation & Posting Efficiency</strong><br>
  <sub>One click. All platforms. No API keys needed.</sub>
</p>

<p align="center">
  <a href="https://github.com/xjanova/PostXapp/releases/latest"><img src="https://img.shields.io/github/v/release/xjanova/PostXapp?style=for-the-badge&color=DC2626&label=Download" alt="Latest Release"></a>
  <img src="https://img.shields.io/github/actions/workflow/status/xjanova/PostXapp/android-release.yml?style=for-the-badge&logo=github&label=Android%20Build" alt="Android Build">
  <img src="https://img.shields.io/github/license/xjanova/PostXapp?style=for-the-badge" alt="License">
</p>

---

## What is PostX?

PostX is a multi-platform auto-posting app that lets you publish text and images to **10 social media platforms** simultaneously with a single tap. No API keys, no developer accounts, no complex setup — just log in with your existing accounts and post.

### Supported Platforms

| Platform | Status | Platform | Status |
|:---------|:------:|:---------|:------:|
| Facebook | :white_check_mark: | Pinterest | :white_check_mark: |
| X (Twitter) | :white_check_mark: | Threads | :white_check_mark: |
| Instagram | :white_check_mark: | YouTube | :white_check_mark: |
| LinkedIn | :white_check_mark: | Bluesky | :white_check_mark: |
| TikTok | :white_check_mark: | Telegram | :white_check_mark: |

---

## Features

- **One-Click Multi-Post** — Write once, publish to all connected platforms instantly
- **Cookie-Based Auth** — Log in via embedded browser, no API keys or tokens required
- **Image Support** — Attach images from gallery or camera to your posts
- **Auto-Update** — App checks for new versions and updates itself from GitHub Releases
- **Post History** — Track all your posts with status, timestamps, and filters
- **Auto Retry** — Failed posts are automatically retried
- **Dark UI** — Crypto-trading inspired dark theme with red accents

---

## Download

### Android (APK)

1. Go to [**Releases**](https://github.com/xjanova/PostXapp/releases/latest)
2. Download `PostXApp-vX.X.X.apk`
3. Install on your Android device (allow "Install from unknown sources" if prompted)

> The app will notify you automatically when a new version is available.

### Desktop (Windows / macOS / Linux)

Desktop builds are also available in [Releases](https://github.com/xjanova/PostXapp/releases):
- **Windows** — `.exe` installer
- **macOS** — `.dmg` (Intel & Apple Silicon)
- **Linux** — `.AppImage`

---

## Screenshots

<p align="center">
  <sub>Coming soon</sub>
</p>

---

## Tech Stack

### Android (Primary)
| Component | Technology |
|:----------|:-----------|
| Framework | Flutter 3.38 + Dart 3.10 |
| WebView | flutter_inappwebview |
| Storage | shared_preferences |
| Media | image_picker |
| Updates | GitHub Releases API + open_filex |
| CI/CD | GitHub Actions |

### Desktop
| Component | Technology |
|:----------|:-----------|
| Framework | Electron + React 18 |
| Language | TypeScript |
| Styling | Tailwind CSS + Framer Motion |
| State | Zustand |
| Build | electron-vite (Vite 5) |
| Updates | electron-updater |
| CI/CD | GitHub Actions |

---

## How It Works

```
1. Connect    →  Log in to each platform via embedded browser
2. Compose    →  Write your post + attach an image
3. Select     →  Choose which platforms to post to (or select all)
4. Post       →  One tap — PostX handles the rest
```

PostX uses **browser automation** through embedded WebViews. When you log in, your session cookies are saved locally on your device. When you post, PostX opens each platform in a headless browser, navigates to the compose area, fills in your content, and submits — just like you would manually, but automated.

> **No data leaves your device** — all authentication and posting happens locally through the browser. PostX never collects or transmits your credentials.

---

## Building from Source

### Android

```bash
cd mobile
flutter pub get
flutter build apk --release
```

> Requires Flutter 3.38+ and Java 17

### Desktop

```bash
npm install
npm run build
```

> Requires Node.js 18+

---

## CI/CD

Builds are automated via GitHub Actions. Push a version tag to trigger:

```bash
git tag v1.2.0
git push origin v1.2.0
```

This automatically builds and uploads APK + AAB (Android) and installers (Desktop) to GitHub Releases.

---

## Project Structure

```
PostXapp/
├── mobile/                  # Flutter Android app (primary)
│   ├── lib/
│   │   ├── main.dart        # App entry point
│   │   ├── models/          # Platform configs, post models
│   │   ├── pages/           # Dashboard, Compose, Accounts, History, Settings
│   │   ├── services/        # Storage, automation, auto-update
│   │   ├── theme/           # Crypto-dark theme
│   │   └── widgets/         # Glass cards, platform icons
│   └── android/             # Android native config
├── electron/                # Desktop Electron main process
├── src/                     # Desktop React renderer
├── .github/workflows/       # CI/CD pipelines
└── logoapp.png              # App logo
```

---

<p align="center">
  <sub>Built with by <strong>xman studio</strong></sub><br>
  <sub>Licensed by xman studio</sub>
</p>
