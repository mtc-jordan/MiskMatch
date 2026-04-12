import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miskmatch/core/storage/secure_storage.dart';

/// Persisted app locale. Null means "follow system".
/// Saved as an IETF tag (`en`, `ar`) in secure storage.

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._storage) : super(null) {
    _restore();
  }

  final SecureStorage _storage;

  static const _supported = {'en', 'ar'};

  Future<void> _restore() async {
    final tag = await _storage.getLocale();
    if (tag != null && _supported.contains(tag)) {
      state = Locale(tag);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await _storage.saveLocale('');
      state = null;
      return;
    }
    if (!_supported.contains(locale.languageCode)) return;
    await _storage.saveLocale(locale.languageCode);
    state = locale;
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref.watch(secureStorageProvider));
});
