# Estado

Actualizado el 2026-11-10 (GMT-3).

## Hecho

- Causa identificada: `dell_smm_hwmon` (ver README.md y NOTAS.md).
- Blacklist puesta en `/etc/modprobe.d/blacklist-dell-smm.conf`. Alfred decidió dejarla
  como solución permanente.
- Pruebas de carga de 60 s, hasta 70 °C y de 5 min: sin picos y temperatura estable.
- Se encontró en el código del kernel por qué la excepción del Inspiron 580 no cubre la 580s.
- Borrador del reporte en inglés: `reports/bug-dell-smm-hwmon-inspiron-580s.md`.

## Próximo paso

1. Alfred manda el reporte por mail en texto plano a Pali Rohár y Guenter Roeck, con copia a
   `linux-hwmon@vger.kernel.org`. Las instrucciones están al principio del borrador.
2. Opcional: cargarlo también en Launchpad con `ubuntu-bug linux`, y agregar el link de
   lore.kernel.org.
3. Si piden probar el parche: compilar el módulo con la entrada `"Inspiron 580s"`, sacar
   la blacklist y repetir la carga hasta 70 °C.

## Repo

- Público en https://github.com/alfredoka/fan-kernel-blacklist (subido el 2026-11-10).
