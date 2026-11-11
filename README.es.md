# fan-kernel-blacklist

[English](README.md) · Castellano

En la Dell Inspiron 580s el ventilador del procesador subía y bajaba cada 7 a 12 s, entre
~300 y ~3300 rpm. La causa es el driver del kernel `dell_smm_hwmon`, y la solución es no
cargarlo.

## Solución aplicada (2026-11-10)

```
echo "blacklist dell_smm_hwmon" | sudo tee /etc/modprobe.d/blacklist-dell-smm.conf
sudo reboot
```

El driver no está en el initramfs, así que no hace falta `update-initramfs`. Con eso la
BIOS maneja sola el ventilador y lo hace bien. Lo que se pierde es la lectura de las rpm y
el control manual (`pwm1`).

Para deshacerlo: `sudo rm /etc/modprobe.d/blacklist-dell-smm.conf` y
`sudo modprobe dell_smm_hwmon`.

## Por qué pasa

El kernel ya conoce este bug. `drivers/hwmon/dell-smm-hwmon.c` tiene la tabla
`i8k_blacklist_fan_type_dmi_table` para los equipos donde la llamada
`I8K_SMM_GET_FAN_TYPE` hace que "CPU fan speed randomly going up and down". El Inspiron
580 figura ahí, pero comparado con el nombre exacto `"Inspiron 580 "`. Esta máquina
reporta `"Inspiron 580s"`, el mismo equipo en gabinete chico, así que la excepción no se
aplica.

## Resultado

Con el driver bloqueado, 5 minutos al 100 % en los 4 hilos dejan la CPU estable en
72–73 °C (máximo 74 °C, crítico 105 °C). El ventilador queda silencioso y sin picos. El
ventilador y la pasta térmica están bien.

## Archivos

- `NOTAS.md`: la bitácora completa de las pruebas.
- `STATE.md`: dónde quedó y qué falta.
- `reports/bug-dell-smm-hwmon-inspiron-580s.md`: el reporte en inglés para el kernel.
- `reports/carga-5min-2026-11-10.log`: las temperaturas de la prueba de 5 minutos.
- `scripts/carga-larga.sh`: la prueba de carga, que muestra la temperatura cada 1 s y corta a 80 °C.
