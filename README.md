# 🛡️ Safety-Pal

### Distributed Women Safety Network

> Bridging the gap between fear and response through intelligent escalation, preventive awareness, and hardware-backed redundancy.

---

## 📌 Overview

Safety-Pal is a multi-layer women safety ecosystem designed to reduce emergency response delay and improve real-time intervention.

Unlike traditional panic button applications, Safety-Pal integrates:

* 🔴 Voice-based SOS with smart escalation
* 📞 Automated guardian voice calling agent
* 🗺 Verified Safe Zones & Risk Heatmap
* 📝 Admin-validated incident reporting
* 📟 Suraksha Netra hardware redundancy

The system consists of:

* 📱 Women Client Application
* 🖥 Admin Web Dashboard
* 📲 Shake Detection Module

---

## 🗂 Repository Structure

```
Safety-Pal/
│
├── women-safety/        # Flutter Client Application (Women)
├── safety-pal-admin/    # Admin Web Application
├── shake-detection/     # Shake Detection Feature Module
└── README.md
```

---

# 📱 women-safety

## Client Side Application (Women)

Flutter-based mobile application designed for real-time emergency support and preventive safety awareness.

---

## 🚀 Core Features

### 🔴 1. Voice SOS with Smart Escalation

* Shake or hold activation
* Records live audio
* Sends SMS and email with real-time location
* 10-second escalation timer
* Automatically triggers guardian voice call if not cancelled

---

### 📞 2. Automated Voice Calling Agent

* Server-triggered real-time call
* Speaks emergency message to guardians
* Reduces dependency on passive notifications

---

### 🗺 3. Nearest Safe Zones

* Displays verified safe locations (Police, Hospitals, NGOs)
* Map-based navigation
* Distance calculation

---

### 🔥 4. Risky Areas Heatmap

* Visual heatmap of high-risk zones
* Built from:

  * Approved incident reports
  * Existing crime datasets
* Real-time risk warning

---

### 📝 5. Incident Reporting

Users can submit reports with:

* Incident category
* Description
* Auto geotag
* Optional photo upload
* Severity level
* Anonymous option

All reports require admin approval before influencing heatmap.

---

### 🚨 6. One-Tap Emergency

* Direct call to emergency services
* Minimal friction design

---

### 👤 7. Guardian & Profile Management

* Add / remove guardians
* Privacy controls
* Permission management

---

### 📟 8. Suraksha Netra Integration

* Hardware status monitoring
* GPS & GSM connectivity indicators
* Device testing interface

---

## 🛠 Tech Stack (Client)

* Flutter
* Firebase Core
* Cloud Firestore
* Geolocator
* Telephony (SMS)
* Mailer (Email)
* Flutter Map

---

# 🖥 safety-pal-admin

## Admin Side Web Application

Web-based dashboard for monitoring, moderation, and safety intelligence management.

---

## 🎯 Purpose

Ensures:

* Data validation
* Incident moderation
* Safe zone management
* System reliability

---

## 🚀 Admin Features

### 📝 Incident Moderation

* View submitted reports
* Approve / reject incidents
* Categorize incidents
* Push approved incidents to heatmap dataset

---

### 🗺 Safe Zone Management

* Add / edit verified safe zones
* Manage zone categories

---

### 📊 Monitoring Dashboard

* View SOS logs
* Track active alerts
* Basic analytics

---

## 🛠 Tech Stack (Admin)

* Web Framework (React / Next.js / etc.)
* Firebase Authentication
* Firestore
* REST APIs

---

# 📲 shake-detection

## Shake Detection Feature Module

Dedicated motion-based trigger module for seamless SOS activation.

---

## 🎯 Purpose

Provides shake-to-trigger functionality for emergency activation.

---

## ⚙ Functionality

* Monitors device accelerometer
* Detects predefined shake threshold
* Prevents false positives
* Triggers Voice SOS workflow
* Supports cooldown logic

---

## 🔧 Implementation Concepts

* Sensor listeners
* Threshold filtering
* Motion smoothing
* Background execution support

---

# 📟 Suraksha Netra (Hardware Integration)

An independent hardware safety module designed for redundancy.

---

## 🔐 Capabilities

* GPS module
* GSM connectivity
* Microphone & camera
* Direct cloud communication
* Works without smartphone

Adds hardware-level safety in case of phone failure.

---

# 🧠 System Architecture Overview

```
Flutter Client (women-safety)
        ↓
Backend APIs
        ↓
Database
        ↑
Admin Dashboard (safety-pal-admin)
        ↑
Suraksha Netra Hardware
```

---


---

# 🚀 Getting Started

## 📱 Run Client App

```bash
cd women-safety
flutter pub get
flutter run
```

---

## 🖥 Run Admin App

```bash
cd safety-pal-admin
npm install
npm start
```

---

# 📌 Future Scope

* Wearable version of Suraksha Netra
* City-wide deployment
* Government API integrations
* Advanced predictive risk models

---

# 🤝 Contributors

Team Safety-Pal
Morpheus Hackathon Project – 2026

