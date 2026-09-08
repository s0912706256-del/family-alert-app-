import 'dart:async';
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
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const FamilyAlertApp());
}

Future<void> showNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'family_alert_channel',
    '家庭緊急通知',
    channelDescription: '用於網路重啟與緊急訊息廣播',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0, title, body, platformChannelSpecifics,
  );
}

class FamilyAlertApp extends StatelessWidget {
  const FamilyAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家庭私人通知助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _customMsgController = TextEditingController();
  RawDatagramSocket? _udpSocket;
  static const int udpPort = 8888;

  @override
  void initState() {
    super.initState();
    _startUdpListener();
  }

  void _startUdpListener() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
      _udpSocket?.broadcastEnabled = true;
      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _udpSocket?.receive();
          if (dg != null) {
            String message = utf8.decode(dg.data);
            showNotification("🏠 【家庭廣播通知】", message);
          }
        }
      });
    } catch (e) {
      debugPrint("UDP 監聽啟動失敗: $e");
    }
  }

  void _sendUdpBroadcast(String message) async {
    try {
      RawDatagramSocket socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      List<int> data = utf8.encode(message);
      socket.send(data, InternetAddress('255.255.255.255'), udpPort);
      socket.close();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚡ 已發送廣播通知給家中所有人！')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 廣播失敗：$e')),
      );
    }
  }

  @override
  void dispose() {
    _udpSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 家用私人通知控制台'),
        backgroundColor: Colors.deepPurple.shade100,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.red),
                    const SizedBox(height: 10),
                    const Text('網路重啟廣播', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('按下後會對家中所有連線手機發送「5 分鐘後重啟」通知。', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () {
                        _sendUdpBroadcast("🚨 系統將於 5 分鐘後重新啟動 Wi-Fi 路由器！請先存檔或暫停遊戲/會議！");
                      },
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('發送 5 分鐘重啟預告', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📢 自訂家庭廣播', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customMsgController,
                      decoration: const InputDecoration(
                        hintText: '輸入訊息（例如：開飯囉！）',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        if (_customMsgController.text.isNotEmpty) {
                          _sendUdpBroadcast(_customMsgController.text);
                          _customMsgController.clear();
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('廣播至全家手機'),
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
}
