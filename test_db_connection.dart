import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://yqfhuzrvpzyswmmqhfic.supabase.co';
const _supabaseAnonKey = 'sb_publishable_lf14rk-115WV5RlVSt1KgA_M3Qt4hNq';

Future<void> main() async {
  print('=== Database Connection Test ===\n');
  
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    print('✓ Supabase initialized successfully\n');
    
    final supabase = Supabase.instance.client;
    
    // Test 1: Check farms table
    print('--- Testing farms table ---');
    try {
      final farms = await supabase.from('farms').select();
      print('✓ Farms table accessible');
      print('  Number of farms: ${farms.length}');
      if (farms.isNotEmpty) {
        print('  First farm: ${farms.first}');
      } else {
        print('  ⚠ WARNING: farms table is empty');
      }
    } catch (e) {
      print('✗ ERROR accessing farms table: $e');
    }
    print('');
    
    // Test 2: Check sensor_telemetry table
    print('--- Testing sensor_telemetry table ---');
    try {
      final telemetry = await supabase.from('sensor_telemetry').select().limit(5);
      print('✓ sensor_telemetry table accessible');
      print('  Number of records (sample): ${telemetry.length}');
      if (telemetry.isNotEmpty) {
        print('  First record: ${telemetry.first}');
        print('  Expected columns: farm_id, recorded_at, temperature_c, humidity_percent, power_load_kw, ammonia_ppm');
      } else {
        print('  ⚠ WARNING: sensor_telemetry table is empty');
      }
    } catch (e) {
      print('✗ ERROR accessing sensor_telemetry table: $e');
    }
    print('');
    
    // Test 3: Check alerts table
    print('--- Testing alerts table ---');
    try {
      final alerts = await supabase.from('alerts').select().limit(5);
      print('✓ alerts table accessible');
      print('  Number of alerts (sample): ${alerts.length}');
      if (alerts.isNotEmpty) {
        print('  First alert: ${alerts.first}');
        print('  Expected columns: farm_id, triggered_at, severity, alert_type');
      } else {
        print('  ⚠ WARNING: alerts table is empty');
      }
    } catch (e) {
      print('✗ ERROR accessing alerts table: $e');
    }
    print('');
    
    // Test 4: Check feeding_logs table
    print('--- Testing feeding_logs table ---');
    try {
      final logs = await supabase.from('feeding_logs').select().limit(5);
      print('✓ feeding_logs table accessible');
      print('  Number of logs (sample): ${logs.length}');
      if (logs.isNotEmpty) {
        print('  First log: ${logs.first}');
        print('  Expected columns: farm_id, action_time, amount, unit, action_type');
      } else {
        print('  ⚠ WARNING: feeding_logs table is empty');
      }
    } catch (e) {
      print('✗ ERROR accessing feeding_logs table: $e');
    }
    print('');
    
    // Test 5: Check if we can query with farm_id
    print('--- Testing farm_id relationship ---');
    try {
      final farms = await supabase.from('farms').select();
      if (farms.isNotEmpty) {
        final farmId = farms.first['farm_id'];
        print('✓ Using farm_id: $farmId');
        
        final telemetry = await supabase
            .from('sensor_telemetry')
            .select()
            .eq('farm_id', farmId)
            .limit(1);
        print('  Telemetry for this farm: ${telemetry.length} records');
        
        final alerts = await supabase
            .from('alerts')
            .select()
            .eq('farm_id', farmId)
            .limit(1);
        print('  Alerts for this farm: ${alerts.length} records');
      } else {
        print('⚠ Cannot test relationships - no farms found');
      }
    } catch (e) {
      print('✗ ERROR testing farm_id relationship: $e');
    }
    print('');
    
    print('=== Test Complete ===');
    
  } catch (e) {
    print('✗ FATAL ERROR: $e');
    print('This usually means:');
    print('  1. Invalid Supabase URL or key');
    print('  2. Network connectivity issues');
    print('  3. Supabase project is paused or deleted');
  }
}
