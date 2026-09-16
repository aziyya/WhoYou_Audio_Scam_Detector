# WhoYou - Real-Time Audio Scam Detection

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.x-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-Cloud-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

WhoYou is a mobile application designed to detect potential phone scams by converting speech into text and analyzing conversations using keyword matching and Natural Language Processing (NLP).

The application provides scam risk scores, alerts users to suspicious conversations, and allows users to report and check suspicious phone numbers.

## Features

### User Features

- Real-time speech-to-text scam detection
- Audio and video file analysis
- English and Malay language support
- Scam risk score and alert levels
- Haptic alerts for suspicious conversations
- Suspicious phone number search
- Community scam reporting
- Scam-related news and awareness
- Detection history
- User profile management

### Admin Features

- Manage scam detection keywords
- Assign risk weights to keywords
- Add, update, and delete keywords
- View reported numbers and user statistics
- Real-time keyword synchronization

## How It Works

```text
Audio Input
     ↓
Speech-to-Text
     ↓
Keyword Detection
     ↓
NLP Analysis
     ↓
Scam Score Calculation
     ↓
Risk Level & Alert
     ↓
Save Detection History
```

## Scam Scoring

The final scam score combines keyword detection and NLP analysis:

Final Score = (NLP Score × 0.6) + (Keyword Score × 0.4)

| Score   | Alert Level |
| ------- | ----------- |
| 0%      | Safe        |
| 1–29%   | Low         |
| 30–59%  | Medium      |
| 60–100% | High        |

## Disclaimer ##

WhoYou is a supplementary tool for scam detection and should not be used as the sole method for identifying fraudulent calls.
Users should verify suspicious calls through official channels and exercise caution before providing personal or financial information.
