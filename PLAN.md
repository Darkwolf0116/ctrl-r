# PLAN DE IMPLEMENTACIÓN: CTRL+R Educational PWA (v2 — implementado)

## 🎯 Objetivo
PWA offline-first para celulares reciclados/gama baja, con gamificación estilo Duolingo, la mascota Sanik (hormiga) como protagonista, dos niveles educativos (Primaria/Secundaria) con puntos independientes y conversión de puntos a décimas en exámenes finales. Proyecto del Instituto de Bachillerato en Computación (IBC), Quezaltepeque, Chiquimula.

> **v2:** el plan original (v1) fue escrito por opencode, que solo llegó a convertir el logo a base64. Esta versión corrige los errores del plan y documenta lo que quedó implementado. Ver la sección **0. Correcciones v2**.

---

## 0. CORRECCIONES v2 (respecto al plan v1)

| Problema en v1 | Corrección aplicada |
|---|---|
| Service Worker "embebido como Blob" y manifest `data:` → los navegadores no lo permiten (ni instalable ni offline) | `sw.js` y `manifest.webmanifest` reales. Se registran solo si la página se sirve por http(s); abierto como archivo, `index.html` funciona igual (sin instalación) |
| Íconos deformados: `Logo.png` es **236×140** y se estiró a 192×192 y 512×512 | `tools/generate-icons.ps1` quita el fondo, centra el logo con relleno blanco y genera ícono `maskable` dentro de la zona segura |
| `logo_base64.txt` guardado en UTF-16 (inservible) | Eliminado junto con los demás intermedios; el logo se embebe desde `icons/logo.png` |
| Conversión contradictoria ("1,000 pts = 0.1 décima (1/10 de punto)") | **1,000 pts = 1 décima = 0.1 punto · 10,000 pts = 1 punto** |
| `bankPoints` "nunca decrece" pero el canje "descuenta de bankPoints" | `ganados`, `canjeados` y `gastados` solo crecen; `disponibles = ganados − canjeados − gastados` |
| Se podían farmear décimas repitiendo preguntas fáciles | 1.ª respuesta correcta = 100 %, repetida = 25 %, con pista = 50 %; **tope diario de 600 pts al banco** por nivel (la XP no tiene tope) |
| "Anti-trampa" solo con localStorage (editable) | Estado firmado (FNV-1a + sal): si se edita a mano → aviso y canjes bloqueados. Cada canje genera un **comprobante con código verificable** por el docente. Es disuasivo: la seguridad real requiere servidor |
| Vidas: "ver ad simulado" (app para niños) | Eliminado. Con 0 vidas: esperar (1 vida / 20 min), **Repaso** (no gasta vidas, +1 ❤️) o 200 pts |
| Racha con ❤️ y vidas con ♡ | Racha = 🔥, vidas = ❤️ |
| "Background Sync" / "Sincronizando..." sin backend | Eliminado. El indicador solo informa que el progreso se guarda en el teléfono |
| Fuente Nunito en base64 (no se tenía el archivo) | Pila de fuentes del sistema (Nunito/Quicksand si existen → system-ui) |
| Animaciones de Sanik por partes con un PNG (imposible) | Sanik en **SVG inline** con partes animables; el PNG se usa en header, inicio e íconos |
| Tipos "ordenar/clasificar/patrón" con una estructura que solo admite opción múltiple | Todas son de opción múltiple (4 opciones, se barajan); `tipo` es una etiqueta y `visual` muestra emojis, muestras de color o figuras |
| Medalla Oro = 30 aciertos con solo 25 preguntas; combo ×3 a 20 aciertos en lecciones de 8 | Las medallas cuentan aciertos totales (incluye repasos) y el combo dura toda la sesión |
| `AudioContext` en el constructor (bloqueado por autoplay) y notas simultáneas | Se crea con el primer toque; notas escalonadas (arpegio) |
| Historial "inmutable" sin límite | Últimos 300 movimientos; los comprobantes de canje nunca se recortan |
| Guardado solo con debounce | También al ocultar/cerrar la página (`visibilitychange`, `pagehide`) |
| Metas irreales (FCP < 100 ms) | `index.html` ≈ 246 KB sin dependencias externas; JS/CSS compatible con Chrome 80+ / Safari 13+ |
| Idiomas "quechua, aimara" (Perú/Bolivia) | Kaqchikel y k'iche' (Guatemala) |
| Materias con nombres cortos; naranja #FF9800 sin contraste AA | Nombres y propósitos del CNB según la identidad visual; colores de materia oscurecidos a AA; paleta institucional #1B3C59 / #3A8C75 / #3E8C43 |
| Ligas con 30 bots presentados como rivales | "Colonia semanal" con hormigas ficticias, etiquetadas como personajes de práctica |
| `start_url: "/"` (falla en subcarpetas) | `start_url: "./"`; los atajos `?materia=` abren la materia en el último nivel usado |
| Faltaban secciones del documento de identidad visual | Pantalla **Sobre CTRL+R** (quiénes somos, misión, visión, mascota, donaciones, compromiso con tus datos, contacto), **asistente Sanik offline** e **Ideas y reseñas** |

