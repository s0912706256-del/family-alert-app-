import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地通知 Channel（Android 8.0+ 必須區分 Channel）
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 建立 Android 高優先級警報頻道 (重要通知)
  const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
    'urgent_alert_channel',
    '緊急警報通知',
    description: '用於網路重啟、緊急廣播等高優先級事件',
    importance: Importance.max,
    playSound: true,
  );

  // 建立 Android 標準優先級頻道 (一般廣播)
  const AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
    'general_alert_channel
