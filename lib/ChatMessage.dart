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
  final String? vidInfo;
  final bool isEditable;
  bool isProcessing;
  String? outDir;

  List<String> logs;
  List<String>? pathFakes;
  List<String>? pathOriginal;


  var isLogsDisplayed = false;

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
    this.pathOriginal,
    this.pathFakes,
    this.vidInfo,

    this.logs = const [],

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
      'isProcessing': isProcessing,
      'logs': logs,
      'pathOriginal': pathOriginal,
      'pathFakes': pathFakes,
      'vidInfo': vidInfo,
      // You might want to store the path as a string if needed
    };
  }

  // Create ChatMessage from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {

   List<String>  pathOriginal=[];
   try {
     pathOriginal=json.containsKey('pathOriginal') ? (json['pathOriginal'] as List<dynamic>).cast<String>() : [];
   } catch (e, s) {
     print(s);
   }

   List<String>  pathFakes=[];
   try {
     pathFakes=json.containsKey('pathFakes') ? (json['pathFakes'] as List<dynamic>).cast<String>() : [];
   } catch (e, s) {
     print(s);
   }

   List<String>  logs=[];
   try {
     logs=json.containsKey('logs') ? (json['logs'] as List<dynamic>).cast<String>() : [];
   } catch (e, s) {
     print(s);
   }



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
      vidInfo: json['vidInfo'] as String?,

      isEditable: json['isEditable'] as bool? ?? false,
      isProcessing: json['isProcessing'] as bool? ?? false,
      logs: logs,
      pathOriginal: pathOriginal,
      pathFakes: pathFakes,

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
