# Zero Count V2 — UI Development Strategy (Mockup → Flutter)

This document explains the exact process used to turn the approved UI mockups
into nearly pixel-identical Flutter screens. Use it as the playbook for every
future screen.

---

## 1. The Pipeline (per screen)

```
Mockup image
   │
   ├─ 1. Read the mockup visually (every region, color, spacing)
   ├─ 2. Extract design tokens (colors, radii, fonts)
   ├─ 3. Generate missing art assets with AI (grid-slice strategy)
   ├─ 4. Build the Flutter screen with shared tokens/widgets
   ├─ 5. Golden test at mockup resolution (852x1846 @2x)
   ├─ 6. Real-font preview render → eyeball vs mockup
   └─ 7. Fix overflow/spacing diffs, regenerate goldens, commit
```

Never skip steps 5–6: the test-font render catches layout bugs, the
real-font render catches visual mismatches.

---

## 2. Design Tokens First (`lib/ui/zc_theme.dart`)

All colors were measured from the mockups once and reused everywhere:

- Dark palette: `bgTop #0D0328 → bgBottom #08051E` gradient, panels
  `panelPurple #130B3B`, inputs `panelInput #1D0A4B`
- Neon accents: `neonPurple #9B30FF`, `neonPink #D846CB`, `neonGreen #2EEA6A`
- Gold CTA gradient: `#FDE03A → #FDC421 → #F9A809` (dark text `#1A0B3C`)
- Phase 2 light palette (`LcColors`): bg `#F4F1FB`, purple `#7C3AED`,
  rarity colors (Rare blue / Epic purple / Legendary orange)
- Radii: panel 20, button 14, chip 12, card 10
- Typography: **Bungee** for display titles, **Nunito** (800 headings,
  600 body) for everything else — loaded at runtime, with test-safe
  fallbacks

**Rule: never hardcode a color in a screen.** If it's not in the token file,
add it there first. This is what keeps 20+ screens visually consistent.

---

## 3. AI Art Asset Strategy (the "grid-slice" trick)

Mockups contain rich artwork (heroes, card backs, avatars, stickers) that
can't be drawn in code. Instead of generating 100+ images one by one:

1. **Generate one 1:1 image containing a perfectly aligned 2x2 grid** with a
   prompt like: *"Perfectly aligned 2x2 grid of four X with wide even spacing
   between them, on a solid #150B3A background, flat mobile game art style,
   no text, no watermark"*
2. **Slice the 4 cells with PIL** (`trim()` against the corner background
   color + small padding) → 4 individual PNGs
3. Grid variations: 2x2 (4 items), 2-stacked (2 items), single heroes (1:1 or
   3:2)
4. Always request a **solid, known background color** so auto-trimming works
5. Trim ALL assets (raw AI output has ~20% dead padding that breaks layout)

This produced 122 assets from ~26 generation calls — 4x cheaper and visually
consistent because each grid shares one art style/lighting.

Assets live in `app/assets/art/` (declared once in `pubspec.yaml`).

---

## 4. Screen Construction Patterns

### Shared widgets, not one-off code
- `ZcScreenHeader` / `CollectionHeader` (dark+light variants) — back button,
  title, coin/gem pills, bell
- `ZcCurrencyPill` — coin/gem chip with green "+" badge
- `ZcBottomNav` — 5-tab bar (dark pill style + light text style)
- `RarityChip`, `CollectionFilters`, `CollectionGridCard`, `VisitStoreStrip`
- `ZcPlayingCard`, `ZcCardFan` — game-specific primitives

One parameterized `CollectionGridScreen` drives 5 of the 7 collection
screens — only the hero config differs. Fewer widgets = fewer bugs =
consistent mockup fidelity.

### Layout patterns that survive any font/screen
- `LayoutBuilder` + solved card widths (fit N cards in available width,
  clamped 30–54px) instead of fixed sizes
