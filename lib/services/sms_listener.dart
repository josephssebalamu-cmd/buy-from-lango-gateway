import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:telephony/telephony.dart';

import '../supabase_config.dart';
import 'command_parser.dart';
import 'sms_sender.dart';

final Uri _smsWebhookUri = Uri.parse('$supabaseUrl/functions/v1/sms-webhook');
bool _isListening = false;

class SmsListener {
  void startListening() {
    if (_isListening) return;
    _isListening = true;
    initializeSmsListener();
  }
}

void initializeSmsListener() {
  Telephony.instance.listenIncomingSms(
    onNewMessage: (message) => unawaited(_handleIncomingSms(message)),
    onBackgroundMessage: onBackgroundMessage,
  );
}

@pragma('vm:entry-point')
Future<void> onBackgroundMessage(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _handleIncomingSms(message);
}

Future<void> _handleIncomingSms(SmsMessage message) async {
  try {
    final from = message.address?.trim();
    final body = message.body?.trim();
    final subscriptionId = message.subscriptionId;
    if (smsWebhookToken.isEmpty) {
      throw StateError('The SMS webhook token is not configured.');
    }
    if (subscriptionId == null || subscriptionId < 0) {
      throw StateError('The incoming SMS SIM could not be identified.');
    }
    if (from == null || from.isEmpty || body == null || body.isEmpty) {
      throw StateError('Received an SMS without a sender or message body.');
    }

    final response = await http.post(
      _smsWebhookUri,
      headers: {
        'apikey': supabaseAnonKey,
        'x-sms-gateway-token': smsWebhookToken,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'phone': from, 'message': body}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'SMS Edge Function returned HTTP ${response.statusCode}.',
      );
    }

    final reply = CommandParser().parseReply(response.body);
    if (reply.isEmpty) return;
    await SmsSender().sendSms(
      to: from,
      message: reply,
      subscriptionId: subscriptionId,
    );
  } catch (error, stackTrace) {
    debugPrint('Failed to process incoming SMS: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
