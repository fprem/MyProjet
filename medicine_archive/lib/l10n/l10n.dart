import 'package:flutter/widgets.dart';

import '../data/backup.dart';
import '../data/tags.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// The languages the app is written in. English is also the fallback for
/// any other phone language.
const appLocales = AppLocalizations.supportedLocales;

extension L10nContext on BuildContext {
  /// The app's text in the phone's language. English when the widget is
  /// shown outside the app (as in some tests).
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}

/// The app's text for the phone's language, for the moments before the app
/// is on screen (the unlock prompt, a start-up error).
AppLocalizations systemL10n() {
  final locales = WidgetsBinding.instance.platformDispatcher.locales;
  for (final locale in locales) {
    if (AppLocalizations.delegate.isSupported(Locale(locale.languageCode))) {
      return lookupAppLocalizations(Locale(locale.languageCode));
    }
  }
  return lookupAppLocalizations(const Locale('en'));
}

extension TagText on AppLocalizations {
  /// What the person sees for [tag]: the time of day, or their own tag as typed.
  String tag(String tag) => switch (tag) {
    MedicineTags.morning => tagMorning,
    MedicineTags.noon => tagNoon,
    MedicineTags.evening => tagEvening,
    _ => tag,
  };

  /// What the person sees for a group: [tag], or "No tag" for null.
  String group(String? tag) => tag == null ? noTag : this.tag(tag);

  /// Why a backup couldn't be opened.
  String backupProblem(BackupException e) => switch (e.problem) {
    BackupProblem.notBackup => backupNotBackup,
    BackupProblem.wrongPassword => backupWrongPassword,
    BackupProblem.damaged => backupDamaged,
  };
}
