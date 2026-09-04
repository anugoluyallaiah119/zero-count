# Local Setup & Test — Zero Count

Run these commands on a machine with Flutter 3.32+ installed.

---

## 1. Prerequisites

```bash
flutter --version   # must be 3.32+
java -version       # must be 17+
```

---

## 2. Clone & enter the app

```bash
git clone https://github.com/YallaiahAnugolu/Zero-Count.git
cd Zero-Count/app
git checkout feat/v2.2-retention-loop
```

---

## 3. Create the upload keystore (one-time)

```bash
keytool -genkey -v \
  -keystore ~/zc-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then create `android/key.properties` (already gitignored):

```bash
cat > android/key.properties <<EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_USERNAME/zc-upload.jks
EOF
```

---

## 4. Install dependencies + generate icons & splash

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## 5. Run on a connected Android device (debug)

```bash
flutter run --debug --dart-define=FLAVOR=dev
```

> The dev flavor points the API at `http://localhost:8080`.
> To test against your staging server:
> ```bash
> flutter run --debug \
>   --dart-define=FLAVOR=dev \
>   --dart-define=API_BASE=https://your-staging-server.com
> ```

---

## 6. Build a release AAB for Play Store

```bash
flutter build appbundle \
  --release \
  --dart-define=FLAVOR=prod
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Upload this file to **Google Play Console → Internal testing**.

---

## 7. GitHub Actions release (alternative — no local Flutter needed)

Add these secrets in **GitHub → Settings → Secrets → Actions**:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -i ~/zc-upload.jks \| pbcopy` |
| `KEYSTORE_STORE_PASSWORD` | Your store password |
| `KEYSTORE_KEY_PASSWORD` | Your key password |
| `KEYSTORE_KEY_ALIAS` | `upload` |
| `GOOGLE_SERVICES_JSON` | Full content of `google-services.json` from Firebase |

Then go to **Actions → Release Android AAB → Run workflow** and download the signed AAB artifact.
