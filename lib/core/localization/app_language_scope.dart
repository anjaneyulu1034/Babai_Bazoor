import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';

class AppLanguageScope extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  const AppLanguageScope({
    super.key,
    required ValueNotifier<AppLanguage> notifier,
    required this.onChanged,
    required super.child,
  }) : super(notifier: notifier);

  final ValueChanged<AppLanguage> onChanged;

  static AppLanguageScope _lookup(BuildContext context, {required bool watch}) {
    if (watch) {
      final scope = context
          .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
      assert(scope != null, 'AppLanguageScope not found in widget tree.');
      return scope!;
    }

    final element = context
        .getElementForInheritedWidgetOfExactType<AppLanguageScope>();
    final scope = element?.widget as AppLanguageScope?;
    assert(scope != null, 'AppLanguageScope not found in widget tree.');
    return scope!;
  }

  static AppLanguage watch(BuildContext context) {
    return _lookup(context, watch: true).notifier!.value;
  }

  static AppLanguage of(BuildContext context) {
    return _lookup(context, watch: false).notifier!.value;
  }

  static void update(BuildContext context, AppLanguage language) {
    _lookup(context, watch: false).onChanged(language);
  }
}
