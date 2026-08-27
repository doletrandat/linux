/* SPDX-License-Identifier: GPL-2.0-or-later */
/*
 * Copyright (c) 2012 Linaro Limited.
 */

#include <linux/init.h>
#include <linux/irqchip/arm-gic-v3.h>
#include <linux/linkage.h>
#include <asm/assembler.h>
#include <asm/virt.h>

.arch armv7-a

#ifndef ZIMAGE
/*
 * For the kernel proper, we need to find out the CPU boot mode long after
 * boot, so we need to store it in a writable variable.
 *
 * This is not in .bss, because we set it sufficiently early that the boot-time
 * zeroing of .bss would clobber it.
 */
.data
	.align	2
ENTRY(__boot_cpu_mode)
	.long	0
.text

	/*
	 * Save the primary CPU boot mode. Requires 2 scratch registers.
	 */
	.macro	store_primary_cpu_mode	reg1, reg2
	mrs	\reg1, cpsr
	and	\reg1, \reg1, #MODE_MASK
	str_l	\reg1, __boot_cpu_mode, \reg2
	.endm

	/*
	 * Compare the current mode with the one saved on the primary CPU.
	 * If they don't match, record that fact. The Z bit indicates
	 * if there's a match or not.
	 * Requires 2 additional scratch registers.
	 */
	.macro	compare_cpu_mode_with_primary mode, reg1, reg2
	adr_l	\reg2, __boot_cpu_mode
	ldr	\reg1, [\reg2]
	cmp	\mode, \reg1		@ matches primary CPU boot mode?
	orrne	\reg1, \reg1, #BOOT_CPU_MODE_MISMATCH
	strne	\reg1, [\reg2]		@ record what happened and give up
	.endm

#else	/* ZIMAGE */

	.macro	store_primary_cpu_mode	reg1:req, reg2:req
	.endm

/*
 * The zImage loader only runs on one CPU, so we don't bother with mult-CPU
 * consistency checking:
 */
	.macro	compare_cpu_mode_with_primary mode, reg1, reg2
	cmp	\mode, \mode
	.endm

#endif /* ZIMAGE */

/*
 * Hypervisor stub installation functions.
 *
 * These must be called with the MMU and D-cache off.
 * They are not ABI compliant and are only intended to be called from the kernel
 * entry points in head.S.
 */
@ Call this from the primary CPU
ENTRY(__hyp_stub_install)
	store_primary_cpu_mode	r4, r5
ENDPROC(__hyp_stub_install)

	@ fall through...

@ Secondary CPUs should call here
ENTRY(__hyp_stub_install_secondary)
	mrs	r4, cpsr
	and	r4, r4, #MODE_MASK

	/*
	 * If the secondary has booted with a different mode, give up
	 * immediately.
	 */
	compare_cpu_mode_with_primary	r4, r5, r6
	retne	lr

	/*
	 * Once we have given up on one CPU, we do not try to install the
	 * stub hypervisor on the remaining ones: because the saved boot mode
	 * is modified, it can't compare equal to the CPSR mode field any
	 * more.
	 *
	 * Otherwise...
	 */

	cmp	r4, #HYP_MODE

#ifndef ZIMAGE
	bne	.Llumia_hyp_stub_done	@ diagnostic return for the boot CPU
#else
	retne	lr			@ give up if the CPU is not in HYP mode
#endif

/*
 * Configure HSCTLR to set correct exception endianness/instruction set
 * state etc.
 * Turn off all traps
 * Eventually, CPU-specific code might be needed -- assume not for now
 *
 * This code relies on the "eret" instruction to synchronize the
 * various coprocessor accesses. This is done when we switch to SVC
 * (see safe_svcmode_maskall).
 */
	@ Now install the hypervisor stub:
	W(adr)	r7, __hyp_stub_vectors
	mcr	p15, 4, r7, c12, c0, 0	@ set hypervisor vector base (HVBAR)

	@ Disable all traps, so we don't get any nasty surprise
	mov	r7, #0
	mcr	p15, 4, r7, c1, c1, 0	@ HCR
	mcr	p15, 4, r7, c1, c1, 2	@ HCPTR
	mcr	p15, 4, r7, c1, c1, 3	@ HSTR

