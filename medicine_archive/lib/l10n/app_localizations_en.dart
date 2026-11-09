// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Medicine Archive';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get next => 'Next';

  @override
  String get undo => 'Undo';

  @override
  String get moreOptions => 'More options';

  @override
  String get cantBeUndone => 'This can\'t be undone.';

  @override
  String get newProfile => 'New profile';

  @override
  String get exportBackup => 'Export backup';

  @override
  String get importBackup => 'Import backup';

  @override
  String get noProfilesTitle => 'No profiles yet';

  @override
  String get noProfilesMessage => 'Create a profile for each person whose medicines you keep.';

  @override
  String get importABackup => 'Import a backup';

  @override
  String get profilesHeading => 'Profiles';

  @override
  String medicineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicines',
      one: '1 medicine',
    );
    return '$_temp0';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get checkMedicine => 'Check medicine';

  @override
  String get editMedicine => 'Edit medicine';

  @override
  String get addMedicine => 'Add medicine';

  @override
  String fromBarcodeFound(String aic) {
    return 'From the barcode: AIC $aic, found in AIFA\'s medicine list.';
  }

  @override
  String get couldntReadLabel => 'Couldn\'t read the label. Please type it in.';

  @override
  String fromBarcodeInPhoto(String aic) {
    return 'From the barcode in the photo: AIC $aic, found in AIFA\'s medicine list.';
  }

  @override
  String barcodeNotInList(String aic) {
    return 'The barcode (AIC $aic) isn\'t in AIFA\'s list, so the text in the photo was read.';
  }

  @override
  String get readFromText =>
      'Read from the text in the photo. Check it and fix anything that is wrong.';

  @override
  String get photoDeleted => 'The photo has been deleted.';

  @override
  String get photoDeletedOnSave => 'The photo is deleted when you save, unless you keep it.';

  @override
  String medicineSaved(String name) {
    return '$name saved';
  }

  @override
  String deleteMedicineQuestion(String name) {
    return 'Delete $name?';
  }

  @override
  String medicineArchived(String name) {
    return '$name archived';
  }

  @override
  String medicineRestored(String name) {
    return '$name restored';
  }

  @override
  String medicineMoved(String name, String group) {
    return '$name moved to $group';
  }

  @override
  String allCount(int count) {
    return 'All ($count)';
  }

  @override
  String groupCount(String group, int count) {
    return '$group ($count)';
  }

  @override
  String get emptyGroupHint =>
      'Nothing here yet. Hold a medicine and drop it on this chip, or pick the tag in its form.';

  @override
  String get dragHint => 'Hold a medicine and drag it to another group to change its tag.';

  @override
  String deleteProfileQuestion(String name) {
    return 'Delete $name and all their medicines?';
  }

  @override
  String get scanBox => 'Scan box';

  @override
  String get addByHand => 'Add by hand';

  @override
  String get deleteProfile => 'Delete profile';

  @override
  String takingCount(int count) {
    return 'Taking ($count)';
  }

  @override
  String archivedCount(int count) {
    return 'Archived ($count)';
  }

  @override
  String get noArchivedTitle => 'No archived medicines';

  @override
  String get noArchivedMessage =>
      'When someone stops taking a medicine, tap Archive on it and it moves here.';

  @override
  String get noMedicinesTitle => 'No medicines yet';

  @override
  String get noMedicinesMessage =>
      'Tap Scan box to read a medicine box. Only what you check and save is kept, encrypted on this phone.';

  @override
  String restoreMedicine(String name) {
    return 'Restore $name';
  }

  @override
  String archiveMedicine(String name) {
    return 'Archive $name';
  }

  @override
  String deleteMedicine(String name) {
    return 'Delete $name';
  }

  @override
  String get readingLabel => 'Reading the label…';

  @override
  String get happensOnPhone => 'This happens on your phone.';

  @override
  String moveTo(String group) {
    return 'Move to $group';
  }

  @override
  String moveMedicineTo(String name) {
    return 'Move $name to';
  }

  @override
  String get moveToMenu => 'Move to…';

  @override
  String get tagMorning => 'Morning';

  @override
  String get tagNoon => 'Noon';

  @override
  String get tagEvening => 'Evening';

  @override
  String get noTag => 'No tag';

  @override
  String get savedEncrypted => 'Saved encrypted on this phone only.';

  @override
  String get required => 'Required';

  @override
  String get strengthField => 'Strength (optional)';

  @override
  String get strengthHint => 'e.g. 500 mg';

  @override
  String get strengthHelper => 'Check it: 0,5 mg and 1 mg are different';

  @override
  String get quantityField => 'Quantity (optional)';

  @override
  String get unitField => 'Unit (optional)';

  @override
  String get unitHint => 'compresse, ml…';

  @override
  String get addBoxPhoto => 'Add a photo of the box';

  @override
  String get keepBoxPhoto => 'Keep the box photo';

  @override
  String get keepBoxPhotoSubtitle => 'Saved encrypted, shown on this page';

  @override
  String get photoOfBox => 'Photo of the box';

  @override
  String get photoCantShow => 'The photo can\'t be shown.';

  @override
  String get whenYouTakeIt => 'When you take it';

  @override
  String get yourTags => 'Your tags';

  @override
  String get addTagLabel => 'Add a tag';

  @override
  String get addTagHint => 'e.g. When needed, Holiday';

  @override
  String get addTag => 'Add tag';

  @override
  String get discardNewTitle => 'Discard this medicine?';

  @override
  String get discardNewMessage => 'It hasn\'t been saved yet.';

  @override
  String get discardChangesTitle => 'Discard your changes?';

  @override
  String get discardChangesMessage => 'The changes haven\'t been saved.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String get backupSaved =>
      'Backup saved. Keep the password safe: without it the backup can\'t be opened.';

  @override
  String profilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return '$_temp0';
  }

  @override
  String backupCounts(String profiles, String medicines) {
    return '$profiles and $medicines';
  }

  @override
  String backupImported(String counts) {
    return 'Backup imported: $counts.';
  }

  @override
  String get replaceTitle => 'Replace everything on this phone?';

  @override
  String replaceMessage(String counts) {
    return 'The backup has $counts. What is on this phone now will be replaced by it.';
  }

  @override
  String get replace => 'Replace';

  @override
  String get encrypting => 'Encrypting…';

  @override
  String atLeastChars(int count) {
    return 'At least $count characters';
  }

  @override
  String get passwordsDontMatch => 'The passwords don\'t match';

  @override
  String get exportBackupMessage =>
      'The backup holds every profile, medicine and kept photo, encrypted with a password you choose. You need the password to import it, and nobody can open it without, not even you if it\'s forgotten.';

  @override
  String get password => 'Password';

  @override
  String get repeatPassword => 'Repeat password';

  @override
  String get export => 'Export';

  @override
  String get typeBackupPassword => 'Type the password the backup was made with.';

  @override
  String get open => 'Open';

  @override
  String get backupNotBackup => 'This file isn\'t a Medicine Archive backup.';

  @override
  String get backupWrongPassword => 'Wrong password, or the file is damaged.';

  @override
  String get backupDamaged => 'The file is damaged.';

  @override
  String get lockedTitle => 'Medicine Archive is locked';

  @override
  String get lockedMessage => 'Use your fingerprint, face or phone PIN to open it.';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock your medicine archive';

  @override
  String archiveCantOpen(String detail) {
    return 'The archive couldn\'t be opened. $detail.';
  }

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get pointCamera =>
      'Point the camera at the barcode on the box (the AIC code on the bollino).';

  @override
  String get noBarcodeTakePhoto => 'No barcode? Take a photo';

  @override
  String get whichBarcode => 'Which barcode?';

  @override
  String get help => 'Help';

  @override
  String get helpTitle => 'Which barcode to scan';

  @override
  String get scanThis => 'Scan this';

  @override
  String get bollinoImageLabel => 'A bollino: striped barcode with A012745093 under it';

  @override
  String get bollinoTitle => 'The bollino';

  @override
  String get bollinoText =>
      'The sticker with a striped barcode and an A plus 9 digits under it: that is the AIC code.';

  @override
  String get datamatrixImageLabel => 'A square Data Matrix code made of dots';

  @override
  String get datamatrixTitle => 'The square dot code';

  @override
  String get datamatrixText =>
      'Newer boxes have a grid of dots (Data Matrix) with the AIC code inside.';

  @override
  String get notThis => 'Not this';

  @override
  String get eanImageLabel => 'An EAN-13 shop barcode with 13 digits';

  @override
  String get eanTitle => 'The shop barcode';

  @override
  String get eanText =>
      '13 digits, often starting with 80. It\'s only a product number, so the app skips it. If the box only has this one, take a photo instead.';

  @override
  String get aifaCredit =>
      'Medicine names come from AIFA\'s open data (Agenzia Italiana del Farmaco), adapted for the app. Licence: CC BY 4.0.';

  @override
  String get gotIt => 'Got it';

  @override
  String get onboarding1Title => 'How many times has someone asked you which medicines you take?';

  @override
  String get onboarding1Body =>
      'At the doctor\'s, at the pharmacy, in the emergency room… and the boxes are at home.';

  @override
  String get onboarding2Title => 'Now that problem is solved';

  @override
  String get onboarding2Body =>
      'Your medicines, and your family\'s, are always with you: in your pocket, on your phone.';

  @override
  String get onboarding3Title => 'How it works';

  @override
  String get onboarding3Body1 => 'Create a profile for each person.';

  @override
  String get onboarding3Body2 => 'Scan the barcode on the box, or take a photo.';

  @override
  String get onboarding3Body3 => 'Check and save. Everything stays encrypted on this phone.';

  @override
  String get skip => 'Skip';

  @override
  String get letsStart => 'OK, let\'s start';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }
}
