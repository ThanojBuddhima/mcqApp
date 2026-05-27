import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mcq_platform/app.dart';

void main() {
  testWidgets('App loads', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: McqApp()));
    expect(find.text('MCQ Platform'), findsOneWidget);
  });
}
