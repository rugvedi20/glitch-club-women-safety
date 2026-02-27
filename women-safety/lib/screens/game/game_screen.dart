import 'package:flutter/material.dart';
import 'package:safety_pal/screens/game/real_time_navigation_game.dart';

class SafeNavigationApp extends StatelessWidget {
  const SafeNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe Navigation Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  int _score = 0;

  void _updateScore(int newScore) {
    setState(() {
      _score = newScore;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Navigation Adventure'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.star),
                const SizedBox(width: 4),
                Text(
                  '$_score',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RealTimeNavigationGame(
        onScoreUpdate: _updateScore,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show game instructions
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('How to Play'),
                content: const SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎮 Game Objectives:'),
                      Text('• Move towards the green safe zone marker'),
                      Text('• Collect power-ups along the way'),
                      SizedBox(height: 16),
                      Text('⭐ Power-ups:'),
                      Text('• Yellow stars: Points (+10)'),
                      Text('• Purple stars: Speed boost (+15)'),
                      Text('• Blue stars: Shield (+20)'),
                      SizedBox(height: 16),
                      Text('🎯 Winning:'),
                      Text('• Reach the safe zone'),
                      Text('• Collect as many power-ups as possible'),
                      Text('• Get bonus points for quick completion!'),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Got it!'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.help_outline),
      ),
    );
  }
}
