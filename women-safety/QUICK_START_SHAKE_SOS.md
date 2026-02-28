# Quick Integration Guide - SOS Shake Detection

## 🚀 Quick Start in 3 Steps

### Step 1: Add Provider to main.dart
```dart
import 'package:safety_pal/providers/shake_sos_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {}
  
  await Supabase.initialize(
    url: 'https://dmskjlxwhqljetgpljiq.supabase.co',
    anonKey: 'sb_publishable_m1_szeEAgg9Edk5QTT5x7g_liP9worm',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShakeSOSProvider()),  // ← ADD THIS
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safety Pal',
        theme: ThemeData(
          // ... your theme
        ),
        home: const AppInitializer(),
      ),
    );
  }
}
```

### Step 2: Add Widget to Your Home/Main Screen
```dart
import 'package:safety_pal/widgets/shake_sos_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeShakeDetection();
  }

  void _initializeShakeDetection() {
    // Get your existing SOS trigger method reference
    final provider = context.read<ShakeSOSProvider>();
    
    provider.updateSOSCallback(() async {
      // Call your existing SOS implementation here
      await _triggerSOS();
    });
  }

  Future<void> _triggerSOS() async {
    // Your existing SOS code here
    debugPrint('SOS triggered by shake detection!');
    // Example:
    // await sendSOSAlert();
    // await notifyEmergencyContacts();
    // await recordLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Pal'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Your existing widgets...
            
            // Add the SOS Widget (can go anywhere in the layout)
            ShakeSOSWidget(
              onSOSTriggered: _triggerSOS,
            ),
            
            // Rest of your widgets...
          ],
        ),
      ),
    );
  }
}
```

### Step 3: (Optional) Run `flutter pub get`
```gradle
cd d:\2026\Women Safety 2.0
flutter pub get
```

## 🎯 What This Gives You

✅ **Foreground Service** - Runs even when app is closed  
✅ **Persistent Notification** - Shows detection status  
✅ **Automatic Shake Detection** - Always monitoring once enabled  
✅ **Easy Integration** - Just add the widget or use programmatically  
✅ **Callback Support** - Execute your SOS flow when shake detected  
✅ **Status Management** - Track active/inactive state  

## 📱 User Experience

1. User sees "SOS Shake Detection" card on home screen
2. Can toggle detection ON/OFF with button
3. When ON, persistent notification shows (can't swipe away)
4. When phone is shaken, SOS flow automatically triggers
5. Works even if app is closed or in background

## 🔧 Advanced Usage (Optional)

### Programmatic Control
```dart
// In any widget/screen with context
final provider = context.read<ShakeSOSProvider>();

// Enable with custom callback
await provider.enableShakeDetection(() async {
  print('Custom shake handling');
});

// Disable
await provider.disableShakeDetection();

// Check status
bool isActive = provider.isShakeDetectionActive;

// Update callback later
provider.updateSOSCallback(() async {
  print('New callback');
});
```

### Listen to Status Changes
```dart
// In build method with Consumer
Consumer<ShakeSOSProvider>(
  builder: (context, provider, child) {
    if (provider.isShakeDetectionActive) {
      return Text('Detection Active');
    } else {
      return Text('Detection Inactive');
    }
  },
)
```

## ⚙️ Customization

### Change Detection Sensitivity
Edit `ShakeSensorListener.java`:
```java
// More sensitive: smaller threshold
private static final float SHAKE_THRESHOLD = 15f;

// Less sensitive: larger threshold  
private static final float SHAKE_THRESHOLD = 35f;
```

### Customize Notification Text
Edit `ShakeDetectionService.java`:
```java
.setContentTitle("Your App - SOS Active")
.setContentText("Your custom message here")
```

### Customize Widget UI
Edit `ShakeSOSWidget.dart` - colors, labels, icons, etc.

## ❓ Common Issues

### "Permission denied" error
- App asks for SENSORS permission on first start
- User needs to grant it in Settings → Permissions

### "Shake detection not working"
- Check if device is being held firmly (not too loose)
- Increase sensitivity by lowering SHAKE_THRESHOLD
- Ensure sensor permission is granted

### "Too many false positives"
- Increase SHAKE_THRESHOLD for less sensitivity
- Increase MIN_SHAKE_COUNT to require more shakes
- Increase SHAKE_WINDOW_TIME_MS to allow more time

## 📋 Checklist Before Deployment

- [ ] Added ShakeSOSProvider to MultiProvider in main.dart
- [ ] Added ShakeSOSWidget or programmatic control to screen
- [ ] Updated AndroidManifest.xml (already done, but verify)
- [ ] Tested on real Android device
- [ ] Tested permissions flow
- [ ] Verified SOS callback is called correctly
- [ ] Customized notification text (optional)
- [ ] Customized sensitivity (optional)
- [ ] Tested with app closed and in background

## 📚 Documentation Files

- `SOS_SHAKE_DETECTION_GUIDE.md` - Full technical documentation
- `ShakeSensorListener.java` - Accelerometer monitoring logic
- `ShakeDetectionService.java` - Foreground service implementation
- `MainActivity.kt` - Android-Flutter communication
- `shake_sos_service.dart` - Flutter service layer
- `shake_sos_provider.dart` - State management
- `shake_sos_widget.dart` - Ready-to-use UI component

## 🆘 Need Help?

1. Check logcat for errors:
   ```
   adb logcat | grep -i "shake\|safety"
   ```

2. Review the full guide: `SOS_SHAKE_DETECTION_GUIDE.md`

3. Check widget implementation in `shake_sos_widget.dart`

4. Verify native code in:
   - `ShakeDetectionService.java`
   - `ShakeSensorListener.java`
   - `MainActivity.kt`

That's it! 🎉 Your app now has professional-grade shake detection SOS.
