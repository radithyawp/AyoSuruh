/// Release-facing feature switches.
///
/// Voucher infrastructure is intentionally preserved while the customer-facing
/// voucher experience stays hidden during the early Ayo Suruh launch phase.
/// Re-enable later by changing [vouchersEnabled] to true and shipping an update.
abstract final class AyoFeatureFlags {
  static const bool vouchersEnabled = false;
}
