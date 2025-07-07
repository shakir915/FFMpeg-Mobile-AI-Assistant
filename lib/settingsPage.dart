import 'dart:io';

import 'package:ffuiflutter/main.dart';
import 'package:ffuiflutter/utils.dart';
import 'package:ffuiflutter/words.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Settingspage extends StatefulWidget {
  const Settingspage({super.key});

  @override
  State<Settingspage> createState() => _SettingspageState();
}

class _SettingspageState extends State<Settingspage> with TickerProviderStateMixin {
  var totalSizeOfDir = 0;
  bool showInitialPrompt = false;
  bool showRetryPrompt = false;
  bool showApiKey = false;

  late AnimationController _initialPromptController;
  late AnimationController _retryPromptController;
  late AnimationController _apiKeyController;
  late Animation<double> _initialPromptAnimation;
  late Animation<double> _retryPromptAnimation;
  late Animation<double> _apiKeyAnimation;
  final tecInitPrompt = TextEditingController();
  final tecRetryPrompt = TextEditingController();
  final tecApiKey = TextEditingController();

  @override
  void initState() {
    tecInitPrompt.text = initialPrompt;
    tecRetryPrompt.text = retryPrompt;
    tecApiKey.text = pref.getString("gemini_api_key") ?? "";

    super.initState();

    // Initialize animation controllers
    _initialPromptController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _retryPromptController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _apiKeyController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _initialPromptAnimation = CurvedAnimation(
      parent: _initialPromptController,
      curve: Curves.easeInOut,
    );
    _retryPromptAnimation = CurvedAnimation(
      parent: _retryPromptController,
      curve: Curves.easeInOut,
    );
    _apiKeyAnimation = CurvedAnimation(
      parent: _apiKeyController,
      curve: Curves.easeInOut,
    );

    refreshTotal();
  }

  Future<void> refreshTotal() async {
    try {
      totalSizeOfDir = await getDirectorySizeBytes();
      await waitForBuildIfPending();
      if (mounted) setState(() {});
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _initialPromptController.dispose();
    _retryPromptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 25),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),

            // API Configuration Section
            _buildSectionHeader('API Configuration', Icons.api),
            _buildSettingsTile(
              title: 'Gemini API Key',
              subtitle: showApiKey
                  ? 'Tap to collapse API key editor'
                  : tecApiKey.text.isEmpty
                  ? 'Tap to expand and set your Gemini API key'
                  : 'API key configured • Tap to edit',
              icon: Icons.key,
              iconColor: Colors.teal,
              onTap: () {
                setState(() {
                  showApiKey = !showApiKey;
                  if (showApiKey) {
                    _apiKeyController.forward();
                    // Close other expanded sections
                    if (showInitialPrompt) {
                      showInitialPrompt = false;
                      _initialPromptController.reverse();
                    }
                    if (showRetryPrompt) {
                      showRetryPrompt = false;
                      _retryPromptController.reverse();
                    }
                  } else {
                    _apiKeyController.reverse();
                  }
                });
              },
              trailing: AnimatedRotation(
                turns: showApiKey ? 0.5 : 0,
                duration: Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ),

            // API Key Input (Animated Expandable)
            SizeTransition(
              sizeFactor: _apiKeyAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildApiKeyInput(),
              ),
            ),

            SizedBox(height: 8),

            // Storage Management Section
            _buildSectionHeader('Storage Management', Icons.storage),
            _buildSettingsTile(
              title: 'Clear Chats and Storage',
              subtitle: totalSizeOfDir > 0
                  ? '${formatBytes(totalSizeOfDir)} used • Delete all data and files'
                  : 'No data to clear',
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              onTap: deleteDialog,
              trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ),

            SizedBox(height: 8),

            // AI Settings Section
            _buildSectionHeader('AI Settings', Icons.psychology),

            // Initial AI Prompt Setting
            _buildSettingsTile(
              title: 'Customize \'Initial AI Prompt\'',
              subtitle: showInitialPrompt
                  ? 'Tap to collapse prompt editor'
                  : 'Tap to expand and customize the initial prompt sent to AI',
              icon: Icons.edit_note,
              iconColor: Colors.blue,
              onTap: () {
                setState(() {
                  showInitialPrompt = !showInitialPrompt;
                  if (showInitialPrompt) {
                    _initialPromptController.forward();
                    // Close other expanded sections
                    if (showRetryPrompt) {
                      showRetryPrompt = false;
                      _retryPromptController.reverse();
                    }
                    if (showApiKey) {
                      showApiKey = false;
                      _apiKeyController.reverse();
                    }
                  } else {
                    _initialPromptController.reverse();
                  }
                });
              },
              trailing: AnimatedRotation(
                turns: showInitialPrompt ? 0.5 : 0,
                duration: Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ),

            // Initial Prompt Input (Animated Expandable)
            SizeTransition(
              sizeFactor: _initialPromptAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildPromptInput(
                  title: 'Initial AI Prompt Template',
                  onChanged: (value) {
                    tecInitPrompt.text = value;
                    pref.setString("initialPrompt", value);
                  },
                  controller: tecInitPrompt,
                  hintText: 'Enter your custom initial prompt for AI command generation...',
                ),
              ),
            ),

