# Safety Pal (women-safety)

A cross‑platform Flutter application built for a hackathon to help users
stay safe by maintaining trusted contacts, sending SOS alerts, and visualising
safe/risky zones on a map.  The code is structured into modular screens and
services to make it easy to maintain and extend.

## High‑level architecture

- **Screens** – organised under `lib/screens/` by feature: `auth`, `home`,
  `map`, `game`, `heatmap`.
- **Widgets** – reusable UI components under `lib/widgets`.
- **Services** – classes encapsulating platform logic and I/O under
  `lib/services` (permissions, SMS/email, user data).
- **Models / utils** – small helpers and extensions as needed.

## Features & corresponding packages / APIs

| Feature | Packages / APIs | Notes |
|---------|----------------|-------|
| **Authentication flow** (sign‑up, about you, add guardians) | `flutter/material` UI, `path_provider` for local JSON storage | Data is stored locally via `UserDataService`. No backend yet. |
| **Home page with SOS** | `permission_handler`, `geolocator`, `telephony`, `flutter_sound`, `mailer` | Permissions managed by `PermissionService`; pressing SOS records audio, sends SMS and email alerts via `SmsService`/`EmailService` using Gmail SMTP. |
| **Safe‑zone listing** | `http` + Overpass API for nearby hospitals/police/malls, `geolocator` for location | Displays top‑5 closest places; navigates using `NavigationScreen` which calls OSRM routing API and draws a polyline with `flutter_map` / `latlong2`. |
| **Risky‑areas heat‑map** | `http` calls to local Flask server, `flutter_map_heatmap` | Server reads `crime_dataset_1000.csv` and clusters data using Python (`scikit‑learn`, `pandas`). Flutter layer fetches `/area-risk` and plots weighted points. |
| **Real‑time navigation game** | Same map/location packages plus game logic | Single screen in `lib/screens/game/`; uses position stream to update route and collect power‑ups. |
| **Permissions helper** | `permission_handler`, `telephony`, `geolocator` | Encapsulated in `PermissionService` service. |

> **Note:** any database code was removed; the app currently keeps user data
> in local JSON files.  No Firebase or other backend is required for build.

## Packages (versions are in `pubspec.yaml`)

- `path_provider` ^2.0.11
- `flutter_sound` ^9.2.13
- `permission_handler` ^10.2.0
- `url_launcher` ^6.3.1
- `geolocator` ^9.0.2
- `google_fonts`, `google_maps_flutter`, `flutter_map`, `latlong2`,
  `flutter_map_heatmap`
- `mailer` ^6.0.1, `flutter_dotenv` ^5.2.1, `telephony` ^0.2.0

_(plus standard Flutter SDK packages)_

## Folder structure summary

```
lib/
  screens/
    auth/
      register_screen.dart
      about_user_screen.dart
      add_guardians_screen.dart
    home/
      home_screen.dart
    map/
      safe_zone_list_screen.dart    # list view
      navigation_screen.dart        # map + routing view
      risky_areas_map_screen.dart   # heat‑map view
    game/
      game_screen.dart              # wrapper with score
      real_time_navigation_game.dart
  services/
    permission_service.dart
    sms_service.dart
    email_service.dart
    user_data_service.dart
  widgets/
    buttons.dart
    auth_field.dart
    agreements.dart
    gender_button.dart
    ...
```

## Getting started

1.  `flutter pub get`
2.  `flutter run` (choose a device)

All features run without any backend; the only external HTTP calls are to
public map APIs and the local Flask server for heat‑map data.

