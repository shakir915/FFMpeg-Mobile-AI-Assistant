

import 'package:ffuiflutter/main.dart';

String aiInitialized="🤖 AI initialized! I can help you create FFmpeg commands.";
String welcome="👋 Welcome! Select a file and tell me what you'd like to do with it. I'll generate the FFmpeg command for you!\nexample : convert the video to MP3 audio";
String pleaseSelectFiles="Please select a file first using the file picker buttons below! 📎";
String noFileSelected="No file selected to process!";
const String YOUR_PROMPT_HERE="YOUR_PROMPT_HERE";
const String YOUR_FAILED_COMMAND_HERE="YOUR_FAILED_COMMAND_HERE";
const String YOUR_INPUT_FILES_HERE="YOUR_INPUT_FILES_HERE";
const String YOUR_OUTPUT_DIRECTORY_HERE="YOUR_OUTPUT_DIRECTORY_HERE";
const String YOUR_INPUT_FILES_DETAILS_HERE="YOUR_INPUT_FILES_DETAILS_HERE";
const String YOUR_ERROR_LOGS_HERE="YOUR_ERROR_LOGS_HERE";

String get initialPrompt => pref.getString("initialPrompt") ?? '''
Generate an FFmpeg command based on this request: "YOUR_PROMPT_HERE"

Rules:
- Use input files: YOUR_INPUT_FILES_HERE
- Use output directory: "YOUR_OUTPUT_DIRECTORY_HERE"
- Use appropriate output filename with correct extension
- Keep commands concise and practical - no explanations needed, only the command
- This is for programmatic execution on a mobile device
- Don't use /usr/bin/ or bash-like commands at the start - only FFmpeg command required
- Do not include: echo, printf, &&, ||, pipes, or shell operators
- Generate a static working command - no printf or echo as these commands will not work
- Generate ONLY a direct FFmpeg command for Android
- Use the concat filter method, not file lists or shell operators
- Include the actual file paths directly in the command

Input files details:
YOUR_INPUT_FILES_DETAILS_HERE
''';


String get retryPrompt => pref.getString("retryPrompt") ?? '''
The following FFmpeg command failed: "ffmpeg YOUR_FAILED_COMMAND_HERE"

Error logs:
YOUR_ERROR_LOGS_HERE

Generate an improved FFmpeg command based on the failed command and error logs.

Rules:
- Use output directory: "YOUR_OUTPUT_DIRECTORY_HERE"
- Keep commands concise and practical - no explanations needed, only the command
- This is for programmatic execution on a mobile device
- Don't use /usr/bin/ or bash-like commands at the start - only FFmpeg command required
- Do not include: echo, printf, &&, ||, pipes, or shell operators
- Generate a static working command - no printf or echo as these commands will not work
- Generate ONLY a direct FFmpeg command for Android
- Use the concat filter method, not file lists or shell operators
- Include the actual file paths directly in the command
- Fix the issues identified in the error logs

Input files details:
YOUR_INPUT_FILES_DETAILS_HERE
''';



