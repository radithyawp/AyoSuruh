import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {
  FeedbackService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get suggestedRole {
    final String mode = (_client.auth.currentUser?.userMetadata?['active_mode'] ??
            'customer')
        .toString()
        .toLowerCase();
    return mode == 'mitra' ? 'mitra' : 'customer';
  }

  Future<void> submit({
    required String role,
    required int easeRating,
    required int discoverabilityRating,
    required int uiRating,
    required String performance,
    required int trustRating,
    required List<String> usefulFeatures,
    required bool foundBug,
    String? bugDetails,
    String? liked,
    String? improvement,
    required int nps,
    required bool allowFollowup,
    String? contact,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Silakan login kembali sebelum mengirim masukan.');
    }

    await _client.rpc(
      'submit_app_feedback',
      params: <String, dynamic>{
        'p_role': role,
        'p_ease_rating': easeRating,
        'p_discoverability_rating': discoverabilityRating,
        'p_ui_rating': uiRating,
        'p_performance': performance,
        'p_trust_rating': trustRating,
        'p_useful_features': usefulFeatures,
        'p_found_bug': foundBug,
        'p_bug_details': foundBug ? bugDetails : null,
        'p_liked': liked,
        'p_improvement': improvement,
        'p_nps': nps,
        'p_allow_followup': allowFollowup,
        'p_contact': allowFollowup ? contact : null,
      },
    );
  }
}
