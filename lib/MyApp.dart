import 'package:flutter/material.dart';

import 'FFmpegChatScreen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FFmpeg Chat',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(primary: Colors.blue, secondary: Colors.blueAccent, surface: Colors.grey[900]!),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(backgroundColor: Colors.grey[900], elevation: 0),
      ),
      home: const FFmpegChatScreen(),
    );
  }
}