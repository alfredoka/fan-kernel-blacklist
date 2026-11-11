# Dell Inspiron 580s: CPU fan revving up and down on Linux (`dell_smm_hwmon`)

English · [Castellano](README.es.md)

**Symptom:** on a Dell Inspiron 580s running Linux, the CPU fan keeps cycling up and
down every 7–12 seconds, roughly between 300 and 3300 rpm. It happens at idle and under
load, and the fan speed does not follow the CPU temperature. Once it starts, it keeps
going until you reboot. It did not happen on Windows.

**Cause:** the kernel driver `dell_smm_hwmon`. The Linux kernel already knows about this
BIOS bug and has a workaround for the Inspiron 580, but the workaround does not apply to
the 580s because of an exact model-name match.

**Fix:** blacklist the driver. The BIOS then controls the fan correctly on its own.

```sh
echo "blacklist dell_smm_hwmon" | sudo tee /etc/modprobe.d/blacklist-dell-smm.conf
sudo reboot
```

Unloading the module with `modprobe -r` is not enough. Once the BIOS is in the bad
state it stays there until a reboot.

---

## Am I affected?

You probably are if all of these are true:

1. It is a Dell desktop whose fan "breathes" up and down in a regular cycle even at idle.
2. `dell_smm_hwmon` is loaded:
   ```sh
   lsmod | grep dell_smm
   ```
3. Your model is not covered by the kernel's workaround. The kernel log never shows
   `Disabling fan type call due to BIOS bugs`:
   ```sh
   cat /sys/class/dmi/id/product_name
   journalctl -k | grep -i "fan type"
   ```

If your fan is fine until the CPU reaches about 70 °C and then starts cycling, and keeps
cycling after the CPU cools down, that is the same behaviour measured here.

## Root cause

`drivers/hwmon/dell-smm-hwmon.c` sends SMM calls to the Dell BIOS. On some machines,
issuing the `I8K_SMM_GET_FAN_TYPE` call breaks the BIOS fan control. The source code
documents it like this:

> On some machines once I8K_SMM_GET_FAN_TYPE is issued then CPU fan speed randomly going
> up and down due to bug in Dell SMM or BIOS.
> — [`dell-smm-hwmon.c`](https://github.com/torvalds/linux/blob/master/drivers/hwmon/dell-smm-hwmon.c),
> see also [kernel bug 100121](https://bugzilla.kernel.org/show_bug.cgi?id=100121)

The affected models go in `i8k_blacklist_fan_type_dmi_table`, and that table already
includes the Inspiron 580:

```c
{
	.ident = "Dell Inspiron 580",
	.matches = {
		DMI_EXACT_MATCH(DMI_SYS_VENDOR, "Dell Inc."),
		DMI_EXACT_MATCH(DMI_PRODUCT_NAME, "Inspiron 580 "),
	},
},
```

The 580s is the same machine in a slim chassis, but its DMI product name is
`Inspiron 580s`. `DMI_EXACT_MATCH` fails, so the driver never disables the call.
Checked against Ubuntu kernel 7.0.0-42 (7.0.14) and against `torvalds/linux` master as
of 2026-11-10.

The proper fix is a one-line DMI entry for `"Inspiron 580s"`. A bug report with a
suggested patch is in
[`reports/bug-dell-smm-hwmon-inspiron-580s.md`](reports/bug-dell-smm-hwmon-inspiron-580s.md).

## Test results

Test machine: Inspiron 580s, Core i3 530 (2 cores, 4 threads), BIOS A05, Ubuntu Server 26.04.

| | With `dell_smm_hwmon` | Driver blacklisted |
|---|---|---|
| Idle | cycles ~300 → ~2800 rpm every 10–12 s | quiet, steady |
| Full load, up to ~70 °C | steady ~1015 rpm | quiet, steady |
| Full load, above ~70 °C | cycles 505–2428 rpm, ~7 s period | quiet, steady |
| After the load stops | keeps cycling at 48 °C (321–3269 rpm) | quiet, steady |
| 5 min at 100 % on all 4 threads | — | stable at 72–73 °C, max 74 °C |

Without the driver, rpm cannot be read, so the fan was judged by ear and temperatures
come from `coretemp`. The 5-minute plateau at 72–73 °C, far below the 89 °C max and
105 °C critical, shows that the BIOS fan curve works fine on its own. The fan and the
thermal paste were never the problem.

Things ruled out along the way:

- No ACPI thermal zones, no ACPI fan device, no `thermald`, `fancontrol`, `i8kmon` or
  `tlp`. Nothing else in the system drives the fan.
- SATA link power management (ALPM) changes made no difference.
- BIOS update: other owners report that going from A03 to A07 does not help.

## Trade-offs

With the driver blacklisted you lose fan rpm readout (`fan1_input`) and manual fan
control (`pwm1`). CPU temperatures are still available through `coretemp`
(`sensors`, `/sys/class/hwmon/*/temp*_input`).

If you need manual control instead, a sequence that pins the fan with the driver loaded
is `pwm1_enable=1`, then `pwm1=255`, then `pwm1=128`. That gives a steady ~520 rpm, but
then nothing raises the fan when the CPU gets hot. The hardware only has three levels:
0, 128 (~509 rpm) and 255 (~4456 rpm).

## Undo

```sh
sudo rm /etc/modprobe.d/blacklist-dell-smm.conf
sudo modprobe dell_smm_hwmon
```

## Files

- [`reports/bug-dell-smm-hwmon-inspiron-580s.md`](reports/bug-dell-smm-hwmon-inspiron-580s.md):
  the upstream bug report (to `linux-hwmon@vger.kernel.org`) with the suggested patch.
- [`scripts/carga-larga.sh`](scripts/carga-larga.sh): the load test. It runs all 4
  threads at 100 % for up to 5 minutes, prints the CPU temperature every second and
  stops at 80 °C.
- [`reports/carga-5min-2026-11-10.log`](reports/carga-5min-2026-11-10.log): the
  temperature log of the 5-minute test.
- [`NOTAS.md`](NOTAS.md): the full investigation log (Spanish).

## Status

- Workaround applied and confirmed on 2026-11-10.
- Upstream report drafted, not yet sent. This section will link to the
  lore.kernel.org thread once it is.

If this fixes your machine too, especially another model with the same symptom, please
open an issue with your `product_name`. That helps get the kernel table updated.
