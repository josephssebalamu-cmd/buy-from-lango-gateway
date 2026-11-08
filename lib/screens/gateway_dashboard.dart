import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GatewayDashboard extends StatefulWidget {
  const GatewayDashboard({super.key, this.supabaseReady});

  final Future<void>? supabaseReady;

  @override
  State<GatewayDashboard> createState() => _GatewayDashboardState();
}

class _GatewayDashboardState extends State<GatewayDashboard>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool? _databaseConnected;
  bool? _serviceRunning;
  PermissionStatus? _smsPermission;
  PermissionStatus? _notificationPermission;
  PermissionStatus? _batteryOptimizationPermission;
  int? _queuedCount;
  int? _sentCount;
  int? _deliveredCount;
  int? _failedCount;
  List<Map<String, dynamic>> _recentMessages = const [];
  String? _loadError;
  final TextEditingController _activeSimPhoneController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeSimPhoneController.text = '+234';
    unawaited(_refreshDashboard());
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _activeSimPhoneController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshDashboard());
      _startRefreshTimer();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshDashboard()),
    );
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing || widget.supabaseReady == null) return;
    _isRefreshing = true;

    try {
      await widget.supabaseReady;
      final client = Supabase.instance.client;
      final messages = await client
          .from('sms_log')
          .select('id,phone,message,direction,status,created_at')
          .order('created_at', ascending: false)
          .limit(30);
      final outboundStatuses = messages
          .where((message) => message['direction'] == 'outbound')
          .map((message) => message['status']?.toString())
          .toList();
      final queuedCount = outboundStatuses
          .where((status) => status == 'queued')
          .length;
      final sentCount = outboundStatuses
          .where((status) => status == 'sent')
          .length;
      final deliveredCount = outboundStatuses
          .where((status) => status == 'delivered')
          .length;
      final failedCount = outboundStatuses
          .where((status) => status == 'failed')
          .length;
      final serviceRunningFuture = FlutterBackgroundService().isRunning();
      final smsPermissionFuture = Permission.sms.status;
      final notificationPermissionFuture = Permission.notification.status;
      final batteryPermissionFuture =
          Permission.ignoreBatteryOptimizations.status;
      final deviceStatus = await Future.wait<Object>([
        serviceRunningFuture,
        smsPermissionFuture,
        notificationPermissionFuture,
        batteryPermissionFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _serviceRunning = deviceStatus[0] as bool;
        _smsPermission = deviceStatus[1] as PermissionStatus;
        _notificationPermission = deviceStatus[2] as PermissionStatus;
        _batteryOptimizationPermission = deviceStatus[3] as PermissionStatus;
        _databaseConnected = true;
        _queuedCount = queuedCount;
        _sentCount = sentCount;
        _deliveredCount = deliveredCount;
        _failedCount = failedCount;
        _recentMessages = messages;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _databaseConnected = false;
        _loadError = error.toString();
      });
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Gateway'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _isRefreshing ? null : _refreshDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  semanticLabel: 'Buy From Lango logo',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buy From Lango', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('SMS Gateway', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Gateway status', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vivo background settings',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For more reliable background operation, enable Auto-Start '
                      'for Lango SMS Gateway, allow high background power use '
                      'in Battery settings, and lock the app in the recent-apps '
                      'screen if your Vivo model offers that option. Menu names '
                      'vary by Funtouch OS version. Battery restrictions can '
                      'still affect background activity.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusIndicator(
                  label: 'Background service',
                  isHealthy: _serviceRunning,
                ),
                _StatusIndicator(
                  label: 'Supabase connection',
                  isHealthy: _databaseConnected,
                ),
                _StatusIndicator(
                  label: 'SMS permission',
                  isHealthy: _smsPermission?.isGranted,
                  healthyText: 'Granted',
                ),
                _StatusIndicator(
                  label: 'Notifications',
                  isHealthy: _notificationPermission?.isGranted,
                  healthyText: 'Allowed',
                ),
                _StatusIndicator(
                  label: 'Battery unrestricted',
                  isHealthy: _batteryOptimizationPermission?.isGranted,
                  healthyText: 'Enabled',
                ),
              ],
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _loadError!),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active SIM card phone number',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _activeSimPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '+2348012345678',
                        labelText: 'SIM phone number',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Outbound delivery report', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _SummaryCard(label: 'Queued', count: _queuedCount),
                _SummaryCard(label: 'Sent', count: _sentCount),
                _SummaryCard(label: 'Delivered', count: _deliveredCount),
                _SummaryCard(label: 'Failed', count: _failedCount),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Queue checks run every 10 seconds. Counts reflect the latest 30 log entries.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Recent SMS activity', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_recentMessages.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _databaseConnected == false
                        ? 'SMS activity is unavailable while disconnected.'
                        : 'No SMS activity recorded yet.',
                  ),
                ),
              )
            else
              ..._recentMessages.map(
                (message) => _SmsLogTile(message: message),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.label,
    required this.isHealthy,
    this.healthyText = 'Connected',
  });

  final String label;
  final bool? isHealthy;
  final String healthyText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isHealthy == null
        ? colorScheme.outline
        : isHealthy!
        ? Colors.green.shade700
        : colorScheme.error;
    final stateText = isHealthy == null
        ? 'Checking'
        : isHealthy!
        ? healthyText
        : 'Needs attention';

    return Chip(
      avatar: Icon(
        isHealthy == null
            ? Icons.hourglass_empty
            : isHealthy!
            ? Icons.check_circle
            : Icons.warning,
        size: 18,
        color: color,
      ),
      label: Text('$label: $stateText'),
    );
  }
}

class _SmsLogTile extends StatelessWidget {
  const _SmsLogTile({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final direction = message['direction']?.toString() ?? 'unknown';
    final status = message['status']?.toString() ?? 'unknown';
    final phone = message['phone']?.toString() ?? 'Unknown number';
    final body = message['message']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      message['created_at']?.toString() ?? '',
    );

    return Card(
      child: ListTile(
        leading: Icon(
          direction == 'inbound' ? Icons.call_received : Icons.call_made,
        ),
        title: Text(phone),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActivityStatusChip(
                  label: direction.toUpperCase(),
                  status: direction,
                ),
                _ActivityStatusChip(
                  label: status.toUpperCase(),
                  status: status,
                ),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    return '$date $time';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              count?.toString() ?? '—',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStatusChip extends StatelessWidget {
  const _ActivityStatusChip({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase();
    final color = switch (normalizedStatus) {
      'delivered' || 'inbound' => Colors.green.shade100,
      'sent' => Colors.blue.shade100,
      'queued' => Colors.orange.shade100,
      'failed' => Theme.of(context).colorScheme.errorContainer,
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    };

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Could not refresh SMS data: $message'),
      ),
    );
  }
}
