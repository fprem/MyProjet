// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Medicine Archive';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get save => 'Salva';

  @override
  String get create => 'Crea';

  @override
  String get next => 'Avanti';

  @override
  String get undo => 'Annulla';

  @override
  String get moreOptions => 'Altre opzioni';

  @override
  String get cantBeUndone => 'Non si può annullare.';

  @override
  String get newProfile => 'Nuovo profilo';

  @override
  String get exportBackup => 'Esporta backup';

  @override
  String get importBackup => 'Importa backup';

  @override
  String get noProfilesTitle => 'Ancora nessun profilo';

  @override
  String get noProfilesMessage =>
      'Crea un profilo per ogni persona di cui tieni i farmaci.';

  @override
  String get importABackup => 'Importa un backup';

  @override
  String get profilesHeading => 'Profili';

  @override
  String medicineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count farmaci',
      one: '1 farmaco',
    );
    return '$_temp0';
  }

  @override
  String get nameLabel => 'Nome';

  @override
  String get checkMedicine => 'Controlla il farmaco';

  @override
  String get editMedicine => 'Modifica farmaco';

  @override
  String get addMedicine => 'Aggiungi farmaco';

  @override
  String fromBarcodeFound(String aic) {
    return 'Dal codice a barre: AIC $aic, trovato nell\'elenco dei farmaci AIFA.';
  }

  @override
  String get couldntReadLabel =>
      'Non è stato possibile leggere l\'etichetta. Scrivila tu.';

  @override
  String fromBarcodeInPhoto(String aic) {
    return 'Dal codice a barre nella foto: AIC $aic, trovato nell\'elenco dei farmaci AIFA.';
  }

  @override
  String barcodeNotInList(String aic) {
    return 'Il codice a barre (AIC $aic) non è nell\'elenco AIFA, quindi è stato letto il testo della foto.';
  }

  @override
  String get readFromText =>
      'Letto dal testo della foto. Controlla e correggi quello che è sbagliato.';

  @override
  String get photoDeleted => 'La foto è stata eliminata.';

  @override
  String get photoDeletedOnSave =>
      'La foto viene eliminata quando salvi, a meno che tu non la tenga.';

  @override
  String medicineSaved(String name) {
    return '$name salvato';
  }

  @override
  String deleteMedicineQuestion(String name) {
    return 'Eliminare $name?';
  }

  @override
  String medicineArchived(String name) {
    return '$name archiviato';
  }

  @override
  String medicineRestored(String name) {
    return '$name ripristinato';
  }

  @override
  String medicineMoved(String name, String group) {
    return '$name spostato in $group';
  }

  @override
  String get dragHint =>
      'Tieni premuto un farmaco e trascinalo in un altro gruppo per cambiargli etichetta.';

  @override
  String deleteProfileQuestion(String name) {
    return 'Eliminare $name e tutti i suoi farmaci?';
  }

  @override
  String get scanBox => 'Scansiona scatola';

  @override
  String get deleteProfile => 'Elimina profilo';

  @override
  String takingCount(int count) {
    return 'In uso ($count)';
  }

  @override
  String archivedCount(int count) {
    return 'Archiviati ($count)';
  }

  @override
  String get noArchivedTitle => 'Nessun farmaco archiviato';

  @override
  String get noArchivedMessage =>
      'Quando qualcuno smette di prendere un farmaco, tocca Archivia e il farmaco finisce qui.';

  @override
  String get noMedicinesTitle => 'Ancora nessun farmaco';

  @override
  String get noMedicinesMessage =>
      'Tocca Scansiona scatola per leggere la confezione. Viene tenuto solo quello che controlli e salvi, cifrato su questo telefono.';

  @override
  String get readingLabel => 'Lettura dell\'etichetta…';

  @override
  String get happensOnPhone => 'Avviene sul tuo telefono.';

  @override
  String moveTo(String group) {
    return 'Sposta in $group';
  }

  @override
  String moveMedicineTo(String name) {
    return 'Sposta $name in';
  }

  @override
  String get moveToMenu => 'Sposta in…';

  @override
  String get tagMorning => 'Mattina';

  @override
  String get tagNoon => 'Mezzogiorno';

  @override
  String get tagEvening => 'Sera';

  @override
  String get noTag => 'Senza etichetta';

  @override
  String get savedEncrypted => 'Salvato cifrato solo su questo telefono.';

  @override
  String get required => 'Obbligatorio';

  @override
  String get strengthField => 'Dosaggio (facoltativo)';

  @override
  String get strengthHint => 'es. 500 mg';

  @override
  String get strengthHelper => 'Controllalo: 0,5 mg e 1 mg sono diversi';

  @override
  String get quantityField => 'Quantità (facoltativa)';

  @override
  String get unitField => 'Unità (facoltativa)';

  @override
  String get unitHint => 'compresse, ml…';

  @override
  String get addBoxPhoto => 'Aggiungi una foto della scatola';

  @override
  String get keepBoxPhoto => 'Tieni la foto della scatola';

  @override
  String get keepBoxPhotoSubtitle =>
      'Salvata cifrata, mostrata in questa pagina';

  @override
  String get photoOfBox => 'Foto della scatola';

  @override
  String get photoCantShow => 'Non è possibile mostrare la foto.';

  @override
  String get whenYouTakeIt => 'Quando lo prendi';

  @override
  String get yourTags => 'Le tue etichette';

  @override
  String get addTagLabel => 'Aggiungi un\'etichetta';

  @override
  String get addTagHint => 'es. Al bisogno, Vacanza';

  @override
  String get addTag => 'Aggiungi etichetta';

  @override
  String get discardNewTitle => 'Scartare questo farmaco?';

  @override
  String get discardNewMessage => 'Non è ancora stato salvato.';

  @override
  String get discardChangesTitle => 'Scartare le modifiche?';

  @override
  String get discardChangesMessage => 'Le modifiche non sono state salvate.';

  @override
  String get keepEditing => 'Continua a modificare';

  @override
  String get discard => 'Scarta';

  @override
  String get backupSaved =>
      'Backup salvato. Custodisci la password: senza, il backup non si può aprire.';

  @override
  String profilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profili',
      one: '1 profilo',
    );
    return '$_temp0';
  }

  @override
  String backupCounts(String profiles, String medicines) {
    return '$profiles e $medicines';
  }

  @override
  String backupImported(String counts) {
    return 'Backup importato: $counts.';
  }

  @override
  String get replaceTitle => 'Sostituire tutto su questo telefono?';

  @override
  String replaceMessage(String counts) {
    return 'Il backup contiene $counts. Quello che c\'è ora su questo telefono verrà sostituito.';
  }

  @override
  String get replace => 'Sostituisci';

  @override
  String get encrypting => 'Cifratura…';

  @override
  String atLeastChars(int count) {
    return 'Almeno $count caratteri';
  }

  @override
  String get passwordsDontMatch => 'Le password non coincidono';

  @override
  String get exportBackupMessage =>
      'Il backup contiene tutti i profili, i farmaci e le foto tenute, cifrati con una password che scegli tu. Serve la password per importarlo, e nessuno può aprirlo senza, nemmeno tu se la dimentichi.';

  @override
  String get password => 'Password';

  @override
  String get repeatPassword => 'Ripeti la password';

  @override
  String get export => 'Esporta';

  @override
  String get typeBackupPassword =>
      'Scrivi la password con cui è stato fatto il backup.';

  @override
  String get open => 'Apri';

  @override
  String get backupNotBackup =>
      'Questo file non è un backup di Medicine Archive.';

  @override
  String get backupWrongPassword =>
      'Password sbagliata, o il file è danneggiato.';

  @override
  String get backupDamaged => 'Il file è danneggiato.';

  @override
  String get lockedTitle => 'Medicine Archive è bloccato';

  @override
  String get lockedMessage =>
      'Usa l\'impronta, il volto o il PIN del telefono per aprirlo.';

  @override
  String get unlock => 'Sblocca';

  @override
  String get unlockReason => 'Sblocca il tuo archivio farmaci';

  @override
  String archiveCantOpen(String detail) {
    return 'Non è stato possibile aprire l\'archivio. $detail.';
  }

  @override
  String get scanBarcode => 'Scansiona codice a barre';

  @override
  String get pointCamera =>
      'Inquadra il codice a barre sulla scatola (il codice AIC sul bollino).';

  @override
  String get noBarcodeTakePhoto => 'Niente codice? Scatta una foto';

  @override
  String get whichBarcode => 'Quale codice a barre?';

  @override
  String get help => 'Aiuto';

  @override
  String get helpTitle => 'Quale codice a barre inquadrare';

  @override
  String get scanThis => 'Inquadra questo';

  @override
  String get bollinoImageLabel =>
      'Un bollino: codice a barre a righe con A012745093 sotto';

  @override
  String get bollinoTitle => 'Il bollino';

  @override
  String get bollinoText =>
      'L\'adesivo con un codice a barre a righe e sotto una A seguita da 9 cifre: è il codice AIC.';

  @override
  String get datamatrixImageLabel =>
      'Un codice quadrato Data Matrix fatto di puntini';

  @override
  String get datamatrixTitle => 'Il codice quadrato a puntini';

  @override
  String get datamatrixText =>
      'Le scatole più recenti hanno una griglia di puntini (Data Matrix) con dentro il codice AIC.';

  @override
  String get notThis => 'Non questo';

  @override
  String get eanImageLabel =>
      'Un codice a barre EAN-13 da negozio con 13 cifre';

  @override
  String get eanTitle => 'Il codice a barre del negozio';

  @override
  String get eanText =>
      '13 cifre, spesso inizia con 80. È solo un numero di prodotto, quindi l\'app lo salta. Se la scatola ha solo questo, scatta una foto.';

  @override
  String get aifaCredit =>
      'I nomi dei farmaci vengono dai dati aperti di AIFA (Agenzia Italiana del Farmaco), adattati per l\'app. Licenza: CC BY 4.0.';

  @override
  String get gotIt => 'Ho capito';

  @override
  String get onboarding1Title =>
      'Quante volte ti hanno chiesto quali farmaci prendi?';

  @override
  String get onboarding1Body =>
      'Dal medico, in farmacia, al pronto soccorso… e le scatole sono a casa.';

  @override
  String get onboarding2Title => 'Ora il problema è risolto';

  @override
  String get onboarding2Body =>
      'I tuoi farmaci, e quelli della tua famiglia, sono sempre con te: in tasca, sul telefono.';

  @override
  String get onboarding3Title => 'Come funziona';

  @override
  String get onboarding3Body1 => 'Crea un profilo per ogni persona.';

  @override
  String get onboarding3Body2 =>
      'Scansiona il codice a barre sulla scatola, o scatta una foto.';

  @override
  String get onboarding3Body3 =>
      'Controlla e salva. Tutto resta cifrato su questo telefono.';

  @override
  String get skip => 'Salta';

  @override
  String get letsStart => 'OK, cominciamo';

  @override
  String stepOf(int step, int total) {
    return 'Passo $step di $total';
  }

  @override
  String optionsFor(String name) {
    return 'Opzioni per $name';
  }

  @override
  String get edit => 'Modifica';

  @override
  String get archiveStopped => 'Archivia (non lo prende più)';

  @override
  String get restore => 'Ripristina';

  @override
  String alsoTags(String tags) {
    return 'anche $tags';
  }

  @override
  String searchMedicines(String name) {
    return 'Cerca tra i farmaci di $name';
  }

  @override
  String noMatch(String query) {
    return 'Nessun farmaco corrisponde a \"$query\"';
  }

  @override
  String get typeItIn => 'Scrivi a mano';

  @override
  String get clearSearch => 'Cancella la ricerca';

  @override
  String get usePhoneColours => 'Usa i colori del telefono';
}