- `SingleChildScrollView + ConstrainedBox(minHeight) + IntrinsicHeight` for
  screens with `Spacer()` — scrolls on small devices instead of overflowing
- `Row` with `Expanded`/`Flexible` everywhere; `FittedBox` on any text that
  must never wrap

### Test-font survival (critical!)
Flutter's golden-test font ("tofu") is ~40% wider than real fonts. Every
`RenderFlex overflowed` in tests is a real overflow risk on narrow phones.
So: FittedBox/Flexible on every fixed-width text row, even if it "fits" with
the real font.

---

## 5. Golden Tests (visual regression locking)

```dart
tester.view.physicalSize = const Size(852, 1846);  // mockup resolution
tester.view.devicePixelRatio = 2.0;                // 426x923 logical
```

- One golden PNG per screen/state, in `test/goldens/`
- Repository fakes (`FakeAuthRepository`, `FakeProfileRepository`,
  `FakeRoomRepository`, `FakeLiveMatchController`) make every screen
  renderable without a backend
- Big PNG assets need an async decode loop inside `runAsync`:
  `for (20x) { delay 50ms; pump(); }`
- Taller viewport (`900x2200`) for scrollable showcase trees — avoids the
  "non-finite rect" semantics flake from clipped off-screen nodes

Once goldens are committed, **any accidental visual change fails CI**.

---

## 6. Real-Font Previews (the truth check)

Goldens use tofu font — they prove layout, not beauty. For design review:

1. Download Bungee/Nunito TTFs (Google Fonts css2 → gstatic woff2 →
   fontTools convert to TTF) + `MaterialIcons-Regular.otf` **from the
   Flutter SDK's own cache** (`bin/cache/artifacts/material_fonts/`) — the
   SDK version matches the icon codepoints exactly
2. `FontLoader(family)..addFont(...)` in a preview test
3. Wrap in `MaterialApp(theme: ThemeData(fontFamily: 'Nunito'))`
4. Capture with `matchesGoldenFile` into a scratch folder, copy PNGs out
5. **Eyeball each preview side-by-side with the mockup**, fix diffs, repeat

Fake-time trick: drive animations with `tester.pump(Duration(...))` + short
real delays — real-time waits don't advance the animation clock, and they
can trigger time-based navigation (e.g. splash auto-route) mid-capture.

---

## 7. Animation Fidelity (V1 gameplay motion)

The card-draw motion from V1 was restored as a reusable `_CardFlight`
overlay:

```
draw:   face-down rise → rotateY flip 0→π (un-mirror front past π/2) →
        hold so the user reads the card → glide down + fade into hand
take:   face-up tilt from discard pile
discard: fast rise from hand to table center
```

Triggered by **diffing state** (`ref.listen` on hand card IDs) inside a
`Stack` overlay with `IgnorePointer` — the board never rebuilds for an
animation, and flights never stack.

---

## 8. App Icons

From one master icon (`App_icon.png`), PIL generates:

- **Android legacy**: `mipmap-{mdpi…xxxhdpi}/ic_launcher.png` (48–192px)
- **Android adaptive**: foreground at 68% of the canvas (108–432px) +
  `mipmap-anydpi-v26/ic_launcher.xml` + background color `#0A0618`
- **iOS**: full `AppIcon.appiconset` (17 files + Contents.json), flattened
  opaque (iOS rejects alpha in icons)

---

## 9. Checklist for the Next Screen

- [ ] Read the mockup; list every region and its tokens
- [ ] Reuse existing tokens/widgets; add new tokens to `zc_theme.dart`
- [ ] Generate art via 2x2 grids; trim; drop into `assets/art/`
- [ ] Build with Flexible/FittedBox everywhere
- [ ] Golden test at 852x1846@2x with fakes
- [ ] Real-font preview; compare against mockup; fix diffs
- [ ] `flutter analyze` clean + full `flutter test` green
- [ ] **Wire a navigation entry point** (a screen nobody can reach
      doesn't exist)
- [ ] Commit + rebuild the zip
