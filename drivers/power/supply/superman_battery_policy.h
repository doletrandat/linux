/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _SUPERMAN_BATTERY_POLICY_H
#define _SUPERMAN_BATTERY_POLICY_H

/* Stock Superman NTC margins [-7,+2] C, trailing rate 1.5 C/min, tail 10 C. */
struct smbb_superman_temp_policy {
	bool initialized;
	unsigned long long last_ms;
	int low_mc;
	int high_mc;
};

static bool smbb_superman_temp_update(struct smbb_superman_temp_policy *p,
		int decic, unsigned long long now_ms)
{
	int low, high, step;
	unsigned long long elapsed;

	if (decic < -300 || decic > 800) {
		p->initialized = false;
		return false;
	}
	low = decic * 100 - 7000;
	high = decic * 100 + 2000;
	/* Unknown history or a missed monitor deadline starts with full tail. */
	if (!p->initialized || now_ms < p->last_ms || now_ms - p->last_ms > 15000) {
		p->low_mc = low - 10000;
		p->high_mc = high + 10000;
	} else {
		elapsed = now_ms - p->last_ms;
		step = elapsed / 40; /* 25 milli-Celsius per second */
		p->low_mc = p->low_mc + step < low ? p->low_mc + step : low;
		if (p->low_mc < low - 10000)
			p->low_mc = low - 10000;
		p->high_mc = p->high_mc - step > high ? p->high_mc - step : high;
		if (p->high_mc > high + 10000)
			p->high_mc = high + 10000;
	}
	p->last_ms = now_ms;
	p->initialized = true;
	return p->low_mc >= 10000 && p->high_mc < 45000;
}

/* Stock 3.30 V empty threshold; this is not a state-of-charge estimate. */
struct smbb_superman_voltage_policy {
	bool initialized;
	bool critical;
	unsigned long long low_since_ms;
	unsigned long long last_ms;
};

static bool smbb_superman_voltage_critical(
		const struct smbb_superman_voltage_policy *p,
		unsigned long long now_ms)
{
	return p->initialized && p->critical && now_ms >= p->last_ms &&
		now_ms - p->last_ms <= 15000;
}

static bool smbb_superman_voltage_update(struct smbb_superman_voltage_policy *p,
		int uv, unsigned long long now_ms)
{
	/* Invalid/missing ADC data and recovered voltage leave capacity unknown. */
	if (uv <= 0 || uv >= 3300000) {
		p->initialized = false;
		p->critical = false;
		return false;
	}
	if (!p->initialized || now_ms < p->last_ms || now_ms - p->last_ms > 15000)
		p->low_since_ms = now_ms;
	p->last_ms = now_ms;
	p->initialized = true;
	/* Reject brief load dips; require a continuous ten-second low interval. */
	p->critical = now_ms - p->low_since_ms >= 10000;
	return p->critical;
}

#endif
