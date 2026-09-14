# Registres crus de l'experiment de transferència

Sortida completa de `bin/console.log` de les sis execucions fetes el 14 de
setembre de 2026 sobre la màquina Windows amb GPU dedicada (NVIDIA GeForce
GTX 1660 Ti with Max-Q Design, controlador 566.14).

| Fitxer | `HEFEST_DIRECT_UPLOAD` | Estratègia efectiva |
|---|---|---|
| `staging_1.log` | sense definir | búfer intermedi |
| `staging_2.log` | sense definir | búfer intermedi |
| `staging_3.log` | sense definir | búfer intermedi |
| `direct_1.log` | `1` | escriptura directa (tipus de memòria 5) |
| `direct_2.log` | `1` | escriptura directa (tipus de memòria 5) |
| `direct_3.log` | `1` | escriptura directa (tipus de memòria 5) |

Cada execució va durar uns 8 s i es va tancar amb `Esc`. El motor escriu un
informe un cop per segon; la xifra rellevant és la línia `uploads` de l'últim
bloc de cada fitxer.

L'anàlisi i les taules són a [`../resultats-gpu-dedicada.md`](../resultats-gpu-dedicada.md).

## Notes de reproducció

- El motor s'ha d'executar **des de `bin/`**: `resource_system` fa servir la
  ruta relativa `assets` i els `.spv` són a `bin/assets/shaders`.
- **La redirecció de stdout no captura res** sobre Windows:
  `platform_console_write` fa servir `WriteConsoleA`, que falla quan stdout
  apunta a un fitxer. Aquests registres són còpies de `bin/console.log`, que el
  registrador escriu amb `fflush` a cada línia.
- Els registres corresponen al binari amb instrumentació temporal de diagnòstic
  (línies `[memtrace]`), retirada abans dels commits `0019163` i `68fdf25`. Es
  va comprovar que no distorsionava les mesures: una execució posterior amb el
  codi net dóna 5,268 ms, dins del rang de la configuració de búfer intermedi.
