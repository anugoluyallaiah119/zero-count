@Tags(["golden"])
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerocount_app/features/auth/auth_repository.dart';
import 'package:zerocount_app/features/collection/collection_grid_screen.dart';
import 'package:zerocount_app/features/collection/store_screen.dart';
import 'package:zerocount_app/features/events/events_screen.dart';
import 'package:zerocount_app/features/player/profile_repository.dart';

import 'widget_test.dart' show FakeAuthRepository, FakeProfileRepository;

/// Golden renders for the Phase 2 screens (Events hub + Collection tab),
/// at the same 852x1846 physical size as the approved mockups.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen, String name) async {
    tester.view.physicalSize = const Size(852, 1846);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            profileRepositoryProvider
                .overrideWithValue(FakeProfileRepository()),
          ],
          child: MaterialApp(home: screen),
        ),
      );
      // Big hero art decode.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });

    await expectLater(find.byType(screen.runtimeType),
        matchesGoldenFile('goldens/$name.png'));

    // Unmount so the next screen starts from a clean tree.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('events daily tab matches mockup', (tester) async {
    await pump(tester, const EventsScreen(initialTab: 0), 'events_daily');
  });

  testWidgets('events weekly tab matches mockup', (tester) async {
    await pump(tester, const EventsScreen(initialTab: 1), 'events_weekly');
  });

  testWidgets('events monthly tab matches mockup', (tester) async {
    await pump(tester, const EventsScreen(initialTab: 2), 'events_monthly');
  });

  testWidgets('events sponsored tab matches mockup', (tester) async {
    await pump(
        tester, const EventsScreen(initialTab: 3), 'events_sponsored');
  });

  testWidgets('store screen matches mockup', (tester) async {
    await pump(tester, const StoreScreen(), 'collection_store');
  });

  testWidgets('card backs screen matches mockup', (tester) async {
    await pump(tester, const CardBacksScreen(), 'collection_card_backs');
  });

  testWidgets('special cards screen matches mockup', (tester) async {
    await pump(
        tester, const SpecialCardsScreen(), 'collection_special_cards');
  });

  testWidgets('avatars screen matches mockup', (tester) async {
    await pump(tester, const AvatarsScreen(), 'collection_avatars');
  });

  testWidgets('themes screen matches mockup', (tester) async {
    await pump(tester, const ThemesScreen(), 'collection_themes');
  });

  testWidgets('effects screen matches mockup', (tester) async {
    await pump(tester, const EffectsScreen(), 'collection_effects');
  });

  testWidgets('stickers screen matches mockup', (tester) async {
    await pump(tester, const StickersScreen(), 'collection_stickers');
  });
}
