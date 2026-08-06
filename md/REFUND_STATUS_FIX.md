# Refund Status Label Fix

Patch ini hanya memperjelas status final refund.

- `refund_requests.status = refunded` ditampilkan sebagai **Refund Disetujui**.
- `payments.status = refunded` ditampilkan sebagai **Sudah Direfund**.
- Notifikasi backend menggunakan istilah **Refund Disetujui**.

Tidak ada migration SQL tambahan.

Setelah menyalin patch, deploy ulang:

```powershell
npx supabase functions deploy request-midtrans-refund
npx supabase functions deploy refresh-midtrans-status
npx supabase functions deploy midtrans-payment-webhook --no-verify-jwt
```
