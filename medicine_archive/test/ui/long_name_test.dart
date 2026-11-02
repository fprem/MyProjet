import 'package:flutter_test/flutter_test.dart';
import 'package:medicine_archive/app.dart';
import 'package:medicine_archive/data/archive_repository.dart';
import 'package:medicine_archive/scan/label_parser.dart';
import 'package:medicine_archive/ui/fitted_name.dart';

import 'fakes.dart';

void main() {
  late ArchiveRepository repo;
  late Profile anna;

  setUp(() async {
    repo = await memoryRepository();
    anna = await repo.createProfile('Anna');
  });

  Future<void> pumpAnna(WidgetTester tester) async {
    await tester.pumpWidget(
      MedicineArchiveApp(
        repository: repo,
        scanner: FakeScanner(const LabelResult.empty()),
        takePhoto: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
  }

  testWidgets('medicine names in the list fit their size to the card', (tester) async {
    await repo.addMedicine(anna.id, name: 'Moment');
    await repo.addMedicine(anna.id, name: 'Amoxicillina e Acido Clavulanico Sandoz');
    await pumpAnna(tester);

    expect(find.widgetWithText(FittedName, 'Moment'), findsOneWidget);
    expect(
      find.widgetWithText(FittedName, 'Amoxicillina e Acido Clavulanico Sandoz'),
      findsOneWidget,
    );
  });
}
