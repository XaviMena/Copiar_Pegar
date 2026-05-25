# Copia Pega MacOs

Mini historial local de portapapeles para macOS. Vive en la barra de menú, guarda texto e imágenes copiadas y permite restaurarlas al portapapeles.

## Ejecutar

```bash
script/build_and_run.sh
```

Ese script compila, instala en `/Applications/Copia y Pega.app` y abre esa copia instalada. No uses `swift run` para ejecutar la app de uso diario, porque macOS lo registra como otro programa en permisos de Accesibilidad.

El empaquetado usa una firma local estable llamada `Copia y Pega Local Code Signing`. Esto evita que macOS pierda el permiso de Accesibilidad después de reinstalar o reiniciar.

## Privacidad

- No usa red.
- No sincroniza con iCloud.
- Guarda el historial en `~/Library/Application Support/CopiaPegaMacOs`.
- Por defecto conserva 50 elementos durante 24 horas.
