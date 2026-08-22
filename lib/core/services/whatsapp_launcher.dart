import 'package:url_launcher/url_launcher.dart';

/// Deep-links to WhatsApp with a pre-filled message via `wa.me`, per the
/// resolution documented in REQUIREMENTS.md §11/§12 item 7 — no WhatsApp
/// Business API needed for the "one-click reminder" features (§6.6, §7.8).
class WhatsappLauncher {
  WhatsappLauncher._();

  /// [phone] should be digits only, with country code (e.g. "9198450XXXXX").
  /// If omitted, opens WhatsApp with the message ready to send to any chat.
  static Future<bool> open({String? phone, required String message}) {
    final encoded = Uri.encodeComponent(message);
    final uri = phone != null && phone.isNotEmpty
        ? Uri.parse('https://wa.me/$phone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
