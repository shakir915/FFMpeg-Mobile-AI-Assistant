import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffuiflutter/getGeminiApiKey.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

enum MessageType { user, ai, file, command, output }

class ChatMessage {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final String? filePath;
  final String? fileName;
  final String? fileSize;
  final String? thumbnail;
  final bool isEditable;
  final bool isProcessing;
  String? outDir;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.thumbnail,
    this.outDir,
    this.isEditable = false,
    this.isProcessing = false,
  });

  ChatMessage copyWith({String? content, bool? isEditable, bool? isProcessing, String? filePath, String? fileName, String? fileSize, String? outDir}) {
    return ChatMessage(
      id: id,
      type: type,
      outDir: outDir,
      content: content ?? this.content,
      timestamp: timestamp,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      thumbnail: thumbnail,
      isEditable: isEditable ?? this.isEditable,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  // Convert ChatMessage to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outDir': outDir,
      'type': type.toString().split('.').last, // Converts MessageType.text to 'text'
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'thumbnail': thumbnail,
      'isEditable': isEditable,
      'isProcessing': isProcessing,
      // Note: outDir is not serialized as Directory objects can't be easily serialized
      // You might want to store the path as a string if needed
    };
  }

  // Create ChatMessage from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      type: _parseMessageType(json['type'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      filePath: json['filePath'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as String?,
      outDir: json['outDir'] as String?,
      thumbnail: json['thumbnail'] as String?,
      isEditable: json['isEditable'] as bool? ?? false,
      isProcessing: json['isProcessing'] as bool? ?? false,
      // outDir is not restored from JSON - you'll need to handle this separately if needed
    );
  }

  static MessageType _parseMessageType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'user':
        return MessageType.user;
      case 'ai':
        return MessageType.ai;
      case 'file':
        return MessageType.file;
      case 'command':
        return MessageType.command;
      case 'output':
        return MessageType.output;
      // Add other MessageType cases as needed
      default:
        throw ArgumentError('Unknown MessageType: $typeString');
    }
  }
}

class FFmpegChatScreen extends StatefulWidget {
  const FFmpegChatScreen({super.key});

  @override
  State<FFmpegChatScreen> createState() => _FFmpegChatScreenState();
}

