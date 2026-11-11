# SmartPay HP — Sales Agent App

Flutter app for sales agents: register customers with full KYC, assign phone
loans with live pricing, submit for approval, collect deposits, initiate the
phone lock, and confirm handover. Same backend API as the web portal.

## 1. Generate the native project scaffold

```bash
flutter create --org com.smartpayug sales_agent_app
cd sales_agent_app
```

## 2. Copy these files in, overwriting the generated `lib/` and `pubspec.yaml`

```bash
flutter pub get
```

## 3. Set your API URL

Edit `lib/config.dart`:

```dart
static const String apiBaseUrl = 'https://app.smartpayug.com/api';
```

## 4. Add required permissions

**Android** — `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`, above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

`image_picker` handles storage/gallery access itself via the system picker on
modern Android — no separate storage permission needed for that path.

**iOS** — `ios/Runner/Info.plist`, add:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture KYC documents and phone handover photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach existing photos for KYC and handover.</string>
```

## 5. Run it

```bash
flutter run
```

## What's built

- **Login**
- **My Customers** — search agent's own registered pool, register new (name,
  phone, gender, NIN, 4 KYC photos, address, country, 2 guarantors), edit
  existing (KYC correction after a decline)
- **Assign Phone Loan** — Type → Name cascading dropdowns (pulled live from
  the catalog API), IMEI 1/2, colour, package selection, live price-band
  validation and loan summary computed client-side using the exact same
  formula as the server (`LoanPackage::calculateBreakdown` mirrored in
  `models/catalog.dart`)
- **My Loans** — list with status badges
- **Loan Detail** — the full status-driven workflow:
  - `draft` → Submit for Approval / Edit
  - `submitted_for_approval` → waiting banner
  - `declined` → reason shown, **Edit & Resubmit** (loops back into the
    assign-loan screen pre-filled) and **Edit KYC**
  - `approved` → Initiate live Mobile Money deposit through the SmartPay
    backend and MamboPay, poll the payment status while the customer enters
    their PIN, then show the deposit result and full attempt history
  - `deposit_paid` → Initiate the real phone-lock API with retry and attempt
    history; once locked, Confirm Handover with the 4-photo capture
    (2 required, 2 optional)
  - `active` / `defaulted` / `completed` → full repayment schedule

## Production payment configuration

The app uses the SmartPay production API base URL from `lib/config.dart`:

```text
https://app.smartpayug.com/api
```

The app does not call MamboPay directly and does not contain MamboPay credentials. The live backend performs MamboPay collection, status polling, payment settlement, schedule allocation, and phone-lock updates. The production backend must have `MamboPayProvider` bound to `MobileMoneyProviderInterface` and valid `MAMBOPAY_USER` and `MAMBOPAY_AUTH_KEY` values in its environment configuration.

The approved deposit amount is read-only in the app. The backend remains authoritative and replaces any client-supplied amount with the approved contract deposit amount. For Mobile Money, the app calls `/agent/loans/{loan}/deposit`, receives a pending payment ID, and polls `/agent/loans/{loan}/deposit/{payment}/status`. A successful response triggers the existing backend settlement logic.

## What's not built yet

- Push notifications (the web bell exists via Laravel database notifications;
  wiring Firebase Cloud Messaging into this app to alert agents the moment a
  loan is approved/declined is a natural next step, not yet done)
- Offline draft caching — the app requires connectivity throughout; if you
  need agents to register customers in low-signal areas and sync later,
  that's a bigger architectural change (local SQLite queue + background sync)
  worth scoping separately
- Bulk/offline IMEI scanning (barcode/QR scan instead of manual typing) —
  straightforward to add with a package like `mobile_scanner` if wanted
