import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Feature Selector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FeatureSelectionPage(),
    );
  }
}

class FeatureSelectionPage extends StatelessWidget {
  const FeatureSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Feature'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // 운행 점수 매기기 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScoringPage(),
                  ),
                );
              },
              child: const Text('운행 점수 매기기'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 서포터즈 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SupporterPage(),
                  ),
                );
              },
              child: const Text('서포터즈'),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoringPage extends StatelessWidget {
  const ScoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운행 점수 매기기'),
      ),
      body: const Center(
        child: Text(
          '운행 점수 매기기 기능 실행 중...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class SupporterPage extends StatelessWidget {
  const SupporterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서포터즈'),
      ),
      body: const Center(
        child: Text(
          '서포터즈 기능 실행 중...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
