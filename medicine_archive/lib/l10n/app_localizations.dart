import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('it')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine Archive'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @cantBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get cantBeUndone;

  /// No description provided for @newProfile.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newProfile;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get importBackup;

  /// No description provided for @noProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet'**
  String get noProfilesTitle;

  /// No description provided for @noProfilesMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a profile for each person whose medicines you keep.'**
  String get noProfilesMessage;

  /// No description provided for @importABackup.
  ///
  /// In en, this message translates to:
  /// **'Import a backup'**
  String get importABackup;

  /// No description provided for @profilesHeading.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesHeading;

  /// No description provided for @medicineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medicine} other{{count} medicines}}'**
  String medicineCount(int count);

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @checkMedicine.
  ///
  /// In en, this message translates to:
  /// **'Check medicine'**
  String get checkMedicine;

  /// No description provided for @editMedicine.
  ///
  /// In en, this message translates to:
  /// **'Edit medicine'**
  String get editMedicine;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get addMedicine;

  /// No description provided for @fromBarcodeFound.
  ///
  /// In en, this message translates to:
  /// **'From the barcode: AIC {aic}, found in AIFA\'s medicine list.'**
  String fromBarcodeFound(String aic);

  /// No description provided for @couldntReadLabel.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the label. Please type it in.'**
  String get couldntReadLabel;

  /// No description provided for @fromBarcodeInPhoto.
  ///
  /// In en, this message translates to:
  /// **'From the barcode in the photo: AIC {aic}, found in AIFA\'s medicine list.'**
  String fromBarcodeInPhoto(String aic);

  /// No description provided for @barcodeNotInList.
  ///
  /// In en, this message translates to:
  /// **'The barcode (AIC {aic}) isn\'t in AIFA\'s list, so the text in the photo was read.'**
  String barcodeNotInList(String aic);

  /// No description provided for @readFromText.
  ///
  /// In en, this message translates to:
  /// **'Read from the text in the photo. Check it and fix anything that is wrong.'**
  String get readFromText;

  /// No description provided for @photoDeleted.
  ///
  /// In en, this message translates to:
  /// **'The photo has been deleted.'**
  String get photoDeleted;

  /// No description provided for @photoDeletedOnSave.
  ///
  /// In en, this message translates to:
  /// **'The photo is deleted when you save, unless you keep it.'**
  String get photoDeletedOnSave;

  /// No description provided for @medicineSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} saved'**
  String medicineSaved(String name);

  /// No description provided for @deleteMedicineQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteMedicineQuestion(String name);

  /// No description provided for @medicineArchived.
  ///
  /// In en, this message translates to:
  /// **'{name} archived'**
  String medicineArchived(String name);

  /// No description provided for @medicineRestored.
  ///
  /// In en, this message translates to:
  /// **'{name} restored'**
  String medicineRestored(String name);

  /// No description provided for @medicineMoved.
  ///
  /// In en, this message translates to:
  /// **'{name} moved to {group}'**
  String medicineMoved(String name, String group);

  /// No description provided for @dragHint.
  ///
  /// In en, this message translates to:
  /// **'Hold a medicine and drag it to another group to change its tag.'**
  String get dragHint;

  /// No description provided for @deleteProfileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and all their medicines?'**
  String deleteProfileQuestion(String name);

  /// No description provided for @scanBox.
  ///
  /// In en, this message translates to:
  /// **'Scan box'**
  String get scanBox;

  /// No description provided for @deleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteProfile;

  /// No description provided for @takingCount.
  ///
  /// In en, this message translates to:
  /// **'Taking ({count})'**
  String takingCount(int count);

  /// No description provided for @archivedCount.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String archivedCount(int count);

  /// No description provided for @noArchivedTitle.
  ///
  /// In en, this message translates to:
  /// **'No archived medicines'**
  String get noArchivedTitle;

  /// No description provided for @noArchivedMessage.
  ///
  /// In en, this message translates to:
  /// **'When someone stops taking a medicine, tap Archive on it and it moves here.'**
  String get noArchivedMessage;

  /// No description provided for @noMedicinesTitle.
  ///
  /// In en, this message translates to:
  /// **'No medicines yet'**
  String get noMedicinesTitle;

  /// No description provided for @noMedicinesMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap Scan box to read a medicine box. Only what you check and save is kept, encrypted on this phone.'**
  String get noMedicinesMessage;

  /// No description provided for @readingLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading the label…'**
  String get readingLabel;

  /// No description provided for @happensOnPhone.
  ///
  /// In en, this message translates to:
  /// **'This happens on your phone.'**
  String get happensOnPhone;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to {group}'**
  String moveTo(String group);

  /// No description provided for @moveMedicineTo.
  ///
  /// In en, this message translates to:
  /// **'Move {name} to'**
  String moveMedicineTo(String name);

  /// No description provided for @moveToMenu.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get moveToMenu;

  /// No description provided for @tagMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get tagMorning;

  /// No description provided for @tagNoon.
  ///
  /// In en, this message translates to:
  /// **'Noon'**
  String get tagNoon;

  /// No description provided for @tagEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get tagEvening;

  /// No description provided for @noTag.
  ///
  /// In en, this message translates to:
  /// **'No tag'**
  String get noTag;

  /// No description provided for @savedEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Saved encrypted on this phone only.'**
  String get savedEncrypted;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @strengthField.
  ///
  /// In en, this message translates to:
  /// **'Strength (optional)'**
  String get strengthField;

  /// No description provided for @strengthHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500 mg'**
  String get strengthHint;

  /// No description provided for @strengthHelper.
  ///
  /// In en, this message translates to:
  /// **'Check it: 0,5 mg and 1 mg are different'**
  String get strengthHelper;

  /// No description provided for @quantityField.
  ///
  /// In en, this message translates to:
  /// **'Quantity (optional)'**
  String get quantityField;

  /// No description provided for @unitField.
  ///
  /// In en, this message translates to:
  /// **'Unit (optional)'**
  String get unitField;

  /// No description provided for @unitHint.
  ///
  /// In en, this message translates to:
  /// **'compresse, ml…'**
  String get unitHint;

  /// No description provided for @addBoxPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of the box'**
  String get addBoxPhoto;

  /// No description provided for @keepBoxPhoto.
  ///
  /// In en, this message translates to:
  /// **'Keep the box photo'**
  String get keepBoxPhoto;

  /// No description provided for @keepBoxPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved encrypted, shown on this page'**
  String get keepBoxPhotoSubtitle;

  /// No description provided for @photoOfBox.
  ///
  /// In en, this message translates to:
  /// **'Photo of the box'**
  String get photoOfBox;

  /// No description provided for @photoCantShow.
  ///
  /// In en, this message translates to:
  /// **'The photo can\'t be shown.'**
  String get photoCantShow;

  /// No description provided for @whenYouTakeIt.
  ///
  /// In en, this message translates to:
  /// **'When you take it'**
  String get whenYouTakeIt;

  /// No description provided for @yourTags.
  ///
  /// In en, this message translates to:
  /// **'Your tags'**
  String get yourTags;

  /// No description provided for @addTagLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get addTagLabel;

  /// No description provided for @addTagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. When needed, Holiday'**
  String get addTagHint;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @discardNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this medicine?'**
  String get discardNewTitle;

  /// No description provided for @discardNewMessage.
  ///
  /// In en, this message translates to:
  /// **'It hasn\'t been saved yet.'**
  String get discardNewMessage;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'The changes haven\'t been saved.'**
  String get discardChangesMessage;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved. Keep the password safe: without it the backup can\'t be opened.'**
  String get backupSaved;

  /// No description provided for @profilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 profile} other{{count} profiles}}'**
  String profilesCount(int count);

  /// No description provided for @backupCounts.
  ///
  /// In en, this message translates to:
  /// **'{profiles} and {medicines}'**
  String backupCounts(String profiles, String medicines);

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Backup imported: {counts}.'**
  String backupImported(String counts);

  /// No description provided for @replaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything on this phone?'**
  String get replaceTitle;

  /// No description provided for @replaceMessage.
  ///
  /// In en, this message translates to:
  /// **'The backup has {counts}. What is on this phone now will be replaced by it.'**
  String replaceMessage(String counts);

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @encrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting…'**
  String get encrypting;

  /// No description provided for @atLeastChars.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String atLeastChars(int count);

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match'**
  String get passwordsDontMatch;

  /// No description provided for @exportBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'The backup holds every profile, medicine and kept photo, encrypted with a password you choose. You need the password to import it, and nobody can open it without, not even you if it\'s forgotten.'**
  String get exportBackupMessage;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get repeatPassword;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @typeBackupPassword.
  ///
  /// In en, this message translates to:
  /// **'Type the password the backup was made with.'**
  String get typeBackupPassword;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @backupNotBackup.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a Medicine Archive backup.'**
  String get backupNotBackup;

  /// No description provided for @backupWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password, or the file is damaged.'**
  String get backupWrongPassword;

  /// No description provided for @backupDamaged.
  ///
  /// In en, this message translates to:
  /// **'The file is damaged.'**
  String get backupDamaged;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine Archive is locked'**
  String get lockedTitle;

  /// No description provided for @lockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint, face or phone PIN to open it.'**
  String get lockedMessage;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your medicine archive'**
  String get unlockReason;

  /// No description provided for @archiveCantOpen.
  ///
  /// In en, this message translates to:
  /// **'The archive couldn\'t be opened. {detail}.'**
  String archiveCantOpen(String detail);

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @pointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the barcode on the box (the AIC code on the bollino).'**
  String get pointCamera;

  /// No description provided for @noBarcodeTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'No barcode? Take a photo'**
  String get noBarcodeTakePhoto;

  /// No description provided for @whichBarcode.
  ///
  /// In en, this message translates to:
  /// **'Which barcode?'**
  String get whichBarcode;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Which barcode to scan'**
  String get helpTitle;

  /// No description provided for @scanThis.
  ///
  /// In en, this message translates to:
  /// **'Scan this'**
  String get scanThis;

  /// No description provided for @bollinoImageLabel.
  ///
  /// In en, this message translates to:
  /// **'A bollino: striped barcode with A012745093 under it'**
  String get bollinoImageLabel;

  /// No description provided for @bollinoTitle.
  ///
  /// In en, this message translates to:
  /// **'The bollino'**
  String get bollinoTitle;

  /// No description provided for @bollinoText.
  ///
  /// In en, this message translates to:
  /// **'The sticker with a striped barcode and an A plus 9 digits under it: that is the AIC code.'**
  String get bollinoText;

  /// No description provided for @datamatrixImageLabel.
  ///
  /// In en, this message translates to:
  /// **'A square Data Matrix code made of dots'**
  String get datamatrixImageLabel;

  /// No description provided for @datamatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'The square dot code'**
  String get datamatrixTitle;

  /// No description provided for @datamatrixText.
  ///
  /// In en, this message translates to:
  /// **'Newer boxes have a grid of dots (Data Matrix) with the AIC code inside.'**
  String get datamatrixText;

  /// No description provided for @notThis.
  ///
  /// In en, this message translates to:
  /// **'Not this'**
  String get notThis;

  /// No description provided for @eanImageLabel.
  ///
  /// In en, this message translates to:
  /// **'An EAN-13 shop barcode with 13 digits'**
  String get eanImageLabel;

  /// No description provided for @eanTitle.
  ///
  /// In en, this message translates to:
  /// **'The shop barcode'**
  String get eanTitle;

  /// No description provided for @eanText.
  ///
  /// In en, this message translates to:
  /// **'13 digits, often starting with 80. It\'s only a product number, so the app skips it. If the box only has this one, take a photo instead.'**
  String get eanText;

  /// No description provided for @aifaCredit.
  ///
  /// In en, this message translates to:
  /// **'Medicine names come from AIFA\'s open data (Agenzia Italiana del Farmaco), adapted for the app. Licence: CC BY 4.0.'**
  String get aifaCredit;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @onboarding1Title.
  ///
  /// In en, this message translates to:
  /// **'How many times has someone asked you which medicines you take?'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Body.
  ///
  /// In en, this message translates to:
  /// **'At the doctor\'s, at the pharmacy, in the emergency room… and the boxes are at home.'**
  String get onboarding1Body;

  /// No description provided for @onboarding2Title.
  ///
  /// In en, this message translates to:
  /// **'Now that problem is solved'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Body.
  ///
  /// In en, this message translates to:
  /// **'Your medicines, and your family\'s, are always with you: in your pocket, on your phone.'**
  String get onboarding2Body;

  /// No description provided for @onboarding3Title.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Body1.
  ///
  /// In en, this message translates to:
  /// **'Create a profile for each person.'**
  String get onboarding3Body1;

  /// No description provided for @onboarding3Body2.
  ///
  /// In en, this message translates to:
  /// **'Scan the barcode on the box, or take a photo.'**
  String get onboarding3Body2;

  /// No description provided for @onboarding3Body3.
  ///
  /// In en, this message translates to:
  /// **'Check and save. Everything stays encrypted on this phone.'**
  String get onboarding3Body3;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @letsStart.
  ///
  /// In en, this message translates to:
  /// **'OK, let\'s start'**
  String get letsStart;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @optionsFor.
  ///
  /// In en, this message translates to:
  /// **'Options for {name}'**
  String optionsFor(String name);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @archiveStopped.
  ///
  /// In en, this message translates to:
  /// **'Archive (stopped taking it)'**
  String get archiveStopped;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @alsoTags.
  ///
  /// In en, this message translates to:
  /// **'also {tags}'**
  String alsoTags(String tags);

  /// No description provided for @searchMedicines.
  ///
  /// In en, this message translates to:
  /// **'Search {name}\'s medicines'**
  String searchMedicines(String name);

  /// No description provided for @noMatch.
  ///
  /// In en, this message translates to:
  /// **'No medicine matches \"{query}\"'**
  String noMatch(String query);

  /// No description provided for @typeItIn.
  ///
  /// In en, this message translates to:
  /// **'Type it in'**
  String get typeItIn;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
