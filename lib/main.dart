import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MyApp.dart';

late SharedPreferences pref;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pref=await SharedPreferences.getInstance();
  runApp(const MyApp());
}





