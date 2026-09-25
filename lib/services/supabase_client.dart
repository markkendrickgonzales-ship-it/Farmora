import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://yqfhuzrvpzyswmmqhfic.supabase.co';
const _supabaseAnonKey = 'sb_publishable_lf14rk-115WV5RlVSt1KgA_M3Qt4hNq';

/// Call once in [main] before [runApp].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
}

/// Shorthand accessor – use anywhere after [initSupabase] has run.
SupabaseClient get supabase => Supabase.instance.client;
