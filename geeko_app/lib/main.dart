import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 리포트 시간 표시용
import 'package:sensors_plus/sensors_plus.dart'; // 가속도 센서 데이터 수집용

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
  // 상태 관리
  String statusMessage = "정상 주행"; // 상태 메시지
  Timer? accelerationTimer; // 가속/감속 체크 타이머
  Timer? roughSurfaceTimer; // 울퉁불퉁 체크 타이머
  bool isDisplayingWarning = false; // 경고 상태
  bool isPedestrianRoad = false; // 인도 여부

  // 점수 및 위반 사항 기록
  int totalScore = 100; // 초기 점수
  List<Map<String, String>> violations = []; // 위반 기록 (시간, 사유)

  // 상수
  final double thresholdAcceleration = 15.0; // 급가속 임계값
  final double thresholdDeceleration = -6.0; // 급감속 임계값
  final double changeThreshold = 0.5; // 자잘한 변화 감지 기준 (가속도의 변화량)
  final int changeFrequencyLimit = 80; // 2초 동안 자잘한 변화 횟수 (울퉁불퉁 경고 기준)
  final Duration warningDuration = const Duration(seconds: 2); // 경고 메시지 출력 시간

  // 가속도 데이터
  List<double> accelerationHistoryX = [];
  List<double> accelerationHistoryY = [];
  List<double> accelerationHistoryZ = [];
  double gravityX = 0.0,
      gravityY = 0.0,
      gravityZ = 0.0; // 중력 값 (Low-Pass Filter)
  final double alpha = 0.8; // 필터 상수

  @override
  void initState() {
    super.initState();

    // 가속도 데이터 수집
    accelerometerEvents.listen((AccelerometerEvent event) {
      gravityX = alpha * gravityX + (1 - alpha) * event.x;
      gravityY = alpha * gravityY + (1 - alpha) * event.y;
      gravityZ = alpha * gravityZ + (1 - alpha) * event.z;

      accelerationHistoryX.add(event.x - gravityX);
      accelerationHistoryY.add(event.y - gravityY);
      accelerationHistoryZ.add(event.z - gravityZ);

      setState(() {});
    });

    // 울퉁불퉁한 길 체크
    roughSurfaceTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      int recentChanges = _calculateRecentChanges();
      if (recentChanges >= changeFrequencyLimit) {
        isPedestrianRoad = true;
        _triggerWarning("⚠️ 인도 주행 감지! 지정된 도로로 이동하세요", "인도 주행", 2);
      } else if (!isDisplayingWarning) {
        _updateStatusMessage("정상 주행");
        isPedestrianRoad = false;
      }
    });

    // 급가속/급감속 체크
    accelerationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      double avgX = accelerationHistoryX
              .sublist(accelerationHistoryX.length - 5)
              .reduce((a, b) => a + b) /
          5;
      double avgY = accelerationHistoryY
              .sublist(accelerationHistoryY.length - 5)
              .reduce((a, b) => a + b) /
          5;
      double avgZ = accelerationHistoryZ
              .sublist(accelerationHistoryZ.length - 5)
              .reduce((a, b) => a + b) /
          5;

      double weightedAcceleration = (0.8 * avgZ + 0.1 * avgX + 0.1 * avgY);

      if (weightedAcceleration > thresholdAcceleration) {
        _triggerWarning("⚠️ 급가속 감지! 속도를 천천히 올리세요", "급가속", 1);
      } else if (weightedAcceleration < thresholdDeceleration) {
        _triggerWarning("⚠️ 급감속 감지! 속도를 천천히 줄이세요", "급감속", 1);
      } else if (!isDisplayingWarning && !isPedestrianRoad) {
        _updateStatusMessage("정상 주행");
      }
    });
  }

  // 최근 2초 동안 가속도 변화 횟수 계산
  int _calculateRecentChanges() {
    int changeCount = 0;
    int sampleCount = 200; // Assuming 100 samples per second
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
    return changeCount;
  }

  // 경고 메시지 출력 및 점수 차감
  void _triggerWarning(String message, String reason, int deduction) {
    if (!isDisplayingWarning) {
      setState(() {
        statusMessage = message;
        isDisplayingWarning = true;

        // 점수 차감 및 위반 기록 저장
        totalScore -= deduction;
        totalScore = max(0, totalScore); // 점수 음수 방지
        String currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
        violations.add({"time": currentTime, "reason": reason});
      });

      Timer(warningDuration, () {
        setState(() {
          isDisplayingWarning = false; // 경고 종료 후 상태 복구
          statusMessage = "정상 주행"; // 정상 상태로 복귀
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 운행 종료 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportPage(
                totalScore: totalScore,
                violations: violations,
              ),
            ),
          );
        },
        label: const Text("운행 종료"), // 텍스트 추가
        tooltip: "운행 종료",
      ),
    );
  }
}

// 리포트 화면
class ReportPage extends StatelessWidget {
  final int totalScore;
  final List<Map<String, String>> violations;

  const ReportPage(
      {super.key, required this.totalScore, required this.violations});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운행 리포트'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "최종 점수: $totalScore/100",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "위반 사항:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            violations.isEmpty
                ? const Text("위반 사항이 없습니다. 안전하게 주행했습니다!")
                : Expanded(
                    child: ListView.builder(
                      itemCount: violations.length,
                      itemBuilder: (context, index) {
                        final violation = violations[index];
                        return ListTile(
                          title: Text(
                              "${violation['time']} - ${violation['reason']}"),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
