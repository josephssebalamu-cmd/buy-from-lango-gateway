import 'dart:collection';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telephony/telephony.dart';

class SmsSender {
  static final Queue<_PendingDeliveryReport> _pendingDeliveryReports =
      Queue<_PendingDeliveryReport>();

  Future<void> sendSms({
    required String to,
    required String message,
    Object? smsLogId,
    int? subscriptionId,
  }) async {
    final pendingReport = _PendingDeliveryReport(smsLogId);
    _pendingDeliveryReports.addLast(pendingReport);
    try {
      await Telephony.instance.sendSms(
        to: to,
        message: message,
        isMultipart: true,
        subscriptionId: subscriptionId,
        statusListener: _handleSendStatus,
      );
    } catch (_) {
      _pendingDeliveryReports.remove(pendingReport);
      rethrow;
    }
  }

  static void _handleSendStatus(SendStatus status) {
    if (status != SendStatus.DELIVERED || _pendingDeliveryReports.isEmpty) {
      return;
    }

    final report = _pendingDeliveryReports.removeFirst();
    final smsLogId = report.smsLogId;
    if (smsLogId != null) {
      unawaited(_markDelivered(smsLogId));
    }
  }

  static Future<void> _markDelivered(Object smsLogId) async {
    try {
      await Supabase.instance.client
          .from('sms_log')
          .update({'status': 'delivered'})
          .eq('id', smsLogId);
    } catch (error, stackTrace) {
      debugPrint('Failed to save SMS delivery report: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _PendingDeliveryReport {
  const _PendingDeliveryReport(this.smsLogId);

  final Object? smsLogId;
}
