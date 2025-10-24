import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_provider.dart';
import '../config.dart';
import '../models/settings.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await http.get(Uri.parse(Config.settingsEndpoint));
      if (response.statusCode == 200) {
        setState(() {
          _settings = AppSettings.fromJson(jsonDecode(response.body));
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _shareApp() {
  final playStoreUrl = _settings?.playStoreUrl ??
      'https://immradio.online'; // fallback link
  final shareText =
      '💞 Check out the Intentional Marriage Ministries app! Strengthen your family with faith and truth. '
      'Download now: $playStoreUrl';
  Share.share(shareText, subject: 'Intentional Marriage Ministries App');
}


  void _showAboutDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _settings?.appIconUrl != null &&
                    _settings!.appIconUrl!.isNotEmpty
                ? Image.network(
                    _settings!.appIconUrl!,
                    width: 48,
                    height: 48,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.info_outline, size: 48),
                  )
                : const Icon(Icons.info_outline, size: 48),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Intentional Marriage Ministries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              _settings?.aboutUs?.isNotEmpty == true
                  ? _settings!.aboutUs!
                  : 'No About Us information available.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2025 Intentional Marriage Ministries',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}


  void _contactFeedback() async {
  final email = _settings?.contactEmail ?? 'info@immradio.online';
  final phone = _settings?.contactPhone;

  final Uri emailLaunchUri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {
      'subject': 'Feedback - Intentional Marriage Ministries App',
      'body':
          'Hello Intentional Marriage Ministries Team,\n\nI would like to share the following feedback:\n\n',
    },
  );

  try {
    final canLaunchEmail = await canLaunchUrl(emailLaunchUri);

    if (canLaunchEmail) {
      await launchUrl(emailLaunchUri);
    } else {
      // fallback if mail app not available or not launching
      String message = 'Send us your feedback at: $email';
      if (phone != null && phone.isNotEmpty) {
        message += '\n\nOr call us at: $phone';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Contact Us'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await launchUrl(emailLaunchUri,
                      mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not open email app: $e');
                }
              },
              child: const Text('OPEN EMAIL APP'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    debugPrint('Error launching email: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  "Appearance",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        title: const Text("Light Mode"),
                        value: false,
                        groupValue: isDark,
                        activeColor: Colors.redAccent,
                        onChanged: (value) {
                          if (value == false) themeProvider.setLightMode();
                        },
                      ),
                      const Divider(height: 0),
                      RadioListTile<bool>(
                        title: const Text("Dark Mode"),
                        value: true,
                        groupValue: isDark,
                        activeColor: Colors.redAccent,
                        onChanged: (value) {
                          if (value == true) themeProvider.setDarkMode();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "App",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.share, color: Colors.redAccent),
                        title: const Text("Share this App"),
                        onTap: _shareApp,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.info_outline,
                            color: Colors.redAccent),
                        title: const Text("About Us"),
                        onTap: _showAboutDialog,
                      ),
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(Icons.mail_outline,
                            color: Colors.redAccent),
                        title: const Text("Contact / Feedback"),
                        onTap: _contactFeedback,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    "Version 1.0.0",
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
