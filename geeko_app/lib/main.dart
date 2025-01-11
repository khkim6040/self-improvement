import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Accelerometer Demo',
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double x = 0.0, y = 0.0, z = 0.0;
  double linearX = 0.0, linearY = 0.0, linearZ = 0.0;

  // 중력 값을 유지하기 위한 변수 (Low-Pass Filter)
  double gravityX = 0.0, gravityY = 0.0, gravityZ = 0.0;

  // 필터 상수: 값이 작을수록 중력이 더 느리게 변화
  final double alpha = 0.8;

  // 사용자에게 경고 메시지를 제공하기 위한 변수
  String feedbackMessage = '';

  @override
  void initState() {
    super.initState();

    // 가속도 데이터 수집
    accelerometerEvents.listen((AccelerometerEvent event) {
      // 중력 계산 (Low-Pass Filter)
      gravityX = alpha * gravityX + (1 - alpha) * event.x;
      gravityY = alpha * gravityY + (1 - alpha) * event.y;
      gravityZ = alpha * gravityZ + (1 - alpha) * event.z;

      // 중력 제거 후, 실제 움직임 계산 (High-Pass Filter)
      linearX = event.x - gravityX;
      linearY = event.y - gravityY;
      linearZ = event.z - gravityZ;

      // 급가속/급제동 감지
      feedbackMessage = _detectSuddenAcceleration(linearX, linearY, linearZ);

      setState(() {
        x = event.x;
        y = event.y;
        z = event.z;
      });
    });
  }

  // 급가속/급제동 감지 함수
  String _detectSuddenAcceleration(double x, double y, double z) {
    double accelerationMagnitude = sqrt(x * x + y * y + z * z);

    if (accelerationMagnitude > 15.0) {
      return '⚠️ 급가속 감지! 속도를 줄이세요!';
    } else if (accelerationMagnitude < 5.0) {
      return '⚠️ 급제동 감지!';
    } else {
      return '안전 주행 중입니다. 👍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accelerometer Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Raw Acceleration (with Gravity):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Linear Acceleration (without Gravity):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'x: ${linearX.toStringAsFixed(2)}, y: ${linearY.toStringAsFixed(2)}, z: ${linearZ.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              feedbackMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    feedbackMessage.contains('⚠️') ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
