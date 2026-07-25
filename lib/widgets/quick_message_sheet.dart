import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a bottom sheet of canned quick messages that get sent to
/// [phone] as an SMS. Used for "Chat" actions on the store/delivery
/// screens where there is no in-app chat channel.
Future<void> showQuickMessageSheet(
  BuildContext context, {
  required String? phone,
  required String recipientLabel,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _QuickMessageSheet(
      phone: phone,
      recipientLabel: recipientLabel,
    ),
  );
}

const _quickMessages = [
  'I have reached at location',
  'Are you coming?',
  'Waiting at pickup',
  'My location is as per map',
  'Message when you reach',
];

Future<void> _sendSms(String phone, String body) async {
  final uri = Platform.isIOS
      ? Uri.parse('sms:$phone&body=${Uri.encodeComponent(body)}')
      : Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

class _QuickMessageSheet extends StatelessWidget {
  final String? phone;
  final String recipientLabel;

  const _QuickMessageSheet({required this.phone, required this.recipientLabel});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Message $recipientLabel',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone == null
                  ? 'No phone number available yet'
                  : 'Send a quick message via SMS',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            for (final msg in _quickMessages) ...[
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFFB1B1B1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: phone == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _sendSms(phone!, msg);
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          msg,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