            SizedBox(height: 8),

            // Retry AI Prompt Setting
            _buildSettingsTile(
              title: 'Customize \'Retry AI Prompt\'',
              subtitle: showRetryPrompt
                  ? 'Tap to collapse prompt editor'
                  : 'Tap to expand and customize the prompt used when retrying failed commands',
              icon: Icons.refresh,
              iconColor: Colors.orange,
              onTap: () {
                setState(() {
                  showRetryPrompt = !showRetryPrompt;
                  if (showRetryPrompt) {
                    _retryPromptController.forward();
                    // Close other expanded sections
                    if (showInitialPrompt) {
                      showInitialPrompt = false;
                      _initialPromptController.reverse();
                    }
                    if (showApiKey) {
                      showApiKey = false;
                      _apiKeyController.reverse();
                    }
                  } else {
                    _retryPromptController.reverse();
                  }
                });
              },
              trailing: AnimatedRotation(
                turns: showRetryPrompt ? 0.5 : 0,
                duration: Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ),

            // Retry Prompt Input (Animated Expandable)
            SizeTransition(
              sizeFactor: _retryPromptAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildPromptInput(
                  title: 'Retry AI Prompt Template',
                  onChanged: (value) {
                    tecRetryPrompt.text = value;
                    pref.setString("retryPrompt", value);
                  },
                  controller: tecRetryPrompt,
                  hintText: 'Enter your custom retry prompt for failed commands...',
                ),
              ),
            ),

            SizedBox(height: 8),

            // Reset Prompts Option
            _buildSettingsTile(
              title: 'Reset All Prompts',
              subtitle: 'Restore default AI prompt configurations',
              icon: Icons.restore,
              iconColor: Colors.purple,
              onTap: _resetPromptsDialog,
              trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF68D391), size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF68D391),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? Colors.blue).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? Colors.blue,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor ?? Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  var obscureText=true;

  Widget _buildApiKeyInput() {
    return Card(
      color: const Color(0xFF2D3748),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.key, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gemini API Key',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: tecApiKey,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 13,
              ),
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: 'Enter your Gemini API key...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4A5568)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4A5568)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal),
                ),
                filled: true,
                fillColor: Color(0xFF1A202C),
                contentPadding: EdgeInsets.all(12),
                suffixIcon: IconButton(
                  icon: Icon(Icons.visibility_off, color: Colors.grey[400]),
                  onPressed: () {
                    // Toggle visibility logic would go here
                    setState(() {
                      obscureText=!obscureText;
                    });
                  },
                ),
              ),
              onChanged: (value) {
                if(value.trim().isEmpty){
                  pref.remove("gemini_api_key");
                }else{
                  pref.setString("gemini_api_key", value);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Get your API key from Google AI Studio (ai.google.dev). Your key is stored securely on your device.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptInput({
    required String title,
    required Function(String) onChanged,
    String? hintText,
    TextEditingController? controller,
  }) {
    return Card(
      color: const Color(0xFF2D3748),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: const Color(0xFF68D391), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 13,
              ),
              maxLines: null,
              minLines: 5,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                contentPadding: EdgeInsets.all(12),
              ),
              onChanged: onChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Use placeholders: \$YOUR_PROMPT_HERE, \$YOUR_INPUT_FILES_HERE, \$YOUR_OUTPUT_DIRECTORY_HERE, \$YOUR_INPUT_FILES_DETAILS_HERE, \$YOUR_ERROR_LOGS_HERE, \$YOUR_FAILED_COMMAND_HERE',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetPromptsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.restore, color: Colors.purple, size: 28),
              SizedBox(width: 12),
              Text(
                'Reset All Prompts',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will reset the following to defaults:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Initial AI prompt template', style: TextStyle(color: Colors.grey[300])),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.refresh, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Retry AI prompt template', style: TextStyle(color: Colors.grey[300])),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.purple, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your custom prompts will be lost!',
                        style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w500),
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
              onPressed: () {
                Navigator.of(context).pop();
                _resetPrompts();
              },
              icon: Icon(Icons.restore, size: 18),
              label: Text('Reset All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetPrompts() async {
    setState(() {
      showInitialPrompt = false;
      showRetryPrompt = false;
    });

    // Animate collapse if expanded
    _initialPromptController.reverse();
    _retryPromptController.reverse();

    // Reset to default prompts
    await pref.remove("initialPrompt");
    await pref.remove("retryPrompt");
    tecInitPrompt.text = initialPrompt;
    tecRetryPrompt.text = retryPrompt;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All prompts reset to defaults'),
        backgroundColor: Colors.purple,
      ),
    );
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
                pref.setBool("data_cleared_restart_required", true);
                refreshTotal();
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

    return totalSize;
  }
}