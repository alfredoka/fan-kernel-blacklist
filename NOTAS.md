# Investigación: ventilador que sube y baja (Dell Inspiron 580s)

Bitácora de las pruebas del 2026-11-10, horas en GMT-3. Se movió acá desde las notas de otro proyecto.

- Equipo: Dell Inspiron 580s con un i3 530 (2 núcleos, 4 hilos, sin turbo) y BIOS
  A05 del 12/05/2010. En el sitio de Dell figura la A07 como última.
- El ventilador del procesador va de ~300 a ~2800 rpm cada 10–12 s, en reposo
  (39–42 °C) y también con la CPU al 100 %. No sigue la temperatura.
- El de la placa queda fijo en ~753 rpm. La BIOS lo controla (`dell_smm`,
  `pwm1_enable=2`); leer `pwm1` da "No data available".
- Prueba de carga de 75 s en los 4 hilos: de 43 a 57 °C en 3 s y 71 °C al final,
  todavía subiendo. Al cortar, 50 °C en 5 s. Máximo 89 °C, crítico 105 °C.
- Conclusión: la pasta o el polvo le restan margen, pero no causan el ruido. Hay
  casos iguales del 580 en el foro de Dell. Uno pasó de A03 a A07 y no le cambió.
- Pruebas del 2026-11-10 a las 20:49–20:58 (GMT-3):
  - **ALPM SATA** (`med_power_with_dipm`): no cambió nada. Se revirtió a
    `max_performance`, porque `keep_firmware_settings` no se puede volver a escribir y
    solo vuelve al reiniciar.
  - **Control manual** (`pwm1_enable=1`, `pwm1=128`): `dell_smm` lo acepta y el
    objetivo baja a 509 rpm. Igual sigue con picos de 1400–2450 rpm cada 10–12 s, así
    que **la causa no es la BIOS**.
  - **Al máximo** (`pwm1=255`): queda parejo en 3600–4470 rpm.
  - Al devolverle el control (`pwm1_enable=2`), la BIOS quedó en modo "a fondo",
    parejo en ~4550 rpm.
  - Después se corrió `pwm1_enable=1` + `pwm1=255` y luego `pwm1=128`. Resultado:
    **clavado en 520–524 rpm, sin picos**, con la CPU en 32–36 °C (21:05, GMT-3).
- **Diagnóstico corregido: el ventilador está sano; los picos los mete la BIOS.** En
  la primera prueba en nivel 1 la BIOS seguía interviniendo cada 10–12 s. Con esta
  secuencia quedó afuera, igual que con `dell-bios-fan-control 0`.
- Solo hay tres niveles: 0 (apagado), 128 (~509 rpm) y 255 (~4456 rpm). No existe una
  velocidad intermedia.
- **Riesgo:** en manual nadie sube el ventilador si la CPU calienta.
- ~~Pendiente: script de control manual, servicio de systemd y cambio de pasta.~~ Ya no
  hacen falta: se resolvió con la blacklist del driver (ver el cierre más abajo).
- **Después de apagar y reiniciar (2026-11-10, 21:15 GMT-3):** la BIOS retomó el
  control (`pwm1_enable=2`) y el ventilador quedó parejo en 1025–1027 rpm durante 30 s
  seguidos, con la CPU en 41–45 °C. No aparecieron los picos de cada 10–12 s. Falta ver
  si se mantiene con el tiempo y con carga; si vuelven, aplicar la secuencia manual.
- **Prueba de carga a las 21:18 (GMT-3), con la BIOS al mando:** 30 s al 100 % en los
  4 hilos, justo después de otra carga de 30 s que no se registró. Durante 19 s quedó
  parejo en ~1015 rpm, mientras la CPU pasaba de 56 a 69 °C. Al llegar a ~70 °C
  volvieron los picos: 505–2428 rpm, con un ciclo de unos 7 s. Al cortar la carga, la
  CPU bajó a 48 °C en 7 s, pero **los picos siguieron en reposo** (321–3269 rpm cada
  ~11 s). Lo que muestra: el ventilador anda bien hasta que la CPU toca ~70 °C. Desde
  ahí la BIOS entra en el modo que sube y baja y no sale aunque la CPU se enfríe. Así
  se explica que antes del reinicio subiera y bajara también en reposo.
