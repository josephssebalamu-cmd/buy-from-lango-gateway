import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sms_sender.dart';

class PollingService {
  PollingService({SupabaseClient? client, SmsSender? smsSender})
    : _client = client ?? Supabase.instance.client,
      _smsSender = smsSender ?? SmsSender();

  final SupabaseClient _client;
  final SmsSender _smsSender;
  Timer? _timer;
  bool _isPolling = false;

  void start() {
    if (_timer != null) return;

    unawaited(_pollQueuedMessages());
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_pollQueuedMessages()),
    );
  }

  void startPolling() => start();

  Future<void> _pollQueuedMessages() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      await Future.wait([
        _pollSmsLogQueue(),
        _pollChatSmsQueue(),
        _pollSellerPhoneQueue(),
      ]);
    } catch (error, stackTrace) {
      debugPrint('Failed to poll queued SMS jobs: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _pollSmsLogQueue() async {
    try {
      final queuedMessages = await _client
          .from('sms_log')
          .select('id,phone,message')
          .eq('direction', 'outbound')
          .eq('status', 'queued')
          .order('created_at');

      for (final queuedMessage in queuedMessages) {
        try {
          await _sendQueuedMessage(queuedMessage);
        } catch (error, stackTrace) {
          debugPrint('Failed to process queued SMS: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to poll queued SMS messages: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _pollChatSmsQueue() async {
    try {
      final jobs = await _client.rpc(
        'claim_chat_sms',
        params: {'p_batch_size': 20},
      ) as List<dynamic>?;

      if (jobs == null || jobs.isEmpty) {
        return;
      }

      for (final rawJob in jobs) {
        if (rawJob is! Map) {
          continue;
        }

        final job = Map<String, dynamic>.from(rawJob);
        final queueId = job['queue_id'];
        final recipientPhone = (job['recipient_phone'] ?? '').toString();
        final messageBody = (job['message_body'] ?? '').toString();

        if (queueId == null || recipientPhone.isEmpty || messageBody.isEmpty) {
          await _finishChatSms(queueId, false, 'Chat SMS job payload is incomplete.');
          continue;
        }

        try {
          await _smsSender.sendSms(to: recipientPhone, message: messageBody);
          await _finishChatSms(queueId, true, null);
        } catch (error, stackTrace) {
          debugPrint('Failed to send chat SMS $queueId: $error');
          debugPrintStack(stackTrace: stackTrace);
          await _finishChatSms(
            queueId,
            false,
            error.toString(),
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to poll chat SMS jobs: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _pollSellerPhoneQueue() async {
    try {
      final jobs = await _client.rpc(
        'claim_seller_phone_sms',
        params: {'p_batch_size': 20},
      ) as List<dynamic>?;

      if (jobs == null || jobs.isEmpty) {
        return;
      }

      for (final rawJob in jobs) {
        if (rawJob is! Map) {
          continue;
        }

        final job = Map<String, dynamic>.from(rawJob);
        final queueId = job['queue_id'];
        final orderId = job['order_id'];
        final buyerId = job['buyer_id'];
        final sellerId = job['seller_id'];

        if (queueId == null || orderId == null || buyerId == null || sellerId == null) {
          await _finishSellerPhoneSms(queueId, false, 'Seller phone job payload is incomplete.');
          continue;
        }

        try {
          final buyerProfile = await _client
              .from('profiles')
              .select('phone')
              .eq('id', buyerId)
              .maybeSingle();
          final sellerProfile = await _client
              .from('profiles')
              .select('phone')
              .eq('id', sellerId)
              .maybeSingle();

          final buyerPhone = (buyerProfile?['phone'] ?? '').toString();
          final sellerPhone = (sellerProfile?['phone'] ?? '').toString();
          if (buyerPhone.isEmpty || sellerPhone.isEmpty) {
            throw StateError('A buyer or seller phone number is unavailable.');
          }

          final message =
              'The seller for your accepted Buy From Lango offer (Order #$orderId) can be reached at $sellerPhone.';

          await _smsSender.sendSms(to: buyerPhone, message: message);
          await _finishSellerPhoneSms(queueId, true, null);
        } catch (error, stackTrace) {
          debugPrint('Failed to send seller phone SMS $queueId: $error');
          debugPrintStack(stackTrace: stackTrace);
          await _finishSellerPhoneSms(
            queueId,
            false,
            error.toString(),
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to poll seller phone SMS jobs: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _sendQueuedMessage(Map<String, dynamic> queuedMessage) async {
    final id = queuedMessage['id'];
    final phone = queuedMessage['phone']?.toString();
    final message = queuedMessage['message']?.toString();
    if (id == null || phone == null || phone.isEmpty || message == null) {
      if (id != null) {
        await _updateStatus(id, 'failed');
      }
      throw StateError('Queued SMS row is missing id, phone, or message.');
    }

    try {
      await _smsSender.sendSms(to: phone, message: message, smsLogId: id);
    } catch (error, stackTrace) {
      await _updateStatus(id, 'failed');
      debugPrint('Failed to send queued SMS $id: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }

    await _updateStatus(id, 'sent');
  }

  Future<void> _updateStatus(Object id, String status) async {
    await _client.from('sms_log').update({'status': status}).eq('id', id);
  }

  Future<void> _finishChatSms(Object? queueId, bool success, String? error) async {
    if (queueId == null) return;

    await _client.rpc(
      'finish_chat_sms',
      params: {
        'p_queue_id': queueId,
        'p_success': success,
        'p_error': success ? null : (error ?? 'SMS delivery failed.'),
      },
    );
  }

  Future<void> _finishSellerPhoneSms(
    Object? queueId,
    bool success,
    String? error,
  ) async {
    if (queueId == null) return;

    await _client.rpc(
      'finish_seller_phone_sms',
      params: {
        'p_queue_id': queueId,
        'p_success': success,
        'p_error': success ? null : (error ?? 'SMS delivery failed.'),
      },
    );
  }
}
