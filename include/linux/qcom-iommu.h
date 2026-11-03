/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_QCOM_IOMMU_H
#define _LINUX_QCOM_IOMMU_H
#include <linux/iommu.h>
#include <linux/kconfig.h>
#if IS_REACHABLE(CONFIG_QCOM_IOMMU)
bool qcom_iommu_domain_faulted(struct iommu_domain *domain);
#else
static inline bool qcom_iommu_domain_faulted(struct iommu_domain *domain)
{
	return false;
}
#endif
#endif