- **¿Linux controla el ventilador? (revisado a las 21:20, GMT-3).** Alfred dice que con
  Windows no pasaba. Lo que hay en Linux:
  - No hay zonas térmicas ACPI (`/sys/class/thermal/thermal_zone*` no existe) ni un
    ventilador ACPI, así que no hay ningún gobernador del kernel que mueva el
    ventilador.
  - `thermald` está instalado pero inactivo. No están `fancontrol`, `i8kmon` ni `tlp`.
  - `intel_powerclamp` está cargado, en 0.
  - El único que habla con el ventilador es `dell_smm_hwmon`, que lo hace con
    llamadas SMM a la BIOS. Las hace cada vez que alguien lee las rpm (nuestras
    mediciones de 1 s) o cuando se escribe `pwm1`. Registra dos cooling devices,
    `dell-smm-fan1` y `dell-smm-fan2`, pero sin zonas térmicas ninguno los maneja.
  - Hipótesis de conflicto: que esas llamadas SMM le alteren el control a la BIOS. Hay
    Dell en los que el driver tiene funciones bloqueadas por eso. Windows no carga
    nada parecido.
  - Prueba propuesta: `sudo modprobe -r dell_smm_hwmon` y escuchar. Sin el driver no
    se pueden leer las rpm, así que la prueba es de oído. Si se calma, ponerlo en la
    blacklist. Si no, probar con `acpi_osi` en el arranque, porque la BIOS puede
    comportarse distinto según el sistema operativo que cree que tiene.
  - **Resultado (21:27, GMT-3):** Alfred descargó el driver desde la ventana 1 de tmux
    y el ventilador sigue igual, de oído. Las llamadas SMM no son las que lo
    mantienen en ese modo. Sin embargo, no queda descartado que el driver lo haya
    disparado, porque la BIOS ya estaba en ese modo antes de descargarlo. La prueba
    que lo resuelve: arrancar con el driver en la blacklist, cargar la CPU hasta
    ~70 °C y escuchar.
  - Sobre `acpi_osi`: Linux ya responde que sí a los nombres de Windows, así que lo
    más probable es que no cambie nada.
  - Otra explicación posible para "con Windows no pasaba": que con Windows la CPU
    nunca llegara a ~70 °C, por ejemplo si había menos polvo.
  - **Prueba definitiva en curso (21:31, GMT-3):** Alfred eligió la opción 1. Se creó
    `/etc/modprobe.d/blacklist-dell-smm.conf` con `blacklist dell_smm_hwmon`. El driver
    no está en el initramfs, así que no hace falta regenerarlo. Después del reinicio
    hay que:
    1. Confirmar con `lsmod | grep dell_smm` que el driver no cargó.
    2. Cargar los 4 hilos hasta ~70 °C. Sin el driver solo se lee la temperatura, con
       `coretemp`.
    3. Que Alfred escuche si aparecen los picos.
  - **Después del reinicio (21:32, GMT-3):** `dell_smm_hwmon` no cargó; sí están
    `dell_smbios`, `dcdbas` y `dell_wmi_descriptor`, que no manejan el ventilador.
    Carga de 60 s en los 4 hilos (21:32:23–21:33:26): de 42 °C en reposo a 53 °C en
    1 s y 65 °C al final, sin llegar a los ~70 °C donde antes empezaban los picos. Al
    cortar, 47 °C en 5 s. Alfred: durante esa carga el ventilador no se aceleró.
  - **Carga hasta 70 °C (21:34:53–21:36:38, GMT-3):** de 45 °C en reposo, 63 °C a los
    30 s, 67 °C al minuto, 70 °C a los 85 s (21:36:22). Se sostuvo 15 s entre 69 y
    70 °C y se cortó. Al cortar, 55 °C en 5 s y 49 °C a los 30 s. Alfred: no hubo
    picos ni durante ni después; el ventilador se oye muy silencioso todo el tiempo.
  - **Carga de 5 min (21:39:29–21:44:53, GMT-3)**, mostrada en vivo en la ventana 1 de
    tmux (script `scripts/carga-larga.sh`): 44 °C en reposo,
    70 °C a los 75 s, 72 °C a los 2 min, y de ahí se estabilizó entre 72 y 73 °C, con
    un máximo de 74 °C al final. Al cortar, 54 °C a los 15 s y 48 °C al minuto. Que la
    temperatura se estabilice sugiere que el ventilador sí acompaña algo, aunque sin el
    driver no se pueden leer las rpm.
  - **RESUELTO (2026-11-10, 21:47 GMT-3).** Alfred decidió dejarlo así. La causa del
    subir y bajar era `dell_smm_hwmon`: con el driver en la blacklist no hubo picos ni
    llegando a 70–74 °C ni después. La blacklist
    (`/etc/modprobe.d/blacklist-dell-smm.conf`) queda puesta y es la solución
    permanente. El ventilador está sano y silencioso, y la pasta está bien: con 5 min
    de carga completa la CPU se estabiliza en 72–73 °C, lejos de los 89 °C de máxima.
    Lo que se pierde: no se pueden leer las rpm ni tocar `pwm1`. La BIOS maneja el
    ventilador sola. Si los picos vuelven algún día, retomar desde acá.
  - **Causa encontrada en el código del kernel (21:55, GMT-3):** el driver ya tiene
    una excepción para este mismo bug (`i8k_blacklist_fan_type_dmi_table`: "CPU fan
    speed randomly going up and down"), y en la lista figura el Inspiron 580, pero
    compara el nombre exacto `"Inspiron 580 "`. Esta máquina reporta
    `"Inspiron 580s"`, así que no coincide y la llamada `I8K_SMM_GET_FAN_TYPE` no se
    desactiva. Según Alfred, la 580 y la 580s son el mismo equipo y solo cambia el
    tamaño del gabinete. Hay un borrador del reporte en inglés en
    `reports/bug-dell-smm-hwmon-inspiron-580s.md` (en este proyecto), para mandar por mail a
    `linux-hwmon@vger.kernel.org`. Falta que Alfred lo mande.
  - Para deshacer: `sudo rm /etc/modprobe.d/blacklist-dell-smm.conf` y
    `sudo modprobe dell_smm_hwmon`.
- Para devolverle el ventilador a la BIOS:
  `echo 2 | sudo tee /sys/class/hwmon/hwmon0/pwm1_enable`. Al reiniciar vuelve solo.
