# Bible Study — iOS App (iPad)

SwiftUI app for iPad that looks up Bible passages and generates study notes using Apple Foundation Models (on-device AI).

## Requirements

| Requirement | Minimum |
|---|---|
| Xcode | 26 beta (for FoundationModels framework) |
| iPadOS | 26.0 |
| iPad chip | M1 or later (iPad Pro M1+, iPad Air M1+) |
| Apple Intelligence | Must be enabled in Settings > Apple Intelligence & Siri |

## Phase 1 (current)

- Type or dictate a Bible reference
- Fetches ESV text for short passages (≤5 verses)
- Apple Foundation Models generates:
  - **Context** — narrative background of the passage
  - **Applications** — 3 practical life applications

## Phase 2 (planned)

- TSK cross-references (local, no cost)
- Historical/cultural background via a local LLM
- Cross-reference explanations

---

## Xcode Setup

### 1. Create the project

1. Open Xcode 26
2. **File > New > Project > iOS > App**
3. Settings:
   - Product Name: `BibleStudy`
   - Bundle Identifier: `com.yourname.BibleStudy`
   - Interface: SwiftUI
   - Language: Swift
   - Uncheck "Include Tests" (optional)
4. **Save into** `ios/` inside this repo (so `ios/BibleStudy/` is created)

### 2. Set deployment target

- Select the project in the Navigator → **BibleStudy** target → **General**
- Set **Minimum Deployments** → **iOS 26.0**

### 3. Add source files

All Swift files are already in `ios/BibleStudy/`. In Xcode:

1. Right-click the `BibleStudy` group → **Add Files to "BibleStudy"**
2. Select all folders: `Models/`, `Services/`, `ViewModels/`, `Views/`, `Resources/`
3. Check **"Add to target: BibleStudy"**
4. Delete the default `ContentView.swift` Xcode created (we have our own)

### 4. Add shared data files

Copy the shared JSON files into `ios/BibleStudy/Resources/` and add them to the target:

```bash
cp shared/verse_counts.json ios/BibleStudy/Resources/
cp shared/book_aliases.json ios/BibleStudy/Resources/
```

Then in Xcode: right-click `Resources/` group → **Add Files** → select both JSON files, ensure they're added to the target.

### 5. Add capabilities

**BibleStudy target → Signing & Capabilities → + Capability:**

- Add **Speech Recognition**

Microphone access is controlled by Info.plist keys (no separate capability needed).

### 6. Info.plist keys

In the **Info** tab of the BibleStudy target, add:

| Key | Value |
|---|---|
| `NSMicrophoneUsageDescription` | BibleStudy uses the microphone to let you speak Bible references aloud. |
| `NSSpeechRecognitionUsageDescription` | BibleStudy uses speech recognition to transcribe spoken Bible references. |

### 7. Configure your ESV API key

```bash
cp ios/BibleStudy/Resources/Secrets.example.plist ios/BibleStudy/Resources/Secrets.plist
```

Edit `Secrets.plist` and replace `YOUR_ESV_API_KEY_HERE` with your key from [api.esv.org](https://api.esv.org).

`Secrets.plist` is gitignored — it will never be committed.

---

## Sideloading (no paid developer account)

You can install the app on your own iPad for free using Xcode's personal team provisioning. The certificate expires every **7 days** and needs to be renewed by re-running from Xcode.

### Steps

1. Connect your iPad to your Mac via USB
2. In Xcode, select your iPad as the run destination (top toolbar)
3. **BibleStudy target → Signing & Capabilities → Team** → select your personal Apple ID
   - Xcode will create a free provisioning profile automatically
4. Press **Run** (⌘R) — Xcode builds and installs the app
5. On your iPad: **Settings > General > VPN & Device Management** → find your Apple ID → tap **Trust**
6. Open the app

### Renewing after 7 days

Simply open the project in Xcode, connect your iPad, and press Run again. Xcode re-signs and reinstalls automatically.

### Alternative: AltStore

[AltStore](https://altstore.io) can refresh the app automatically every 7 days as long as AltServer is running on your Mac. The free tier supports up to 3 sideloaded apps.

---

## Architecture

```
ios/BibleStudy/
├── BibleStudyApp.swift          # @main entry
├── Models/
│   ├── BibleReference.swift     # Parser + verse counter (ported from Python)
│   ├── StudyNote.swift          # UI model + @Generable PassageAnalysis
│   └── AppError.swift           # Typed errors
├── Services/
│   ├── SecretsLoader.swift      # Reads Secrets.plist
│   ├── ESVService.swift         # ESV API HTTP client
│   ├── SpeechService.swift      # SFSpeechRecognizer wrapper
│   └── FoundationModelService.swift  # Apple on-device AI
├── ViewModels/
│   └── StudyViewModel.swift     # @Observable — orchestrates all services
├── Views/
│   ├── ContentView.swift        # NavigationSplitView root
│   ├── SidebarView.swift        # Input + mic button
│   ├── DetailView.swift         # Loading / error / study note router
│   └── StudyNoteView.swift      # Verse text, context, application cards
└── Resources/
    ├── verse_counts.json        # From shared/ — verse counts per chapter
    ├── book_aliases.json        # From shared/ — book name aliases
    ├── Secrets.plist            # Gitignored — your ESV API key
    └── Secrets.example.plist   # Committed template
```