---

## 1. ARCHIVOS

| Archivo | Descripción |
|---|---|
| `index.html` | App completa (HTML + CSS + JS inline, logo embebido). Funciona sola, incluso abierta como archivo |
| `sw.js` | Service Worker cache-first. **Cambiar `CACHE` al publicar una versión nueva** |
| `manifest.webmanifest` | Manifest PWA (íconos, atajos por materia) |
| `icons/` | `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`, `apple-touch-icon-180.png`, `logo.png` (sin fondo) |
| `tools/generate-icons.ps1` | Regenera los íconos desde `info/Logo.png` y vuelve a embeber el logo en `index.html` |
| `PLAN.md` | Este documento |

Para que sea instalable y funcione sin internet hay que publicarlo en un hosting **HTTPS** (por ejemplo GitHub Pages) con todos los archivos juntos. La primera visita necesita internet; después funciona offline.

---

## 2. ARQUITECTURA (`index.html`, un IIFE)

- **CONFIG**: constantes de economía (`PTS_POR_DECIMA`, `TOPE_DIARIO_BANCO`, costos, vidas, combos, desbloqueos).
- **MATERIAS / NIVELES / TIPOS**: áreas del CNB con su propósito.
- **CONTENIDO**: 200 preguntas en formato compacto, normalizadas a objetos `{ id, tipo, dificultad, pregunta, opciones, respuesta, explicacion, visual, xpBase }`.
- **ALMACENAMIENTO**: `ctrlr_primaria_v1`, `ctrlr_secundaria_v1` (firmados) y `ctrlr_global_v1` (ajustes, nombre, reseñas). `SCHEMA_VERSION` + `migrar()`.
- **MOTOR**: lecciones, puntos, banco, vidas, racha, meta diaria, medallas, colonia, canjes y comprobantes.
- **SANIK**: SVG con estados `idle`, `think`, `celebrate`, `sad`, `levelup`, `milestone` (hito de racha) y `sleep` (30 s sin actividad); gorra de graduación en Secundaria.
- **AUDIO**: Web Audio sintético + vibración.
- **VISTAS**: Inicio (selector de nivel) → Aprender (materias) → Materia (dificultad) → Juego → Resultados; Banco, Medallas, Colonia, Más (Tienda, Ajustes, Sobre CTRL+R, Ideas y reseñas); asistente Sanik (botón flotante).

---

## 3. CONTENIDO

25 preguntas por materia y nivel (12 fácil · 8 medio · 5 difícil) = **200 preguntas**, con contexto guatemalteco y explicación breve.

```javascript
// [tipo, pregunta, [opción CORRECTA primero, ...3 distractores], explicación, visual?]
['calculo', 'María compra 3 panes a Q2 cada uno. ¿Cuánto paga?', ['Q6', 'Q5', 'Q3', 'Q8'], '3 panes × Q2 = Q6.']
```
- `visual`: emojis (`'🔴🔵🔴🔵🔴 ❓'`), colores (`'color:#1E5BD8|#F9D71C'`) o figura (`'forma:triangulo'`).
- Los ids dependen de la posición (`mat_pri_f01`): **agregar preguntas nuevas al final de cada lista**.
- Desbloqueo: Medio con 8 fáciles dominadas; Difícil con 5 medias dominadas. Lección = hasta 8 preguntas, primero las no dominadas.

---

## 4. ECONOMÍA Y DÉCIMAS

| Regla | Valor |
|---|---|
| XP por acierto | Fácil 10 · Medio 15 · Difícil 25 |
| Pregunta ya acertada antes | 25 % |
| Con pista (quita 2 opciones incorrectas) | 50 % |
| Combo de aciertos seguidos | 5 → ×1.5 · 10 → ×2 · 20 → ×3 |
| Tope diario al banco | 600 pts por nivel |
| Meta diaria | 300 / 500 / 1,000 XP (configurable) · bono +50 |
| Canje | 1,000 pts = 1 décima (0.1 punto) · 10,000 pts = 1 punto |
| Tienda | Congelar racha 500 pts (máx. 2) · Recargar vidas 200 pts |

