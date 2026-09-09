import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const FamilyAlertApp());
}

class FamilyAlertApp extends StatelessWidget {
  const FamilyAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const AlertHomePage(),
    );
  }
}

class AlertHomePage extends StatefulWidget {
  const AlertHomePage({super.key});

  @override
  State<AlertHomePage> createState() => _AlertHomePageState();
}

class _AlertHomePageState extends State<AlertHomePage> {
  final TextEditingController _msgController = TextEditingController();
  RawDatagramSocket? _udpSocket;
  
  String _currentTime = '';
  String _currentDate = '';
  Timer? _clockTimer;

  // 廣播與動態警報狀態
  String? _alertMessage;
  bool _isUrgent = false;
  Timer? _alertDismissTimer;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _startUdpListener();
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      _currentDate = "${now.year}年${now.month}月${now.day}日";
    });
  }

  void _startUdpListener() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8888);
      _udpSocket?.broadcastEnabled = true;
      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _udpSocket?.receive();
          if (dg != null) {
            String message = utf8.decode(dg.data);
            _handleIncomingBroadcast(message);
          }
        }
      });
    } catch (e) {
      debugPrint("UDP 監聽失敗: $e");
    }
  }

  void _handleIncomingBroadcast(String rawMessage) {
    bool isUrgent = rawMessage.startsWith("[URGENT]");
    String cleanMessage = rawMessage.replaceAll("[URGENT]", "").replaceAll("[NORMAL]", "");

    _alertDismissTimer?.cancel();

    setState(() {
      _alertMessage = cleanMessage;
      _isUrgent = isUrgent;
    });

    // 普通廣播 15 秒後自動隱藏，緊急警報持續顯示直到手動點按
    if (!isUrgent) {
      _alertDismissTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            _alertMessage = null;
          });
        }
      });
    }
  }

  void _sendUdpBroadcast(String message, {bool isUrgent = false}) async {
    try {
      RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      String payload = (isUrgent ? "[URGENT]" : "[NORMAL]") + message;
      List<int> data = utf8.encode(payload);
      socket.send(data, InternetAddress('255.255.255.255'), 8888);
      socket.close();
    } catch (e) {
      debugPrint("發送廣播失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 常態靜態大時鐘 + 日期
              Text(
                _currentTime,
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                _currentDate,
                style: const TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // 2. 有事才會動態跳出的警報卡片 (無事時完全隱藏)
              if (_alertMessage != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isUrgent ? Colors.red.shade900 : Colors.deepPurple.shade800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isUrgent ? Colors.red : Colors.purpleAccent, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isUrgent ? Icons.warning_amber_rounded : Icons.campaign, color: Colors.white, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            _isUrgent ? "⚠️ 緊急重啟通知" : "📢 家庭廣播",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _alertMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        onPressed: () {
                          setState(() {
                            _alertMessage = null;
                          });
                        },
                        child: const Text('我知道了（關閉）'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],

              // 3. 廣播發送區
              Card(
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '輸入廣播訊息...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                              onPressed: () {
                                if (_msgController.text.isNotEmpty) {
                                  _sendUdpBroadcast(_msgController.text, isUrgent: false);
                                  _msgController.clear();
                                }
                              },
                              child: const Text('發送廣播', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () {
                                _sendUdpBroadcast("Deco Wi-Fi 將於 5 分鐘後重新啟動！", isUrgent: true);
                              },
                              child: const Text('5分鐘重啟預告', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _alertDismissTimer?.cancel();
    _udpSocket?.close();
    _msgController.dispose();
    super.dispose();
  }
}
