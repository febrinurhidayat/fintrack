
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/profile_repository.dart';

// Repository provider.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

// Profile data provider.
final profileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfile();
});
