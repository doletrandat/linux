# Lumia 730 source checkpoint, 2026-11-03

This branch consolidates the working build-source overlays without changing the
active build tree or device. The qualified Android device integration is in
[doletrandat/android_device_nokia_superman](https://github.com/doletrandat/android_device_nokia_superman).
Out-of-tree audio, RAM-shadow RMTFS, Radio HAL and current bridge sources remain
there. Stock firmware and device-specific NV/RAM captures are not redistributed.

The base source includes the accumulated SMP, RMI touch, IOMMU and DRM work.
Phone overlays preserve WCNSS startup, sensor calibration, Android quota support,
conservative stock-NTC and low-voltage battery policy, secure firmware decryption,
and the observed connected-scan Wi-Fi stability correction. The measured IADC
provider includes its later signed ADC conversion and exported current API.

`arch/arm/configs/lumia_superman_qualified.config` preserves the complete selected
configuration (SHA256 c9b1530c5bb11cc0349a2d019b4a6f0f1ecef82d07347cb1866f3f9afcfff626).
It is an exact configuration snapshot, not a newly minimized defconfig.

The separate Superman modem/audio DTS include files document the selected DT
additions. They are intentionally not silently enabled in the older board DTS.
`superman-qualified-flat.dts` preserves the actual qualified flattened DT source
used by the RPM audio correction. The running FDT SHA256 was
d721095e5eec1351ac17cd7a1fb3ef81b03ba8bd6818e22bca6cd953f3a4ca51.
Kernel notes SHA256 was
26f8016edc452a72b4b85e83754ca770c25439f358e39c28fa1b6a25cfc1bac1.

The source consolidation itself has not been rebuilt or deployed. Historical
hash-bound runtime qualification belongs to its specific selected images/modules,
not automatically to every checkout of this branch. In particular, current ADC
source is a later external-module update, and MMCC/RPM performance coupling
support was retained in builds while its unqualified OPP policy stayed inactive.
No speedup or unrestricted suspend qualification is claimed.

Physically heard speaker sound, normal Android microphone recording and duplex
cleanup are qualified in the device integration. SMS interfaces passed a cold
framework check. IPv4 data control is installed and its final framework check is
pending. Carrier calls/SMS/data, voice-call audio, actual charging and battery SOC
remain unresolved. Native deep suspend remains guarded.
