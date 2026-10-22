# CTRL+R · Aprende con Sanik 🐜

App educativa gamificada (PWA) para celulares reciclados: Primaria y Secundaria, cuatro áreas del CNB de Guatemala y funciona sin internet. Proyecto del Instituto de Bachillerato en Computación (IBC), Quezaltepeque, Chiquimula.

## Instalar en un celular

1. Abre la página publicada en Chrome (Android) o Safari (iPhone) **con internet** la primera vez.
2. Chrome: menú ⋮ → **Instalar app** (o *Agregar a pantalla principal*). Safari: botón Compartir → **Agregar a inicio**.
3. Desde entonces funciona sin internet. El progreso se guarda solo en ese teléfono.

## Publicar una versión nueva

1. Edita `index.html` (las preguntas están en `CONTENIDO`; agrégalas al final de cada lista).
2. Cambia `CACHE` en `sw.js` (por ejemplo `ctrlr-v2`) para que los teléfonos descarguen la actualización.
3. Haz commit y push a `main`: GitHub Pages se actualiza solo.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app completa (HTML, CSS, JS y logo embebido) |
| `sw.js` | Service Worker: guarda la app para usarla sin internet |
| `manifest.webmanifest` | Datos para instalarla como app |
| `icons/` | Íconos de la app |
| `tools/generate-icons.ps1` | Regenera los íconos desde `info/Logo.png` (carpeta local, no publicada) |
| `PLAN.md` | Plan, reglas del juego y checklist de verificación |
