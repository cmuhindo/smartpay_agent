# SmartPay Sales-Agent Production Payment Checklist

## What changed in the Flutter app

The approved initial-deposit amount is now read-only. The Mobile Money action calls the SmartPay agent deposit endpoint, which uses the live MamboPay provider on the backend. The app polls the payment-status endpoint while the customer enters the Mobile Money PIN. The simulated success/failure phone-lock buttons were replaced by one real `Initiate Phone Lock` action.

The Flutter app does not contain MamboPay credentials. It uses:

```text
https://app.smartpayug.com/api
```

All provider credentials and production URLs remain server-side in Laravel.

## Backend production verification

Run these commands on the SmartPay server. They do not initiate or charge a payment and do not print the secret values:

```bash
cd /var/www/smartpay

php artisan optimize:clear

php artisan tinker --execute="dump([
    'mobile_money_provider' => get_class(app(App\\Services\\Contracts\\MobileMoneyProviderInterface::class)),
    'device_lock_provider' => get_class(app(App\\Services\\Contracts\\DeviceLockProviderInterface::class)),
    'collect_url' => config('services.mambopay.collect_url'),
    'status_url' => config('services.mambopay.status_url'),
    'device_lock_url' => config('services.mambopay.device_lock_url'),
    'repayment_url' => config('services.mambopay.device_repayment_url'),
    'has_mambopay_user' => filled(config('services.mambopay.user')),
    'has_mambopay_auth_key' => filled(config('services.mambopay.auth_key')),
    'has_device_lock_key' => filled(config('services.mambopay.device_lock_api_key')),
    'has_device_lock_sign' => filled(config('services.mambopay.device_lock_sign')),
]);"

php artisan route:list | grep -E 'agent/loans/.*/deposit|agent/loans/.*/initiate-lock'
```

Expected provider classes are:

```text
App\\Services\\MamboPayProvider
App\\Services\\MamboPayDeviceLockProvider
```

Expected Mobile Money URLs are:

```text
https://api.mambopay.net/api/collectfunds
https://api.mambopay.net/api/checktxnstatus
```

The device-lock URLs should be the configured production MamboPay endpoints, not stub URLs. Do not print or share the actual credentials.

## Flutter build

On the development Mac:

```bash
cd /Users/charlesmuhindo/AndroidStudioProjects/sales_agent_app
flutter clean
flutter pub get
flutter analyze
flutter build apk --release
```

Install the release APK on a test device. Use a real approved loan and the customer’s consented Mobile Money number for the first controlled test. Do not test by entering a successful status manually.

## Controlled payment test

1. Open an approved loan in the sales-agent app.
2. Confirm that the approved deposit amount is read-only.
3. Keep the channel as `Mobile Money`.
4. Enter the customer’s Mobile Money number.
5. Tap `Initiate Mobile Money`.
6. Confirm that the customer receives the Mobile Money prompt.
7. Have the customer enter the PIN on the customer’s handset.
8. Confirm that the app changes from pending to confirmed or failed.
9. Confirm the payment record, deposit status, contract status, and phone-lock eligibility in SmartPay.
10. Only after a confirmed deposit, tap `Initiate Phone Lock` and verify the real lock-provider response.

Never use the old `Mark as Received`, `Log as Failed`, `Simulate Success`, or `Simulate Failure` actions for Mobile Money testing.
