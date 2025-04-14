import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Helper extension to quickly access the Supabase client instance.
extension SupabaseClientGetter on BuildContext {
  /// The Supabase client instance.
  SupabaseClient get supabase => Supabase.instance.client;
} 