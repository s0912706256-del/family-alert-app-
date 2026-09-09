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
      debugShowCheckedModeBanner: false,
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
  State<AlertHomePage> createState() => _AlertHomePageState();
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
    String cleanMessage =
        rawMessage.replaceAll("[URGENT]", "").replaceAll("[NORMAL]", "");

    if (isUrgent) {
      _showUrgentNotification("⚠️ 緊急/重啟通知", cleanMessage);
    } else {
      _showNormalNotification("📢 家庭廣播", cleanMessage);
    }
  }

  void _sendUdpBroadcast(String message, {bool isUrgent = false}) async {
    try {
      RawDatagramSocket socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      String payload = (isUrgent
