import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showAppUpdateDialog(
    BuildContext context,) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF2D3748),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Update icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.system_update_alt,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Update Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),



            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (){Navigator.pop(context);},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      var url="";
                      if(Platform.isAndroid){
                        url="https://play.google.com/store/apps/details?id=shakir.kadakkadan.ffuiflutter";
                      }else{
                        url="https://apps.apple.com/us/app/ffmpeg-ai-assistant/id6748019690";
                      }
                      final Uri uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(fontWeight: FontWeight.bold),
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