THUMB(	orr	r7, #(1 << 30)	)	@ HSCTLR.TE
ARM_BE8(orr	r7, r7, #(1 << 25))     @ HSCTLR.EE
	mcr	p15, 4, r7, c1, c0, 0	@ HSCTLR

	mrc	p15, 4, r7, c1, c1, 1	@ HDCR
	and	r7, #0x1f		@ Preserve HPMN
	mcr	p15, 4, r7, c1, c1, 1	@ HDCR

	@ Make sure NS-SVC is initialised appropriately
	mrc	p15, 0, r7, c1, c0, 0	@ SCTLR
	orr	r7, #(1 << 5)		@ CP15 barriers enabled
	bic	r7, #(3 << 7)		@ Clear SED/ITD for v8 (RES0 for v7)
	bic	r7, #(3 << 19)		@ WXN and UWXN disabled
	mcr	p15, 0, r7, c1, c0, 0	@ SCTLR

	mrc	p15, 0, r7, c0, c0, 0	@ MIDR
	mcr	p15, 4, r7, c0, c0, 0	@ VPIDR

	mrc	p15, 0, r7, c0, c0, 5	@ MPIDR
	mcr	p15, 4, r7, c0, c0, 5	@ VMPIDR

#if !defined(ZIMAGE) && defined(CONFIG_ARM_ARCH_TIMER)
	@ make CNTP_* and CNTPCT accessible from PL1
	mrc	p15, 0, r7, c0, c1, 1	@ ID_PFR1
	ubfx	r7, r7, #16, #4
	teq	r7, #0
	beq	1f
	mrc	p15, 4, r7, c14, c1, 0	@ CNTHCTL
	orr	r7, r7, #3		@ PL1PCEN | PL1PCTEN
	mcr	p15, 4, r7, c14, c1, 0	@ CNTHCTL
	mov	r7, #0
	mcrr	p15, 4, r7, r7, c14	@ CNTVOFF

	@ Disable virtual timer in case it was counting
	mrc	p15, 0, r7, c14, c3, 1	@ CNTV_CTL
	bic	r7, #1			@ Clear ENABLE
	mcr	p15, 0, r7, c14, c3, 1	@ CNTV_CTL
1:
#endif

#ifdef CONFIG_ARM_GIC_V3
	@ Check whether GICv3 system registers are available
	mrc	p15, 0, r7, c0, c1, 1	@ ID_PFR1
	ubfx	r7, r7, #28, #4
	teq	r7, #0
	beq	2f

	@ Enable system register accesses
	mrc	p15, 4, r7, c12, c9, 5	@ ICC_HSRE
	orr	r7, r7, #(ICC_SRE_EL2_ENABLE | ICC_SRE_EL2_SRE)
	mcr	p15, 4, r7, c12, c9, 5	@ ICC_HSRE
	isb

	@ SRE bit could be forced to 0 by firmware.
	@ Check whether it sticks before accessing any other sysreg
	mrc	p15, 4, r7, c12, c9, 5	@ ICC_HSRE
	tst	r7, #ICC_SRE_EL2_SRE
	beq	2f
	mov	r7, #0
	mcr	p15, 4, r7, c12, c11, 0	@ ICH_HCR
2:
#endif

#ifndef ZIMAGE
.Llumia_hyp_stub_done:
	/*
	 * Temporary Lumia 730 no-UART checkpoint. LK remains resident at its
	 * identity-mapped physical address, and its pulse helper is already
	 * proven callable with the MMU and D-cache off. Preserve the Linux boot
	 * registers and emit 13 pulses immediately before returning to head.S.
	 * Keep this out of the zImage build so its decompressor layout is exact.
	 */
	push	{r0-r3, r12, lr}
	mov	r0, #13
	movw	r12, #0x0248
	movt	r12, #0x0730
	blx	r12
	pop	{r0-r3, r12, lr}
#endif

	bx	lr			@ The boot CPU mode is left in r4.
ENDPROC(__hyp_stub_install_secondary)

#ifndef ZIMAGE
/*
 * Temporary Lumia 730 no-UART checkpoint after safe_svcmode_maskall().
 * The SVC stack is not assumed valid yet, so save the boot registers and
 * return address in LK's free identity-mapped scratch area and use a fixed
 * temporary stack while calling the resident LK pulse helper.
 */
ENTRY(lumia_head_diag14)
	ldr	r12, =0x073ff000
	str	r0, [r12, #0]
	str	r1, [r12, #4]
	str	r2, [r12, #8]
	str	r3, [r12, #12]
	str	sp, [r12, #16]
	str	lr, [r12, #20]
	str	r9, [r12, #24]
	add	sp, r12, #0x100
	mov	r0, #14
	movw	r12, #0x0248
	movt	r12, #0x0730
	blx	r12
	ldr	r12, =0x073ff000
	ldr	r0, [r12, #0]
	ldr	r1, [r12, #4]
	ldr	r2, [r12, #8]
	ldr	r3, [r12, #12]
	ldr	sp, [r12, #16]
	ldr	lr, [r12, #20]
	mrc	p15, 0, r9, c0, c0		@ preserve the replaced CPU-ID operation
	bx	lr
ENDPROC(lumia_head_diag14)

ENTRY(lumia_head_diag15)
	ldr	r12, =0x073ff000
	str	r0, [r12, #0]
	str	r1, [r12, #4]
	str	r2, [r12, #8]
	str	r3, [r12, #12]
	str	sp, [r12, #16]
	str	lr, [r12, #20]
	str	r9, [r12, #24]
	add	sp, r12, #0x100
	mov	r0, #15
	movw	r12, #0x0248
	movt	r12, #0x0730
	blx	r12
	ldr	r12, =0x073ff000
	ldr	r0, [r12, #0]
	ldr	r1, [r12, #4]
	ldr	r2, [r12, #8]
	ldr	r3, [r12, #12]
	ldr	sp, [r12, #16]
	ldr	lr, [r12, #20]
	ldr	r9, [r12, #24]
	movs	r10, r5				@ preserve the replaced processor check
	bx	lr
ENDPROC(lumia_head_diag15)

/* Emit three final pulses after processor setup, immediately before MMU-on. */
ENTRY(lumia_head_diag19)
	ldr	r12, =0x073ff000
	str	r0, [r12, #0]
	str	r1, [r12, #4]
	str	r2, [r12, #8]
	str	r3, [r12, #12]
	str	sp, [r12, #16]
	str	lr, [r12, #20]
	add	sp, r12, #0x100
	mov	r0, #3
	movw	r12, #0x0248
	movt	r12, #0x0730
	blx	r12
	ldr	r12, =0x073ff000
	ldr	r0, [r12, #0]
	ldr	r1, [r12, #4]
	ldr	r2, [r12, #8]
	ldr	r3, [r12, #12]
	ldr	sp, [r12, #16]
	ldr	lr, [r12, #20]
	bx	lr
ENDPROC(lumia_head_diag19)
#endif

__hyp_stub_do_trap:
#ifdef ZIMAGE
	teq	r0, #HVC_SET_VECTORS
	bne	1f
	/* Only the ZIMAGE stubs can change the HYP vectors */
	mcr	p15, 4, r1, c12, c0, 0	@ set HVBAR
	b	__hyp_stub_exit
#endif

1:	teq	r0, #HVC_SOFT_RESTART
	bne	2f
	bx	r1

2:	ldr	r0, =HVC_STUB_ERR
	__ERET

__hyp_stub_exit:
	mov	r0, #0
	__ERET
ENDPROC(__hyp_stub_do_trap)

/*
 * __hyp_set_vectors is only used when ZIMAGE must bounce between HYP
 * and SVC. For the kernel itself, the vectors are set once and for
 * all by the stubs.
 */
ENTRY(__hyp_set_vectors)
	mov	r1, r0
	mov	r0, #HVC_SET_VECTORS
	__HVC(0)
	ret	lr
ENDPROC(__hyp_set_vectors)

ENTRY(__hyp_soft_restart)
	mov	r1, r0
	mov	r0, #HVC_SOFT_RESTART
	__HVC(0)
	ret	lr
ENDPROC(__hyp_soft_restart)

.align 5
ENTRY(__hyp_stub_vectors)
__hyp_stub_reset:	W(b)	.
__hyp_stub_und:		W(b)	.
__hyp_stub_svc:		W(b)	.
__hyp_stub_pabort:	W(b)	.
__hyp_stub_dabort:	W(b)	.
__hyp_stub_trap:	W(b)	__hyp_stub_do_trap
__hyp_stub_irq:		W(b)	.
__hyp_stub_fiq:		W(b)	.
ENDPROC(__hyp_stub_vectors)
