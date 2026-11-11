#!/bin/bash
# Carga los 4 hilos hasta 5 min; corta antes si llega a 80 °C. Muestra la temperatura cada 1 s.
L="$(dirname "$0")/carga-larga.log"
MAX_S=300; TOPE=80
t(){ max=0; for f in /sys/class/hwmon/hwmon0/temp*_input; do v=$(($(cat $f)/1000)); [ $v -gt $max ] && max=$v; done; echo $max; }
hora(){ TZ=America/Argentina/Buenos_Aires date +%T; }
barra(){ n=$(( $1 - 40 )); [ $n -lt 0 ] && n=0; printf '%*s' $n '' | tr ' ' '#'; }
pids=""
fin(){ kill $pids 2>/dev/null; }
trap fin EXIT INT TERM
clear
echo "Carga al 100 % en 4 hilos — hasta ${MAX_S}s o ${TOPE} °C. Ctrl+C corta." | tee $L
echo "inicio $(hora) reposo $(t) °C" | tee -a $L
for i in 1 2 3 4; do (yes > /dev/null) & pids="$pids $!"; done
for s in $(seq 1 $MAX_S); do
  sleep 1; v=$(t)
  printf '%s  %3ds  %2d °C  %s\n' "$(hora)" $s $v "$(barra $v)" | tee -a $L
  [ $v -ge $TOPE ] && { echo "TOPE de ${TOPE} °C alcanzado" | tee -a $L; break; }
done
fin; echo "corte $(hora)" | tee -a $L
for s in $(seq 1 60); do
  sleep 1; v=$(t)
  printf '%s  +%2ds  %2d °C  %s  (enfriando)\n' "$(hora)" $s $v "$(barra $v)" | tee -a $L
done
echo "FIN $(hora)" | tee -a $L
