import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:safety_pal/providers/auth_provider.dart';
import 'package:safety_pal/screens/app_initializer.dart';
import 'package:safety_pal/screens/home/home_screen.dart';
import 'package:safety_pal/screens/map/risky_areas_map_screen.dart';
import 'package:safety_pal/screens/game/game_screen.dart';
import 'package:safety_pal/screens/map/safe_zone_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safety Pal',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AppInitializer(),
        routes: {
          '/safeZones': (context) => SafeZoneListScreen(),
          '/dangerZones': (context) => const RiskyAreasMapScreen(),
          '/kidsNavi': (context) => SafeNavigationApp(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}

