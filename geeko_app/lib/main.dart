import 'dart:async';
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
      title: 'Safety Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SafetyDetectionPage(),
    );
  }
}

class SafetyDetectionPage extends StatefulWidget {
  const SafetyDetectionPage({super.key});

  @override
  State<SafetyDetectionPage> createState() => _SafetyDetectionPageState();
}

class _SafetyDetectionPageState extends State<SafetyDetectionPage> {
  // 가속도 데이터
  // List<double> accelerationHistory = []; // 모든 가속도 값을 저장
  // accelerationX, accelerationY, accelerationZ 저장
  List<double> accelerationHistoryX = [];
  List<double> accelerationHistoryY = [];
  List<double> accelerationHistoryZ = [];
  double previousAccelerationForAbruption = 0.0; // 급감속/급가속 체크용
  double currentAccelerationForAbruption = 0.0; // 급감속/급가속 체크용
  double previousAccelerationForPedestrian = 0.0; // 인도/차도 체크용
  double currentAccelerationForPedestrian = 0.0; // 인도/차도 체크용

  // 중력 값 (Low-Pass Filter로 계산)
  double gravityX = 0.0, gravityY = 0.0, gravityZ = 0.0;
  double accelerationX = 0.0, accelerationY = 0.0, accelerationZ = 0.0;
  final double alpha = 0.8; // 필터 상수 (값이 작을수록 중력 변화가 느려짐)

  // 상태 관리
  String statusMessage = "정상 주행"; // 기본 메시지
  Timer? accelerationTimer; // 가속/감속 체크용 타이머
  Timer? roughSurfaceTimer; // 울퉁불퉁 체크용 타이머
  bool isDisplayingWarning = false; // 경고 메시지 출력 여부
  bool isPedestrianRoad = false; // 울퉁불퉁한 길 여부

  // 상수
  final double thresholdAcceleration = 3.0; // 급가속 임계값
  final double thresholdDeceleration = -3.0; // 급감속 임계값
  final double changeThreshold = 0.5; // 자잘한 변화 감지 기준 (가속도의 변화량)
  final int changeFrequencyLimit = 80; // 2초 동안 자잘한 변화 횟수 (울퉁불퉁 경고 기준)
  final Duration accelerationCheckInterval =
      const Duration(seconds: 1); // 가속/감속 체크 주기
  final Duration roughSurfaceCheckInterval =
      const Duration(seconds: 2); // 울퉁불퉁 체크 주기
  final Duration warningDuration = const Duration(seconds: 2); // 경고 메시지 출력 시간

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

      // currentAcceleration = sqrt(
      //   pow(event.x - gravityX, 2) +
      //       pow(event.y - gravityY, 2) +
      //       pow(event.z - gravityZ, 2),
      // );
      accelerationX = event.x - gravityX;
      accelerationY = event.y - gravityY;
      accelerationZ = event.z - gravityZ;
      accelerationHistoryX.add(accelerationX);
      accelerationHistoryY.add(accelerationY);
      accelerationHistoryZ.add(accelerationZ);

      // 가속도 데이터 기록
      // accelerationHistory.add(currentAcceleration);

      // print high pass filter value
      debugPrint(
          "x: ${event.x - gravityX}, y: ${event.y - gravityY}, z: ${event.z - gravityZ}");

      // debugPrint("acceleration.length: ${accelerationHistory.length}");

