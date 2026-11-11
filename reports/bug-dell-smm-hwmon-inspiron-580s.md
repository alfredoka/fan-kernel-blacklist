# Bug report draft — dell-smm-hwmon: Inspiron 580s missing from fan type blacklist

Where to send (plain-text email, no HTML, no attachments needed):

- To: Pali Rohár <pali@kernel.org>, Guenter Roeck <linux@roeck-us.net>
- Cc: linux-hwmon@vger.kernel.org
- Archive (searchable afterwards): https://lore.kernel.org/linux-hwmon/

Optional mirror for Ubuntu users: run `ubuntu-bug linux` on the machine (it opens a
Launchpad bug with the logs attached) and paste the same text, adding the lore.kernel.org
link once the email is in the archive.

---

Subject: [BUG] hwmon: (dell-smm) CPU fan oscillates on Dell Inspiron 580s — not covered by the "Inspiron 580 " fan type blacklist entry

Hi,

On a Dell Inspiron 580s the CPU fan keeps cycling between ~300 and ~3300 rpm every
7–12 seconds while dell-smm-hwmon is loaded. With the module blacklisted the problem
disappears completely. The symptom matches the comment above
i8k_blacklist_fan_type_dmi_table ("once I8K_SMM_GET_FAN_TYPE is issued then CPU fan
speed randomly going up and down"), and that table already contains the
Inspiron 580. However, the entry uses

    DMI_EXACT_MATCH(DMI_PRODUCT_NAME, "Inspiron 580 ")

while the 580s reports "Inspiron 580s", so the exact match fails and the fan type
call is not disabled. The 580 and the 580s are the same machine; the only
difference is the chassis size (the "s" is the slim version).

Hardware / software
-------------------
  sys_vendor:     Dell Inc.
  product_name:   Inspiron 580s     (od -c: "I n s p i r o n   5 8 0 s \n", no trailing space)
  board_name:     033FF6
  bios_version:   A05 (05/12/2010)  — A07 is the latest; other users report A07 does not help
  CPU:            Intel Core i3 530 (2C/4T, no turbo)
  Kernel:         Ubuntu 7.0.0-42-generic (7.0.14); the table is unchanged in
                  torvalds/linux master as of 2026-11-10
  No ACPI thermal zones, no ACPI fan, thermald inactive, no fancontrol/i8kmon/tlp,
  so nothing else in the system drives the fan.

When the module was loaded, the kernel log never printed
"Disabling fan type call due to BIOS bugs", which confirms the DMI entry does not match.

Observations with dell-smm-hwmon loaded (fan1 = CPU fan, fan2 = board fan)
-------------------------------------------------------------------------
- fan1 cycles ~300 → ~2800 rpm every 10–12 s, both idle (39–42 °C) and under full
  load. It does not follow temperature. fan2 stays steady at ~753 rpm.
- Manual mode (pwm1_enable=1, pwm1=128): target drops to ~509 rpm, but spikes of
  1400–2450 rpm every 10–12 s continue at first. After pwm1=255 then pwm1=128 the fan
  stays pinned at 520–524 rpm with no spikes. Only three levels exist: 0, 128
  (~509 rpm) and 255 (~4456 rpm).
- Giving control back (pwm1_enable=2) leaves the BIOS stuck at ~4550 rpm.
- After a cold boot the BIOS controls the fan smoothly (~1025 rpm, steady) until the
  CPU reaches ~70 °C under load. From then on the oscillation starts (505–2428 rpm,
  ~7 s period) and does NOT stop when the CPU cools back to 48 °C (321–3269 rpm every
  ~11 s at idle). Only a reboot clears it.
- Unloading the module (modprobe -r) while the fan is already oscillating does not
  stop it; the BIOS state persists until reboot.

Observations with dell-smm-hwmon blacklisted from boot
------------------------------------------------------
(no rpm readout available; fan behaviour judged by ear, temperatures from coretemp)
- 60 s at 100 % on all 4 threads: 42 → 65 °C. Fan quiet, no oscillation.
- Load until 70 °C (reached after 85 s), held 15 s: no oscillation, neither during
  load nor after.
- 5 min at 100 % on all 4 threads: 44 °C idle, 70 °C at 75 s, then stable at
  72–73 °C (max 74 °C). Back to 48 °C one minute after stopping. The fan is quiet the
  whole time and never oscillates. The temperature plateau shows the BIOS fan curve
  works correctly on its own.

Interpretation
--------------
The BIOS fan control on this machine gets into a bad state once the driver touches
it, which is the I8K_SMM_GET_FAN_TYPE bug already documented for the Inspiron 580,
Studio XPS 8000/8100 and Inspiron 3505. I have not yet tested a kernel with the fan
type call disabled (as opposed to the whole module blacklisted), so I cannot rule out
that another SMM call is involved; I am happy to test a patch.

Suggested change (untested)
---------------------------
--- a/drivers/hwmon/dell-smm-hwmon.c
+++ b/drivers/hwmon/dell-smm-hwmon.c
@@ static const struct dmi_system_id i8k_blacklist_fan_type_dmi_table[] __initconst = {
 	{
 		.ident = "Dell Inspiron 580",
 		.matches = {
 			DMI_EXACT_MATCH(DMI_SYS_VENDOR, "Dell Inc."),
 			DMI_EXACT_MATCH(DMI_PRODUCT_NAME, "Inspiron 580 "),
 		},
 	},
+	{
+		.ident = "Dell Inspiron 580s",
+		.matches = {
+			DMI_EXACT_MATCH(DMI_SYS_VENDOR, "Dell Inc."),
+			DMI_EXACT_MATCH(DMI_PRODUCT_NAME, "Inspiron 580s"),
+		},
+	},

Workaround for affected users
-----------------------------
  echo "blacklist dell_smm_hwmon" | sudo tee /etc/modprobe.d/blacklist-dell-smm.conf
  reboot

(The module is not in the initramfs on Ubuntu, so no update-initramfs is needed.)
The BIOS then controls the fan correctly; the cost is losing fan rpm readout and
pwm control.

Thanks,
<name>
