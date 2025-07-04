import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session_state.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffuiflutter/getGeminiApiKey.dart';
import 'package:ffuiflutter/utils.dart';
import 'package:ffuiflutter/words.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'ChatMessage.dart';
import 'ffFails.dart';

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
  var scrollToBottomPending = false;

  GenerativeModel? _model;
  bool _isAIThinking = false;

  List<String> selectedFiles = [];

  @override
  void initState() {
    super.initState();
    downloadBucksBunny();
    loadOldChatsAnd_initializeGemini();
  }


  Future<void> loadOldChatsAnd_initializeGemini() async {
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
    messages.forEach((m) => m.isProcessing = false);
    _messages.addAll(messages);
    } catch (e, s) {
    print(e);
    print(s);
    }
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {


    try {
      _model = GenerativeModel(model: "gemini-2.0-flash", apiKey: getGeminiApiKey());
      _addMessage(ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.ai, content: aiInitialized, timestamp: DateTime.now()));
      _addMessage(ChatMessage(id: 'welcome', type: MessageType.ai, content: welcome, timestamp: DateTime.now()));
    } catch (e) {
      _addMessage(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.ai,
          content: "⚠️ AI not available. You can still use manual FFmpeg commands.",
          timestamp: DateTime.now(),
        ),
      );
      _initializeGemini();
    }

    getDirectorySizeBytes();
  }

  Future<void> _addMessage(ChatMessage message, {dontScrolls = false, save = false}) async {
    setState(() {
      scrollToBottomPending = true;
      _messages.add(message);
    });

    // if(save)
    try {
      if (_messages.isNotEmpty) {
        final Directory docDir = await getApplicationDocumentsDirectory();
        File(docDir.path + "/chatV5.json")
            .writeAsString(
              jsonEncode(
                _messages
                    .where((m) => m.content != welcome && m.content != aiInitialized && m.content != pleaseSelectFiles && m.content != noFileSelected)
                    .map((m) => m.toJson())
                    .toList(),
              ),
            )
            .then((a) {
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

    if (selectedFiles.isEmpty) {
      _addMessage(
        ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.ai, content: pleaseSelectFiles, timestamp: DateTime.now()),
      );
      return;
    }

    await _generateAICommand(text, null,0,null);
  }

  Future<void> _generateAICommand(String userPrompt, List<String>? logs,retry,oldOutDir ) async {
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

    var outDir = await createNewOutDir();

    try {
      String prompt =
          '''
Generate an FFmpeg command based on this request: "$userPrompt"

Rules:
1. Use input file : \n${selectedFiles.map((file) => '\"$file\"').join('   ')}
2. use output file directory as \"${outDir}\"
3. Use appropriate output filename with correct extension
4. Keep commands concise and practical no explanations needed, only command,  it is for programmatical execution  , don't use /usr/bin/ or bash like thing on start, only the command for ffmpeg required 



Request: $userPrompt
FFmpeg command:''';

      if (logs?.isNotEmpty == true) {
        userPrompt=userPrompt.replaceAll(oldOutDir, outDir);
        prompt =
            "got errors on following ffmpeg command "
            "ffmpeg $userPrompt"
            "\n\n\n"
            "errors : \n${logs?.map((l) => '\"$l\"').join('   ')}"
            "Generate an FFmpeg command based on this commands and logs"
            "use output file directory as \"${outDir}\""
            "Keep commands concise and practical no explanations needed, only command,  it is for programmatical execution  , don't use /usr/bin/ or bash like thing on start, only the command for ffmpeg required";
      }

      final content = [Content.text(prompt)];

      final response = await _model!.generateContent(content);

      setState(() {
        _messages.removeWhere((msg) => msg.id == 'thinking');
      });

      print(response.text);

      if (response.text != null) {
        String generatedCommand = response.text!.trim();
        print("prompt $prompt\n content $generatedCommand");
        generatedCommand = generatedCommand.replaceAll('```', '');
        var i = 0;
        List<String> originals = [];
        List<String> fakes = [];
        selectedFiles.forEach((f) {
          f = f.replaceAll(RegExp(r'^/+|/+$'), '');
          i++;
          var iS = selectedFiles.length == 1 ? "" : i.toString();
          var fileName = f.split("/").last;
          var folder = f.replaceFirst(fileName, "");
          generatedCommand = generatedCommand.replaceFirst(folder, "inputDir$iS/");
          originals.add(folder);
          fakes.add("inputDir$iS/");
        });
        generatedCommand = generatedCommand.replaceFirst(outDir!, "outputDir");
        originals.add(outDir);
        fakes.add("outputDir");

        var msg=ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.command,
          content: generatedCommand,
          timestamp: DateTime.now(),
          outDir: outDir,
          isEditable: true,
          pathFakes: fakes,
          pathOriginal: originals,
        );
        _addMessage(
          msg ,
        );
        selectedFiles = [];
        if(retry>0){
          _executeFFmpegCommand(msg,--retry);
        }

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
      _initializeGemini();
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
          selectedFiles.add(result.files.single.path!);
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
          selectedFiles.add(pickedFile.path);
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
            selectedFiles.add(imageFile.path);
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

  Future<void> _executeFFmpegCommand(ChatMessage chat,retry) async {
    setState(() {
      editing = null;
    });

    ChatMessage? statusMessage;
    ChatMessage? logMesaage;

    if (chat?.content?.trim()?.isNotEmpty != true) return;

    print(chat.toJson());
    print("newOtDir old ${chat.outDir}");
    if (await Directory(chat.outDir!)!.list()!.length! > 0) {
      print("newOtDir newOtDir");
      var newOtDir = await createNewOutDir();
      chat.content = chat.content!.replaceAll(chat.outDir!, newOtDir!);
      chat.outDir = newOtDir;
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
      chat.isProcessing = true;
    });

    try {
      var command = chat.content.trim();
      print("command ${command.startsWith("ffmpeg ")}");
      print("command ${command}");
      if (command.startsWith("ffmpeg ")) {
        command = command.replaceFirst("ffmpeg ", "");
      }
      chat.pathFakes?.forEach((fake) {
        command = command.replaceAll(fake, chat.pathOriginal![chat.pathFakes!.indexOf(fake)]);
      });

      print("commandcommandcommand pathFakes\n${chat.pathFakes?.join("\n")}");
      print("commandcommandcommand pathOriginal\n${chat.pathOriginal?.join("\n")}");
      print("commandcommandcommand ${command}");
      var endSession=false;
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          print("session session session ${await session.getState()}");
          print("session session session ${await session.getReturnCode()}");
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            setState(() {
              if (statusMessage != null) _messages.remove(statusMessage);
              if (logMesaage != null) _messages.remove(logMesaage);
              chat.isProcessing = false;
              _showOutputFile(chat!.outDir!);
            });
          } else if (await session.getState() == SessionState.completed || await session.getState() == SessionState.failed) {
            chat.isProcessing = false;
            Future.delayed(Duration(seconds: 1)).then((a) async {
              _generateAICommand(command, logMesaage?.logs,--retry,chat.outDir);
            });
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
            logMesaage?.logs = [];
            logMesaage?.logs.add(lcb.getMessage());
            _addMessage(logMesaage!);
          } else {
            logMesaage?.logs.add(lcb.getMessage());
            logMesaage?.content = lcb.getMessage();
            setState(() {});
          }


          Future.delayed(Duration(seconds: 5)).then((a) async {
            if(chat.isProcessing&&logMesaage!.logs.lastOrNull==lcb.getMessage())
            try {
              var fFmpegFailureDetector = FFmpegFailureDetector();
              fFmpegFailureDetector.analyzeLog( logMesaage!.logs.join("\n"));
              if(fFmpegFailureDetector.hasError){
                            _generateAICommand(command, logMesaage?.logs,--retry,chat.outDir);
                          }
            } catch (e) {
              print(e);
            }

          });


        },
        (Statistics statistics) {
          print("statistics statistics statistics ${statistics}");
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
        chat.isProcessing = false;
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
          save: true,
        );
      }
    });
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final box = context.findRenderObject() as RenderBox;
      final sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;

      await Share.shareXFiles([XFile(filePath)], sharePositionOrigin: sharePositionOrigin);
    } catch (e) {
      _addMessage(
        ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), type: MessageType.ai, content: "Error sharing file: $e", timestamp: DateTime.now()),
      );
    }
  }

  var scrolledUp = false;

  @override
  Widget build(BuildContext context) {
    if (scrollToBottomPending) _checkAndScrollToBottom();
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
          editing = null;
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
                label: Text(
                  totalSizeOfDir > (10 * 1000 * 1000) ? '${formatBytes(totalSizeOfDir)}' : "",
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

            if (editing != null) commandInput(editing!) else if (MediaQuery.of(context).viewInsets.bottom < 50 || focus1.hasFocus) _buildChatInput(),
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
      child: GestureDetector(
        onTap: () {
          if (message.logs.isNotEmpty) {
            setState(() {
              message.isLogsDisplayed = !message.isLogsDisplayed;
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, right: 50),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Expanded(
                child: Text(message.isLogsDisplayed ? message.logs.join("\n") : message.content, style: const TextStyle(color: Colors.white)),
              ),
              if (message.logs.isNotEmpty) Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileMessage(ChatMessage message) {
    // Add this state variable to track selection (you'll need to manage this appropriately)
    // Default unticked

    return GestureDetector(
      onTap: () {
        setState(() {
          if (selectedFiles.contains(message.filePath)) {
            selectedFiles.remove(message.filePath);
          } else {
            selectedFiles.add(message.filePath!);
          }
        });
      },
      child: Container(
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
                              getFileNameWithoutExtension(message.fileName),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            ".${getExtension(message.fileName)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Text(message.fileSize ?? '', style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                ),
                // Tick/Untick button on top right
                Builder(
                  builder: (context) {
                    var isSelected = selectedFiles.contains(message.filePath);
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.green : Colors.grey[400]!, width: 2),
                        color: isSelected ? Colors.green : Colors.transparent,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                                getFileNameWithoutExtension(message.fileName),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "." + getExtension(message.fileName),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                  const Text(
                    'FFmpeg Command',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  setState(() {
                    editing = message;
                  });
                  await waitForBuildIfPending();
                  focus2.requestFocus();
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF4A5568), width: 1),

                    color: Color(0xFF1A202C),
                  ),
                  child: Builder(
                    builder: (context) {
                      return Text(
                        message.content,
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
                        maxLines: 100,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message,3),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(message.isProcessing ? 'Processing...' : 'Run Command', style: const TextStyle(color: Colors.white)),
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
                  const Text(
                    'FFmpeg Command',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: message.content,
                focusNode: focus2,
                style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4A5568))),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4A5568))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF68D391))),
                  filled: true,
                  fillColor: Color(0xFF1A202C),
                ),
                onChanged: (value) {
                  message.content = value;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: message.isProcessing ? null : () => _executeFFmpegCommand(message,3),
                      icon: message.isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow, color: Colors.white),
                      label: Text(message.isProcessing ? 'Processing...' : 'Run Command', style: const TextStyle(color: Colors.white)),
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
                if (Platform.isAndroid)
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
    print("totalSize ${totalSize / (1000 * 1000)} mb");
    if (totalSizeOfDir != totalSize) {
      totalSizeOfDir = totalSize;
      setState(() {});
    }
    return totalSize;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void deleteDialog() {
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        _scrollController.animateTo(maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        scrollToBottomPending = false;
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
          selectedFiles.add(pickedFile.path);
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
            selectedFiles.add(imageFile.path);
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
          selectedFiles.add(result.files.single.path!);
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

  void downloadBucksBunny() {
    // if(kDebugMode)
    //   () async {
    //   final Directory docDir = await getApplicationDocumentsDirectory();
    //   await Dio().download("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", "${docDir.path}/BigBuckBunny.mp4");
    //
    //   await Future.delayed(Duration(seconds: 2));
    //
    //   _selectedFilePath = "${docDir.path}/BigBuckBunny.mp4";
    //   _selectedFileName = "BigBuckBunny.mp4";
    //   _addMessage(ChatMessage(
    //     id: DateTime.now().millisecondsSinceEpoch.toString(),
    //     type: MessageType.file,
    //     content: "File selected",
    //     timestamp: DateTime.now(),
    //     filePath: "${docDir.path}/BigBuckBunny.mp4",
    //     fileName: "BigBuckBunny.mp4",
    //     fileSize: "${100} MB",
    //   ));
    //
    //   print("DioDioDioDioDio");
    // }.call();
  }
}
