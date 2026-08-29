# Future Remove Ads Forever plan

SendFit currently injects `FreeEntitlementProvider`, whose `adsEnabled` value is true. No StoreKit types, purchase flow, subscription, or paywall are present.

To add **SendFit Pro / Remove Ads Forever** later:

1. Create and configure one StoreKit 2 non-consumable product.
2. Implement `StoreKitEntitlementProvider: EntitlementProviding` that derives `adsEnabled` from the verified entitlement.
3. Inject it in `SendFitModel` composition instead of `FreeEntitlementProvider`.
4. Keep `AdPolicy` as the only decision point. Entitled users automatically suppress the compression banner, interstitial preload, and interstitial presentation.
5. Avoid starting Google Mobile Ads for entitled users when practical.

This does not require changes to `VideoCompressionService`, `VideoImportService`, `IncomingVideoRouter`, `ExportService`, compression calculations, or document opening.