**Comprobante de canje**: `P1-261021-K7Q2-0A9ZX` = nivel (P/S) + número de décima, fecha (AAMMDD), id del teléfono, firma. El docente lo valida en *Banco → Verificar un comprobante* y lleva su propio registro para que cada código se use una sola vez.

---

## 5. GAMIFICACIÓN

- **Racha 🔥**: días seguidos con al menos una lección completada; el congelador la protege un día.
- **Vidas ❤️**: 5; cada error quita una (excepto en Repaso); +1 cada 20 minutos.
- **Medallas (27 por nivel)**: Bronce 5 / Plata 15 / Oro 30 aciertos y Diamante 50 seguidos por materia; especiales: Madrugador, Noctámbulo, Racha 7/30/100, Completista, Velocista, Sabio, Fan de Sanik, Primera lección y Primer canje.
- **Colonia semanal**: 30 hormigas (29 personajes de práctica + tú); el lunes los 10 primeros suben y los últimos 5 bajan. Ligas: Bronce, Plata, Oro, Jade, Diamante.
- **Nivel de Sanik**: umbrales de XP 0, 100, 300, 600, 1,000...

---

## 6. DISEÑO

- Paleta institucional: `#1B3C59` (títulos), `#3A8C75` y `#3E8C43` (botones), fondo blanco. Materias: Comunicación `#C2185B`, Matemáticas `#1565C0`, Ciencia `#2E7D32`, Artística `#B45309` (más oscuros en Secundaria).
- Tema claro / oscuro / automático. Botones de 56 px, foco visible, `aria-label`, respeta `prefers-reduced-motion`.
- Diseño de 320 a 520 px de ancho, sin scroll horizontal.

---

## 7. CHECKLIST DE VERIFICACIÓN (21/10/2026)

Verificado con una prueba automatizada (Playwright + Chromium, 375×812 y 320×640):

- [x] Manifest válido e íconos 192/512 cuadrados sin deformar
- [x] Service Worker activo; sin internet la app carga y el atajo `?materia=` funciona
- [x] Selector de nivel → Materias → Juego → Feedback → Resultados
- [x] Puntos por nivel aislados (Secundaria en 0 tras jugar Primaria)
- [x] XP correcta: combos, 25 % en repetidas, 50 % con pista
- [x] Tope diario de 600 pts al banco
- [x] Banco: conversión a décimas, canje (disponibles −1,000), comprobante válido y código alterado rechazado
- [x] Progreso editado a mano → aviso y canje bloqueado; reiniciar nivel lo limpia
- [x] Racha perdida / salvada por congeladores, recarga de vidas por tiempo, ascenso de liga
- [x] Sin vidas → modal → Repaso sin gastar vidas y con +1
- [x] Desbloqueo de Medio tras dominar 8 fáciles
- [x] Medallas (27) y galería
- [x] Asistente Sanik, Sobre CTRL+R y reseñas guardadas
- [x] Sanik con gorra en Secundaria; tema oscuro
- [x] Sin errores de consola por http ni al abrir como archivo (`file://`)
- [x] 200 preguntas válidas (12/8/5 por materia y nivel, 4 opciones distintas)
- [ ] Instalar en un celular real desde un hosting HTTPS (pendiente)
- [ ] Revisión del contenido por docentes y ajuste de dificultad (pendiente)

---

## 8. EXTENSIBILIDAD (TODO en el código)

```javascript
// TODO: Agregar más preguntas AL FINAL de CONTENIDO[nivel][materia][dificultad]
// TODO: Nuevas materias -> MATERIAS + color --c-<clave> en CSS + CONTENIDO
// TODO: Sincronización real con backend (Firebase/Supabase) para validar canjes en servidor
// TODO: Modo profesor: panel con códigos de clase y registro de comprobantes ya usados
// TODO: Modo multijugador local (Bluetooth/WebRTC) -> pantalla "Duelo"
// TODO: Exportar certificado PDF al completar el 100 % del nivel
// TODO: Más idiomas (kaqchikel, k'iche', inglés) -> i18n simple
// TODO: Correo de contacto (hoy "Pendiente" en Sobre CTRL+R)
```

---

## 9. PRÓXIMOS PASOS

1. ✅ Íconos y logo (corregidos)
2. ✅ `index.html`, `sw.js` y `manifest.webmanifest`
3. ✅ Pruebas en navegador (SW, offline, localStorage, navegación)
4. 🔄 Publicar en hosting HTTPS e instalar en un celular real
5. 🔄 Revisión docente del contenido y ajustes de dificultad/economía (`CONFIG`)

**Estado**: implementado y verificado en navegador; pendiente la prueba en un teléfono real.
