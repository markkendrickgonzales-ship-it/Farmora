import 'dart:convert';
import 'dart:io';

// Simple HTTP test to check Supabase connectivity
void main() async {
  print('=== Simple Database Connection Test ===\n');
  
  const url = 'https://yqfhuzrvpzyswmmqhfic.supabase.co';
  const key = 'sb_publishable_lf14rk-115WV5RlVSt1KgA_M3Qt4hNq';
  
  print('Testing Supabase endpoint...');
  print('URL: $url');
  print('Key: ${key.substring(0, 20)}...\n');
  
  // Test farms table
  print('--- Testing farms table ---');
  try {
    final request = await HttpClient().getUrl(Uri.parse('$url/rest/v1/farms?select=*'));
    request.headers.add('apikey', key);
    request.headers.add('Authorization', 'Bearer $key');
    final response = await request.close();
    
    print('Response status: ${response.statusCode}');
    final content = await response.transform(utf8.decoder).join();
    print('Response body: $content');
    
    if (response.statusCode == 200) {
      print('✓ farms table is accessible');
      if (content == '[]') {
        print('⚠ WARNING: farms table is EMPTY');
      }
    } else {
      print('✗ farms table failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('✗ ERROR accessing farms: $e');
  }
  print('');
  
  // Test sensor_telemetry table
  print('--- Testing sensor_telemetry table ---');
  try {
    final request = await HttpClient().getUrl(Uri.parse('$url/rest/v1/sensor_telemetry?select=*&limit=5'));
    request.headers.add('apikey', key);
    request.headers.add('Authorization', 'Bearer $key');
    final response = await request.close();
    
    print('Response status: ${response.statusCode}');
    final content = await response.transform(utf8.decoder).join();
    print('Response body: $content');
    
    if (response.statusCode == 200) {
      print('✓ sensor_telemetry table is accessible');
      if (content == '[]') {
        print('⚠ WARNING: sensor_telemetry table is EMPTY');
      }
    } else {
      print('✗ sensor_telemetry table failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('✗ ERROR accessing sensor_telemetry: $e');
  }
  print('');
  
  // Test alerts table
  print('--- Testing alerts table ---');
  try {
    final request = await HttpClient().getUrl(Uri.parse('$url/rest/v1/alerts?select=*&limit=5'));
    request.headers.add('apikey', key);
    request.headers.add('Authorization', 'Bearer $key');
    final response = await request.close();
    
    print('Response status: ${response.statusCode}');
    final content = await response.transform(utf8.decoder).join();
    print('Response body: $content');
    
    if (response.statusCode == 200) {
      print('✓ alerts table is accessible');
      if (content == '[]') {
        print('⚠ WARNING: alerts table is EMPTY');
      }
    } else {
      print('✗ alerts table failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('✗ ERROR accessing alerts: $e');
  }
  print('');
  
  // Test feeding_logs table
  print('--- Testing feeding_logs table ---');
  try {
    final request = await HttpClient().getUrl(Uri.parse('$url/rest/v1/feeding_logs?select=*&limit=5'));
    request.headers.add('apikey', key);
    request.headers.add('Authorization', 'Bearer $key');
    final response = await request.close();
    
    print('Response status: ${response.statusCode}');
    final content = await response.transform(utf8.decoder).join();
    print('Response body: $content');
    
    if (response.statusCode == 200) {
      print('✓ feeding_logs table is accessible');
      if (content == '[]') {
        print('⚠ WARNING: feeding_logs table is EMPTY');
      }
    } else {
      print('✗ feeding_logs table failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('✗ ERROR accessing feeding_logs: $e');
  }
  print('');
  
  print('=== Test Complete ===');
}
