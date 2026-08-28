ZERO COUNT V2.3 — MOBILE WEB APP

Changes:
- Reverted the recent special/premium card-face redesign. Cards are back to the original V1 card visuals.
- Kept the V2 anti-starvation draw logic.
- 4-player games now use two physical decks.
- Added controlled opening-hand opportunity balancing.
- Improved stock-draw weighting and dry-streak protection.
- Added the supplied Zero Count artwork as the web/app icon.
- Added PWA manifest + service worker + offline cache.
- Added an ADD TO HOME SCREEN button.

To use as a mobile app:
1. Upload this folder to an HTTPS web host.
2. Open the HTTPS URL in Chrome on Android.
3. Tap ADD TO HOME SCREEN when shown, or Chrome menu -> Add to Home screen / Install app.
4. Launch it from the phone home screen. It opens in standalone app mode.

Important: opening index.html directly with file:// is still opening a file. PWA installation/service workers require HTTPS (except localhost).
