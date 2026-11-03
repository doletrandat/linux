/* SPDX-License-Identifier: GPL-2.0-only */
struct device;
/* Signed calibrated internal-sense microamps; negative on verified discharge. */
int superman_iadc_current_ua(struct device *dev,int *ua);
