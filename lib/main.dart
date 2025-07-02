import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffuiflutter/getGeminiApiKey.dart';
import 'package:ffuiflutter/words.dart';
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
   String content;
  final DateTime timestamp;
  final String? filePath;
  final String? fileName;
  final String? fileSize;
  final String? thumbnail;
  final bool isEditable;
   bool isProcessing;
  String? outDir;
  String? inputFileFakedPart;
  String? inputFileFake;

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
    this.inputFileFakedPart,
    this.inputFileFake,

    this.isEditable = false,
    this.isProcessing = false,
  });



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
      'inputFileFakedPart': inputFileFakedPart,
      'inputFileFake': inputFileFake,
      'isProcessing': isProcessing,
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
      inputFileFakedPart: json['inputFileFakedPart'] as String?,
      inputFileFake: json['inputFileFake'] as String?,

      isEditable: json['isEditable'] as bool? ?? false,
      isProcessing: json['isProcessing'] as bool? ?? false,
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
  final FocusNode focus1 = FocusNode();
  final FocusNode focus2 = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  var scrollToBottomPending=false;

  GenerativeModel? _model;
  bool _isAIThinking = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    if(kDebugMode)
    () async {
     //  final Directory docDir = await getApplicationDocumentsDirectory();
     // // await Dio().download("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", "${docDir.path}/test.mp4");
     //
     //  await Future.delayed(Duration(seconds: 2));
     //
     //  _selectedFilePath = "${docDir.path}/test.mp4";
     //  _selectedFileName = "test.mp4";
     //  _addMessage(ChatMessage(
     //    id: DateTime.now().millisecondsSinceEpoch.toString(),
     //    type: MessageType.file,
     //    content: "File selected",
     //    timestamp: DateTime.now(),
     //    filePath: "${docDir.path}/test.mp4",
     //    fileName: "test.mp4",
     //    fileSize: "${100} MB",
     //  ));
     //
     //  print("DioDioDioDioDio");
    }.call();
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {
    try {
      final Directory docDir = await getApplicationDocumentsDirectory();
      var file = File(docDir.path + "/chatV5.json");
      print("_addWelcomeMessage old ${await file.readAsString()}");

      print(file.readAsStringSync());
      var jsonList = jsonDecode(await file.readAsString());
      final List<ChatMessage> messages = jsonList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList()
          .cast<ChatMessage>(); // Add this cast
      messages.forEach((m)=>m.isProcessing=false);
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
          content: aiInitialized,
          timestamp: DateTime.now(),
        ),
      );
      _addMessage(
        ChatMessage(
          id: 'welcome',
          type: MessageType.ai,
          content:
          welcome,
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
      scrollToBottomPending=true;
      _messages.add(message);
    });

    // if(save)
    try {
      if (_messages.isNotEmpty) {
        final Directory docDir = await getApplicationDocumentsDirectory();
        File(docDir.path + "/chatV5.json").writeAsString(jsonEncode(_messages.where((m)=>
        m.content!=welcome&&m.content!=aiInitialized&&m.content!=pleaseSelectFiles&&m.content!=noFileSelected
        ).map((m) => m.toJson()).toList())).then((a) {
          print("after write : readed ");
          print(File(docDir.path + "/chatV5.json").readAsStringSync());
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
          content: pleaseSelectFiles,
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



    var outDir=await createNewOutDir();

    try {
      String prompt =
          '''
Generate an FFmpeg command based on this request: "$userPrompt"

Rules:
1. Use "\"$_selectedFilePath\"" as input filename (will be replaced with actual path)
2. use output file directory as \"${outDir}\"
3. Use appropriate output filename with correct extension
4. Keep commands concise and practical no explanations needed, only command,  it is for programmatical execution  , don't use /usr/bin/ or bash like thing on start, only the command for ffmpeg required 



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
            outDir: outDir,
            inputFileFake: "input_file.${getExtension(_selectedFilePath)}",
            inputFileFakedPart: _selectedFilePath,
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

  Future<void> _executeFFmpegCommand(ChatMessage chat) async {

    setState(() {
      editing=null;
    });

    ChatMessage? statusMessage;
    ChatMessage? logMesaage;

    if(chat?.content?.trim()?.isNotEmpty!=true) return;

    print(chat.toJson());
    print("newOtDir old ${chat.outDir}");
    if(await Directory(chat.outDir!)!.list()!.length!>0){
      print("newOtDir newOtDir");
      var newOtDir= await createNewOutDir();
      chat.content=chat.content!.replaceAll(chat.outDir!, newOtDir!);
      chat.outDir=newOtDir;
    }



    // if (_selectedFilePath == null) {
    //   _addMessage(
    //     ChatMessage(
    //       id: DateTime.now().millisecondsSinceEpoch.toString(),
    //       type: MessageType.ai,
    //       content: noFileSelected,
    //       timestamp: DateTime.now(),
    //     ),
    //   );
    //   return;
    // }

    setState(() {
      chat.isProcessing=true;
    });

    try {


      var command=chat.content.trim();
      print("command ${command.startsWith("ffmpeg ")}");
      print("command ${command}");
      if(command.startsWith("ffmpeg ")){
        command=command.replaceFirst("ffmpeg ", "");
      }
      print("command ${command}");
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            setState(() {
              if (statusMessage != null) _messages.remove(statusMessage);
              if (logMesaage != null) _messages.remove(logMesaage);
              chat.isProcessing = false;
              _showOutputFile(chat!.outDir!);
            });
          } else if (ReturnCode.isCancel(returnCode)) {
            chat.isProcessing = false;
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
            logMesaage?.content= lcb.getMessage();
            setState(() {});
          }
        },
        (Statistics statistics) {
          // print("Statistics ${statistics.toString()}");
          // final timeInMilliseconds = statistics.getTime();
          // final speed = statistics.getSpeed();
          // final videoFrameNumber = statistics.getVideoFrameNumber();
          // final videoFps = statistics.getVideoFps();
          // final bitrate = statistics.getBitrate();
          // final size = statistics.getSize();
          // if (statusMessage == null) {
          //   statusMessage = ChatMessage(
          //     id: DateTime.now().millisecondsSinceEpoch.toString(),
          //     type: MessageType.ai,
          //     content: "$timeInMilliseconds ms, $speed x, ${(size / (1000 * 1000)).toStringAsFixed(1)} MB, $videoFrameNumber, ${videoFps}fps, $bitrate",
          //     timestamp: DateTime.now(),
          //   );
          //   _addMessage(statusMessage!);
          // } else {
          //   statusMessage = statusMessage?.copyWith(
          //     content: "$timeInMilliseconds ms, $speed x, ${(size / (1000 * 1000)).toStringAsFixed(1)} MB, $videoFrameNumber, ${videoFps}fps, $bitrate",
          //   );
          //   setState(() {});
          // }
        },
      );
    } catch (e) {
      setState(() {
        chat.isProcessing=false;
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


  var scrolledUp = false;

  @override
  Widget build(BuildContext context) {
    if(scrollToBottomPending)
     _checkAndScrollToBottom();
    print("bottom ${MediaQuery.of(context).viewInsets.bottom}");
    print("bottom ${MediaQuery.of(context).padding.bottom}");
    if (MediaQuery.of(context).viewInsets.bottom > 50 && !scrolledUp) {
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
        setState(() {
        editing=null;
        });
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FFMpeg AI Assistant'),
          centerTitle: true,
          actions: [

            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                    deleteDialog();

                },
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 25),
                label:  Text(
                  totalSizeOfDir>(10*1000*1000) ? '${formatBytes(totalSizeOfDir)}' : "",
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

            if(editing!=null)
              commandInput(editing!)
            else if(MediaQuery.of(context).viewInsets.bottom < 50||focus1.hasFocus)
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
        return _buildCommandMessage5(message);
      case MessageType.output:
        return _buildOutputMessage4(message);
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                           getFileNameWithoutExtension( message.fileName) ,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          "."+getExtension( message.fileName) ,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        )
                      ],
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

/*  Widget _buildCommandMessage0(ChatMessage message) {
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
  }*/

/*  Widget _buildCommandMessage1(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFF1E293B), // Slate-800
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: const Color(0xFF60A5FA)), // Blue-400
                  const SizedBox(width: 8),
                  const Text('FFmpeg Command',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF60A5FA), // Blue-400
                      )
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: message.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF374151)), // Gray-700
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF374151)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF60A5FA)),
                  ),
                  filled: true,
                  fillColor: Color(0xFF111827), // Gray-900
                ),
                onChanged: (value) => _updateCommandMessage(message.id, value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message.content, message.id, message.outDir),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(
                        message.isProcessing ? 'Processing...' : 'Run Command',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6), // Blue-500
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }*/


/*  Widget _buildCommandMessage2(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFF1F1B2E), // Dark purple
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: const Color(0xFFA855F7)), // Purple-500
                  const SizedBox(width: 8),
                  const Text('FFmpeg Command',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA855F7),
                      )
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: message.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4C1D95)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4C1D95)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFA855F7)),
                  ),
                  filled: true,
                  fillColor: Color(0xFF0F0A1A),
                ),
                onChanged: (value) => _updateCommandMessage(message.id, value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message.content, message.id, message.outDir),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(
                        message.isProcessing ? 'Processing...' : 'Run Command',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6), // Purple-500
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }*/


/*  Widget _buildCommandMessage3(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFF0A0F0D), // Very dark green
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: const Color(0xFF00FF88)), // Bright green
                  const SizedBox(width: 8),
                  const Text('FFmpeg Command',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF88),
                      )
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: message.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF00FF88),
                ),
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A2A1F)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A2A1F)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                  filled: true,
                  fillColor: Color(0xFF000000),
                ),
                onChanged: (value) => _updateCommandMessage(message.id, value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message.content, message.id, message.outDir),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.play_arrow, color: Colors.black),
                      label: Text(
                        message.isProcessing ? 'Processing...' : 'Run Command',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }*/

  Widget _buildOutputMessage4(ChatMessage message) {
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                               getFileNameWithoutExtension( message.fileName) ,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "."+getExtension( message.fileName) ,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            )
                          ],
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

  ChatMessage? editing;

  Widget _buildCommandMessage5(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFF2D3748), // Gray-700
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: const Color(0xFF68D391)), // Green-300
                  const SizedBox(width: 8),
                  const Text('FFmpeg Command',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  setState(() {
                    editing=message;
                  });
                  await waitForBuildIfPending();
                  focus2.requestFocus();
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color:  Color(0xFF4A5568),width: 1),

                    color: Color(0xFF1A202C),
                  ),
                  child: Text(
                  message.content
                        ?.replaceFirst(message.inputFileFakedPart!, message.inputFileFake!)
                        ?.replaceFirst(message.outDir!, "output_dir")??""
                    ,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                    ),
                    maxLines: 100,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(
                        message.isProcessing ? 'Processing...' : 'Run Command',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBB4878), // Green-500
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  Widget commandInput(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: const Color(0xFF2D3748), // Gray-700
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal, color: const Color(0xFF68D391)), // Green-300
                  const SizedBox(width: 8),
                  const Text('FFmpeg Command',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: message.content
                    ?.replaceFirst(message.inputFileFakedPart!, message.inputFileFake!)
                    ?.replaceFirst(message.outDir!, "output_dir")
                ,
                focusNode: focus2,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4A5568)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4A5568)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF68D391)),
                  ),
                  filled: true,
                  fillColor: Color(0xFF1A202C),
                ),
                onChanged: (value) {
                  message.content=value
                      .replaceFirst(message.inputFileFake!, message.inputFileFakedPart!)
                      .replaceFirst("output_dir", message.outDir!);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(
                        message.isProcessing ? 'Processing...' : 'Run Command',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBB4878), // Green-500
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                if(Platform.isAndroid)
                  _pickMediaFromGallery();
                else
                _pickMediaFromGallery2();
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
                focusNode: focus1,
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
                  Text('${formatBytes(totalSizeOfDir)} of app storage ', style: TextStyle(color: Colors.grey[300])),
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



  Future<void> _checkAndScrollToBottom() async {
    await waitForBuildIfPending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScrollExtent = _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        scrollToBottomPending=false;
      }
    });
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

  Future<void> _pickMediaFromGallery2() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        allowCompression: false, // This helps prevent compression
      );

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
            content: "Media selected from gallery (uncompressed)",
            timestamp: DateTime.now(),
            filePath: result.files.single.path!,
            fileName: result.files.single.name,
            fileSize: "${fileSizeInMB} MB",
          ),
        );
      }
    } catch (e) {
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "Error picking from gallery: $e",
          timestamp: DateTime.now(),
        ),
      );
    }
  }



  Future<String> createNewOutDir() async {
    final Directory docDir = await getApplicationDocumentsDirectory();
    final Directory outDir = Directory('${docDir.path}/${DateTime.now().millisecondsSinceEpoch}');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    return outDir.path;
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


String getExtension(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return '';

  final trimmedName = fileName.trim();
  final lastDotIndex = trimmedName.lastIndexOf('.');

  // No dot found or dot is at the beginning/end
  if (lastDotIndex <= 0 || lastDotIndex >= trimmedName.length - 1) {
    return '';
  }

  return trimmedName.substring(lastDotIndex + 1).toLowerCase();
}

String getFileNameWithoutExtension(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return '';

  final trimmedName = fileName.trim();
  final lastDotIndex = trimmedName.lastIndexOf('.');

  if (lastDotIndex <= 0) return trimmedName;

  return trimmedName.substring(0, lastDotIndex);
}