      setState(() {});
    });

    // 울퉁불퉁한 길 체크
    roughSurfaceTimer = Timer.periodic(roughSurfaceCheckInterval, (timer) {
      int recentChanges = _calculateRecentChanges();
      if (recentChanges >= changeFrequencyLimit) {
        // debugPrint("울퉁불퉁한 인도 주행 감지!sdfasdfs");
        isPedestrianRoad = true;
        _updateStatusMessage("⚠️ 인도 주행 감지! 지정된 도로로 이동하세요");
      } else if (!isDisplayingWarning) {
        _updateStatusMessage("정상 주행 중입니다");
        isPedestrianRoad = false;
      }
    });

    // 급가속/급감속 체크
    // 1초 간 가속도 평균 값
    // 진행 방향인 z축 가속도에 가중치 0.8을 주어 가속도 크기 계산
    // 초당 5개의 샘플을 가정하여 5개의 가속도 값을 저장하고 평균을 계산
    accelerationTimer = Timer.periodic(accelerationCheckInterval, (timer) {
      double currentAccelerationForAbruptionX = accelerationHistoryX
              .sublist(accelerationHistoryX.length - 5)
              .reduce((a, b) => a + b) /
          5;
      double currentAccelerationForAbruptionY = accelerationHistoryY
              .sublist(accelerationHistoryY.length - 5)
              .reduce((a, b) => a + b) /
          5;
      double currentAccelerationForAbruptionZ = accelerationHistoryZ
              .sublist(accelerationHistoryZ.length - 5)
              .reduce((a, b) => a + b) /
          5;
      // z축 가속도에 가중치 0.8을 주어 가속도 크기 계산
      currentAccelerationForAbruption =
          (0.8 * currentAccelerationForAbruptionZ +
              0.1 * currentAccelerationForAbruptionX +
              0.1 * currentAccelerationForAbruptionY);

      if (currentAccelerationForAbruption > thresholdAcceleration) {
        _triggerWarning("⚠️ 급가속 감지! 속도를 천천히 올리세요");
      } else if (currentAccelerationForAbruption < thresholdDeceleration) {
        _triggerWarning("⚠️ 급감속 감지! 속도를 천천히 줄이세요");
      } else if (!isDisplayingWarning && !isPedestrianRoad) {
        _updateStatusMessage("정상 주행");
      }
    });
  }

  // 최근 2초 동안 가속도 변화 횟수 계산
  int _calculateRecentChanges() {
    if (accelerationHistoryY.length < 2) return 0;

    int changeCount = 0;
    int sampleCount = roughSurfaceCheckInterval.inSeconds *
        100; // Assuming 100 samples per second

    for (int i = accelerationHistoryY.length - 1;
        i > 0 && i > accelerationHistoryY.length - sampleCount;
        i--) {
      double diff = (0.1 * accelerationHistoryX[i] +
              0.8 * accelerationHistoryY[i] +
              0.1 * accelerationHistoryZ[i] -
              0.1 * accelerationHistoryX[i - 1] -
              0.8 * accelerationHistoryY[i - 1] -
              0.1 * accelerationHistoryZ[i - 1])
          .abs();
      if (diff > changeThreshold) {
        changeCount++;
      }
    }

    debugPrint("changeCount: $changeCount");
    return changeCount;
  }

  // 경고 메시지 출력 함수
  void _triggerWarning(String message) {
    if (!isDisplayingWarning) {
      setState(() {
        statusMessage = message; // 경고 메시지 표시
        isDisplayingWarning = true;
      });

      Timer(warningDuration, () {
        setState(() {
          isDisplayingWarning = false; // 경고 종료 후 상태 복구
          statusMessage = "정상 주행하고 있습니다"; // 정상 주행 메시지로 복귀
        });
      });
    }
  }

  // 상태 메시지 업데이트 함수
  void _updateStatusMessage(String message) {
    if (statusMessage != message) {
      setState(() {
        statusMessage = message;
      });
    }
  }

  @override
  void dispose() {
    accelerationTimer?.cancel(); // 타이머 해제
    roughSurfaceTimer?.cancel(); // 타이머 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Detection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '현재 상태:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                statusMessage,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color:
                      statusMessage.contains("⚠️") ? Colors.red : Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                '급감속에 대한 가속도 크기: ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                currentAccelerationForAbruption.toStringAsFixed(2),
                style: const TextStyle(fontSize: 20),
              ),
              const Text(
                '인도/차도 구별을 위한 가속도 크기: ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                accelerationHistoryY[accelerationHistoryY.length - 1]
                    .toStringAsFixed(2),
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
