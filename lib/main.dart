import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
    'urgent_alert_channel',
    '緊急警報通知',
    description: '用於網路重啟、緊急廣播等高優先級事件',
    importance: Importance.max,
    playSound: true,
  );

  const AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
    'general_alert_channel',
    '一般家庭廣播',
    description: '用於日常自訂訊息（如：開飯囉）',
    importance: Importance.defaultNotification,
    playSound: true,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(urgentChannel);
    await androidImplementation.createNotificationChannel(normalChannel);
  }

  runApp(const FamilyAlertApp());
}

class FamilyAlertApp extends StatelessWidget {
  const FamilyAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Alert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AlertHomePage(),
    );
  }
}

class AlertHomePage extends StatefulWidget {
  const AlertHomePage({super.key});

  @override
  Widget state() => _AlertHomePageState();
}

class _AlertHomePageState extends State<AlertHomePage> {
  final TextEditingController _msgController = TextEditingController();
  RawDatagramSocket? _udpSocket;

  @override
  void initState() {
    super.initState();
    _startUdpListener();
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

    if (isUrgent) {
      _showUrgentNotification("⚠️ 緊急/重啟通知", cleanMessage);
    } else {
      _showNormalNotification("📢 家庭廣播", cleanMessage);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isUrgent ? "已發送高優先級警報！" : "廣播已發送！")),
        );
      }
    } catch (e) {
      debugPrint("發送廣播失敗: $e");
    }
  }

  Future<void> _showUrgentNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'urgent_alert_channel',
      '緊急警報通知',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      fullScreenIntent: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, notificationDetails);
  }

  Future<void> _showNormalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general_alert_channel',
      '一般家庭廣播',
      importance: Importance.defaultNotification,
      priority: Priority.defaultPriority,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(1, title, body, notificationDetails);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 家用私人通知控制台'),
        centerTitle: true,
        backgroundColor: Colors.purple.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.red.shade50,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('網路重啟廣播 (高優先級警報)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('對全家發送高優先級通知，強制懸浮彈窗與警報響鈴。', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('發送 5 分鐘重啟預告'),
                      onPressed: () => _sendUdpBroadcast("Deco Wi-Fi 將於 5 分鐘後重新啟動，請先儲存手頭工作！", isUrgent: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Colors.purple.shade50,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.campaign, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text('自訂家庭廣播 (標準通知)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '輸入訊息（例如：開飯囉！）',
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('廣播至全家手機'),
                      onPressed: () {
                        if (_msgController.text.isNotEmpty) {
                          _sendUdpBroadcast(_msgController.text, isUrgent: false);
                          _msgController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget dispose() {
    _udpSocket?.close();
    _msgController.dispose();
    super.dispose();
  }
}
