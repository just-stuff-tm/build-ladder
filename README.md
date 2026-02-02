# 🪜 Build Ladder

<!-- Badges -->
![Status](https://img.shields.io/badge/status-alpha-orange)
![Platform](https://img.shields.io/badge/platform-Termux%20(Android)-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Usage](https://img.shields.io/badge/usage-APK%20Builder-purple)

**Build Ladder** is a **Termux-first, interactive Android APK builder** that lets you incrementally create, fix, and refine an Android app using guided steps — with optional Automatic AI assistance.

It is designed for:
- Building Android apps **directly on-device** (no PC required)
- Iterative development via small, safe “patch” steps
- Recovering automatically from build failures
- Users who want *control*, not opaque magic

**Status:** Alpha (Termux tested)

---

## ✨ Key Features

- ✅ End-to-end Android APK builds in Termux  
- 🧩 Step-by-step patch system (incremental & rollback-safe)
- 🔁 Automatic rollback on failed patches
- 🩺 `build-ladder doctor` environment diagnostics
- 🤖 Optional autonomous AI patch generation (local LLM supported)
- 🧱 Hardened for Termux (native `aapt2`, SDK fixes)
- ♻️ Self-updating runtime (`build-ladder update`)
- 🙏 Voluntary donations only (no paywalls)

---

## 📦 Requirements

- Android device
- **Termux** (from F-Droid — *recommended source*) - https://f-droid.org/packages/com.termux/
- ~6–8 GB free storage (Android SDK + Gradle)
- Internet access (initial setup only)

---

## 🚀 Installation

```bash
pkg install git -y
git clone https://github.com/just-stuff-tm/build-ladder.git
cd build-ladder
bash installer/install.sh
```

Verify install:

```bash
build-ladder doctor
```

Expected output: all green checkmarks ✅

---

## 🛠 Basic Usage

Start (or continue) building an app:

```bash
build-ladder
```

You will be guided through:
1. App metadata (name, goal, package)
2. Incremental patch steps
3. Automatic builds after each step
4. Safe rollback on failure

Each step asks:

```
What is still wrong / missing?
```

You respond with **intent**, not boilerplate — unless you want to write code.

---

## 🧠 AI Mode (Optional)

Build Ladder can drive itself using a **local AI model** (for example via Ollama).

Example:

```bash
export AI_MODE=auto
export AI_ENDPOINT=http://127.0.0.1:11434/api/generate
export AI_MODEL=deepseek-coder:6.7b
build-ladder
```

AI mode will:
- Read project metadata
- Inspect the last Gradle failure
- Generate patch scripts automatically
- Retry safely with rollback protection

> ⚠️ Cloud AI is NOT bundled.  
> You fully control the endpoint and model.

---

## 🩺 Diagnostics

Run anytime:

```bash
build-ladder doctor
```

Checks:
- Java
- Gradle
- aapt2 (native Termux)
- Android SDK

---

## 🔄 Updating

Build Ladder updates itself from GitHub:

```bash
build-ladder update
```

This refreshes all runtime scripts in:
```
~/.build-ladder/bin/
```

---

## 📁 Project Layout

```
~/projects/current/
├── app/                 # Android application
├── scripts/patches/     # Incremental patch steps
├── .build-ladder.json   # Project metadata
├── gradle.properties
└── local.properties
```

---

## 🙏 Support & Donations (Optional)

Build Ladder is **free and open source**.

If it saved you time or frustration, voluntary support is appreciated:

- **CashApp:** `$yuptm`

No ads.  
No tracking.  
No locked features.

---

## 🏷️ Tags

`#android` `#termux` `#apk-builder` `#mobile-dev` `#cli-tools` `#open-source`

---

## 📜 License

MIT License

---

## 🤝 Credits

- Built and maintained by **just-stuff-tm**
- Powered by:
  - Termux: https://termux.dev
  - Android SDK & Gradle
  - Open-source tooling

---

## ⚠️ Notes

- Alpha quality — expect rough edges
- Termux is the **primary supported environment**
- Desktop Linux/macOS are untested
- Android Studio integration is **not a goal**
