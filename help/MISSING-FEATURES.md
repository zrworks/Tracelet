# Missing Premium Features in Tracelet

After auditing Tracelet's existing feature set against premium competitors, the following feature was identified as the highest-value addition. Other originally listed features (Attestation, Battery Budget Throttling, Unlimited Geofences) were found to **already exist** in Tracelet.

---

## ✅ Implemented: Tracelet Doctor (Diagnostic Widget)

> **Status**: Shipped in `tracelet_doctor` v1.0.0

A drop-in Flutter widget that visualizes the plugin's operational health:

```dart
TraceletDoctor.show(context);
```

See [packages/tracelet_doctor](../packages/tracelet_doctor/) for details.

---

## Remaining Candidate: Local Offline Reverse-Geocoding

> [!NOTE]
> Resolving coordinates to readable addresses in the background is usually done via cloud services (Google Maps, Mapbox), which are expensive and fail without network.

**Practical concerns**: A full street-level geocoding database is several GB. Viable only with coarse-granularity compression (city/zip code level, ~5 MB) or on-demand regional tile downloads. This remains a potential future addition but requires significant research into database size vs. resolution trade-offs.
