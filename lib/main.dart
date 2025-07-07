import 'package:dio/dio.dart';
import 'package:ffuiflutter/words.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MyApp.dart';
import 'getGeminiApiKey.dart';

late SharedPreferences pref;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pref=await SharedPreferences.getInstance();
   // doAdminProcess();
  runApp(const MyApp());
}