class _FFmpegChatScreenState extends State<FFmpegChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();

  GenerativeModel? _model;
  bool _isAIThinking = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    if(kDebugMode)
    () async {
      final Directory docDir = await getApplicationDocumentsDirectory();
     // await Dio().download("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", "${docDir.path}/test.mp4");

      await Future.delayed(Duration(seconds: 2));

      _selectedFilePath = "${docDir.path}/test.mp4";
      _selectedFileName = "test.mp4";
      _addMessage(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.file,
        content: "File selected",
        timestamp: DateTime.now(),
        filePath: "${docDir.path}/test.mp4",
        fileName: "test.mp4",
        fileSize: "${100} MB",
      ));

      print("DioDioDioDioDio");
    }.call();
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {
    try {
      final Directory docDir = await getApplicationDocumentsDirectory();
      var file = File(docDir.path + "/chatV3.json");
      print("_addWelcomeMessage old ${await file.readAsString()}");

      print(file.readAsStringSync());
      var jsonList = jsonDecode(await file.readAsString());
      final List<ChatMessage> messages = jsonList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<ChatMessage>(); // Add this cast
      _messages.addAll(messages);
    } catch (e, s) {
      print(e);
      print(s);
    }

    try {

      _model = GenerativeModel(model: "gemini-2.0-flash", apiKey: getGeminiApiKey());
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "🤖 AI initialized! I can help you create FFmpeg commands.",
          timestamp: DateTime.now(),
        ),
      );
      _addMessage(
        ChatMessage(
          id: 'welcome',
          type: MessageType.ai,
          content:
          "👋 Welcome! Select a file and tell me what you'd like to do with it. I'll generate the FFmpeg command for you!\nexample : convert the video to MP3 audio",
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "⚠️ AI not available. You can still use manual FFmpeg commands.",
          timestamp: DateTime.now(),
        ),
      );

    }

    getDirectorySizeBytes();
  }


  Future<void> _addMessage(ChatMessage message,{dontScrolls=false,save=false}) async {
    setState(() {
      _messages.add(message);
    });
    if(!dontScrolls) {
      await waitForBuildIfPending();
      _scrollToBottom();
    }
    if(save)
    try {
      if (_messages.isNotEmpty) {
        final Directory docDir = await getApplicationDocumentsDirectory();
        File(docDir.path + "/chatV3.json").writeAsString(jsonEncode(_messages.where((m)=>m.type==MessageType.output).map((m) => m.toJson()).toList())).then((a) {
          print("after write : readed ");
          print(File(docDir.path + "/chatV3.json").readAsStringSync());
        });
      }
    } catch (e, s) {
      print(s);
      print(e);
    }

    getDirectorySizeBytes();

  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    _addMessage(ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.user, content: text, timestamp: DateTime.now()));

    if (_selectedFilePath == null) {
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "Please select a file first using the file picker buttons below! 📎",
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    await _generateAICommand(text);
  }

  Future<void> _generateAICommand(String userPrompt) async {
    FocusScope.of(context).unfocus();
    if (_model == null) {
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "AI not available. Please enter FFmpeg command manually.",
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    setState(() {
      _isAIThinking = true;
    });

    _addMessage(ChatMessage(id: 'thinking', type: MessageType.ai, content: "🤔 Thinking...", timestamp: DateTime.now()));

    final Directory docDir = await getApplicationDocumentsDirectory();
    final Directory outDir = Directory('${docDir.path}/${DateTime.now().millisecondsSinceEpoch}');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    try {
      String prompt =
          '''
Generate an FFmpeg command based on this request: "$userPrompt"

Rules:
1. Use "\"$_selectedFilePath\"" as input filename (will be replaced with actual path)
2. use output file directory as \"${outDir.absolute}\"
3. Use appropriate output filename with correct extension
4. Keep commands concise and practical no explanations needed, only command, no ffmpeg at first, it is for programmatical execution in mobile side , don't use /usr/bin/ or bash like thing on start, only the command for ffmpeg required 



Request: $userPrompt
FFmpeg command:''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      setState(() {
        _messages.removeWhere((msg) => msg.id == 'thinking');
      });

      print(response.text);
      if (response.text != null) {
        String generatedCommand = response.text!.trim();
        generatedCommand = generatedCommand.replaceAll('```', '').replaceAll('ffmpeg ', '').trim();

        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.command,
            content: generatedCommand,
            timestamp: DateTime.now(),
            outDir: outDir?.path,
            isEditable: true,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg.id == 'thinking');
      });
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "Error generating command: $e",
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      setState(() {
        _isAIThinking = false;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);

      if (result != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

        setState(() {
          _selectedFilePath = result.files.single.path!;
          _selectedFileName = result.files.single.name;
        });

        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.file,
            content: "File selected",
            timestamp: DateTime.now(),
            filePath: result.files.single.path!,
            fileName: result.files.single.name,
            fileSize: "${fileSizeInMB} MB",
          ),
        );
      }
    } catch (e) {
      _addMessage(
        ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.ai, content: "Error picking file: $e", timestamp: DateTime.now()),
      );
    }
  }

  Future<void> _pickMediaFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 10));

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

        setState(() {
          _selectedFilePath = pickedFile.path;
          _selectedFileName = pickedFile.path.split('/').last;
        });

        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.file,
            content: "Video selected from gallery",
            timestamp: DateTime.now(),
            filePath: pickedFile.path,
            fileName: pickedFile.path.split('/').last,
            fileSize: "${fileSizeInMB} MB",
          ),
        );
      }
    } catch (e) {
      try {
        final XFile? imageFile = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (imageFile != null) {
          final file = File(imageFile.path);
          final fileSize = await file.length();
          final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

          setState(() {
            _selectedFilePath = imageFile.path;
            _selectedFileName = imageFile.path.split('/').last;
          });

          _addMessage(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: MessageType.file,
              content: "Image selected from gallery",
              timestamp: DateTime.now(),
              filePath: imageFile.path,
              fileName: imageFile.path.split('/').last,
              fileSize: "${fileSizeInMB} MB",
            ),
          );
        }
      } catch (e2) {
        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.ai,
            content: "Error picking from gallery: $e2",
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<void> _pickMediaFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 10));

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

        setState(() {
          _selectedFilePath = pickedFile.path;
          _selectedFileName = pickedFile.path.split('/').last;
        });

        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.file,
            content: "Video captured",
            timestamp: DateTime.now(),
            filePath: pickedFile.path,
            fileName: pickedFile.path.split('/').last,
            fileSize: "${fileSizeInMB} MB",
          ),
        );
      }
    } catch (e) {
      try {
        final XFile? imageFile = await _imagePicker.pickImage(source: ImageSource.camera);
        if (imageFile != null) {
          final file = File(imageFile.path);
          final fileSize = await file.length();
          final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

          setState(() {
            _selectedFilePath = imageFile.path;
            _selectedFileName = imageFile.path.split('/').last;
          });

          _addMessage(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: MessageType.file,
              content: "Image captured",
              timestamp: DateTime.now(),
              filePath: imageFile.path,
              fileName: imageFile.path.split('/').last,
              fileSize: "${fileSizeInMB} MB",
            ),
          );
        }
      } catch (e2) {
        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.ai,
            content: "Error capturing from camera: $e2",
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  Future<void> _executeFFmpegCommand(String command, String messageId, String? outDir) async {
    ChatMessage? statusMessage;
    ChatMessage? logMesaage;

    if (_selectedFilePath == null) {
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "No file selected to process!",
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    setState(() {
      final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(isProcessing: true);
      }
    });

    try {
      print("command $command");

      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            setState(() {
              if (statusMessage != null) _messages.remove(statusMessage);
              final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
              if (messageIndex != -1) {
                _messages[messageIndex] = _messages[messageIndex].copyWith(isProcessing: false);
              }
              _showOutputFile(outDir!);
            });
          } else if (ReturnCode.isCancel(returnCode)) {
            _addMessage(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: MessageType.ai,
                content: "❌ FFmpeg execution failed",
                timestamp: DateTime.now(),
              ),
            );
          }
        },
        (Log lcb) {
          print("log ${lcb.getMessage()}");

          if (logMesaage == null) {
            logMesaage = ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: MessageType.ai,
              content: lcb.getMessage(),
              timestamp: DateTime.now(),
            );
            _addMessage(logMesaage!);
          } else {
            logMesaage = logMesaage?.copyWith(content: lcb.getMessage());
            setState(() {});
          }
        },
        (Statistics statistics) {
          print("Statistics ${statistics.toString()}");
          final timeInMilliseconds = statistics.getTime();
          final speed = statistics.getSpeed();
          final videoFrameNumber = statistics.getVideoFrameNumber();
          final videoFps = statistics.getVideoFps();
          final bitrate = statistics.getBitrate();
          final size = statistics.getSize();
          if (statusMessage == null) {
            statusMessage = ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: MessageType.ai,
              content: "$timeInMilliseconds ms, $speed x, ${(size / (1000 * 1000)).toStringAsFixed(1)} MB, $videoFrameNumber, ${videoFps}fps, $bitrate",
              timestamp: DateTime.now(),
            );
            _addMessage(statusMessage!);
          } else {
            statusMessage = statusMessage?.copyWith(
              content: "$timeInMilliseconds ms, $speed x, ${(size / (1000 * 1000)).toStringAsFixed(1)} MB, $videoFrameNumber, ${videoFps}fps, $bitrate",
            );
            setState(() {});
          }
        },
      );
    } catch (e) {
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = _messages[messageIndex].copyWith(isProcessing: false);
        }
      });
      _addMessage(ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.ai, content: "Error: $e", timestamp: DateTime.now()));
    }
  }

  Future<void> _showOutputFile(String outDir) async {
    Directory(outDir).listSync().forEach((outputFilePath) async {
      if (File(outputFilePath.path).existsSync()) {
        final file = File(outputFilePath.path);
        final fileSize = await file.length();
        final fileSizeInMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

        _addMessage(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: MessageType.output,
            content: "✅ Processing completed!",
            timestamp: DateTime.now(),
            filePath: outputFilePath.path,
            fileName: file.uri.pathSegments.last,
            fileSize: "${fileSizeInMB} MB",
          ),
          save: true
        );
      }
    });
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final box = context.findRenderObject() as RenderBox;
      final sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;

      await Share.shareXFiles([XFile(filePath)],  sharePositionOrigin: sharePositionOrigin, );
    } catch (e) {
      _addMessage(
        ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.ai, content: "Error sharing file: $e", timestamp: DateTime.now()),
      );
    }
  }

  void _updateCommandMessage(String messageId, String newCommand) {
    setState(() {
      final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(content: newCommand);
      }
    });
  }

  var scrolledUp = false;

  @override
  Widget build(BuildContext context) {
    _checkAndScrollToBottom();
    print("bottom ${MediaQuery.of(context).viewInsets.bottom}");
    print("bottom ${MediaQuery.of(context).padding.bottom}");
    if (MediaQuery.of(context).viewInsets.bottom > 100 && !scrolledUp) {
      () async {
        await waitForBuildIfPending();
        if (mounted) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          scrolledUp = true;
        }
      }.call();
    } else {
      scrolledUp = false;
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FFMpeg AI Assistant'),
          centerTitle: true,
          actions: [
            if(totalSizeOfDir>(10*1000*1000))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                    deleteDialog();

                },
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                label:  Text(
                  '${formatBytes(totalSizeOfDir)}',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(60, 32)),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    switch (message.type) {
      case MessageType.user:
        return _buildUserMessage(message);
      case MessageType.ai:
        return _buildAIMessage(message);
      case MessageType.file:
        return _buildFileMessage(message);
      case MessageType.command:
        return _buildCommandMessage(message);
      case MessageType.output:
        return _buildOutputMessage(message);
    }
  }

  Widget _buildUserMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
        child: Text(message.content, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAIMessage(ChatMessage message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(20)),
        child: Text(message.content, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildFileMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.grey[850],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.file_present, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? 'Unknown file',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(message.fileSize ?? '', style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.orange[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('FFmpeg Command', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: message.content,
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: null,
                decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.black26),
                onChanged: (value) => _updateCommandMessage(message.id, value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message.content, message.id, message.outDir),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                      label: Text(message.isProcessing ? 'Processing...' : 'Run Command'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutputMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Colors.green[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(message.content, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.movie, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.fileName ?? 'Output file',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(message.fileSize ?? '', style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _shareFile(message.filePath!),
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text('Share', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Select File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.attach_file, color: Colors.white),
              ),
              title: const Text('Choose File'),
              subtitle: const Text('Select any file from storage'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Gallery'),
              subtitle: const Text('Pick photo or video from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickMediaFromGallery();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Camera'),
              subtitle: const Text('Capture photo or video'),
              onTap: () {
                Navigator.pop(context);
                _pickMediaFromCamera();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[700]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: _showAttachmentOptions,
              icon: const Icon(Icons.attach_file),
              style: IconButton.styleFrom(backgroundColor: Colors.grey[800]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[800],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isAIThinking ? null : _sendMessage,
              icon: _isAIThinking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              style: IconButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  var totalSizeOfDir = 0;

  Future<int> getDirectorySizeBytes() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    int totalSize = 0;

    try {
      await for (FileSystemEntity entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            print('Error reading file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      print('Error reading directory ${directory.path}: $e');
    }
    print("totalSize ${totalSize/(1000*1000)} mb");
    if(totalSizeOfDir!=totalSize) {
      totalSizeOfDir = totalSize;
      setState(() {

      });
    }
    return totalSize;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void deleteDialog(){
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'Clear All Data',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('All chat messages', style: TextStyle(color: Colors.grey[300])),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.folder_outlined, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('All processed media files', style: TextStyle(color: Colors.grey[300])),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.storage_outlined, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('${formatBytes(totalSizeOfDir)} of storage ', style: TextStyle(color: Colors.grey[300])),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final Directory directory = await getApplicationDocumentsDirectory();
                  await for (FileSystemEntity entity in directory.list()) {
                    if (entity is Directory) {
                      await entity.delete(recursive: true);
                    } else if (entity is File) {
                      await entity.delete();
                    }
                  }
                } catch (e) {
                  print('Error deleting directory contents: $e');
                }
                _messages.clear();
                _initializeGemini();
              },
              icon: Icon(Icons.delete_forever, size: 18),
              label: Text('Delete All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  var last_maxScrollExtent=0.0;

  Future<void> _checkAndScrollToBottom() async {
    await waitForBuildIfPending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScrollExtent = _scrollController.position.maxScrollExtent;

        if (maxScrollExtent>last_maxScrollExtent) {
          _scrollController.animateTo(
            maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        last_maxScrollExtent=maxScrollExtent;
      }
    });
  }



}

Future<void> waitForBuildIfPending() async {
  if (SchedulerBinding.instance.hasScheduledFrame) {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }
  // Already built, no need to wait
  return;
}
