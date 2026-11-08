import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://ospfxilvkgkamcgjluzb.supabase.co';
const String supabaseAnonKey = 'sb_publishable_6Ect8lCkb8L-SgivCG-7LgZdOgUogz';
const String smsWebhookToken = String.fromEnvironment('SMS_WEBHOOK_TOKEN');

class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = supabaseUrl;
  static const String publishableKey = supabaseAnonKey;
  static const String anonKey = publishableKey;
}

bool _supabaseInitialized = false;

Future<void> ensureSupabaseInitialized() async {
  if (_supabaseInitialized) {
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  _supabaseInitialized = true;
}
