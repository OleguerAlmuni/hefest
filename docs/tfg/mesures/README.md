# Registres crus de l'experiment de transferència

Sortida completa de les dotze execucions que sostenen les xifres del capítol 6
de la memòria. No s'han retallat ni editat: contenen també la sortida del
carregador de Vulkan i l'enumeració de capes, de manera que se'n pot verificar
l'entorn d'execució a més dels resultats.

| Prefix | Equip | Maquinari |
|---|---|---|
| `equipA_` | A | Intel Iris Xe Graphics (integrada), Arch Linux, Mesa 26.2.1 |
| `equipB_` | B | NVIDIA GeForce GTX 1660 Ti Max-Q (dedicada), Windows 11, controlador 566.14 |

| Sufix | `HEFEST_DIRECT_UPLOAD` | Estratègia efectiva |
|---|---|---|
| `staging_1..3` | sense definir | búfer intermedi |
| `direct_1..3` | `1` | escriptura directa |

A tots dos equips el motor va poder emprar l'escriptura directa: cadascun exposa
un tipus de memòria alhora local al dispositiu i visible des de l'amfitrió, si bé
per raons diferents que el capítol 6 analitza.

## Com llegir-los

Tres línies són rellevants per a l'experiment:

- `Upload strategy:` — quina via va emprar **realment** el motor, que no ha de
  coincidir amb la sol·licitada: si el dispositiu no exposa el tipus de memòria
  necessari, torna al búfer intermedi i ho fa constar.
- `uploads` — nombre d'operacions i temps acumulat, separats entre búfers de
  geometria i imatges. És l'última línia de cada informe i la font de la taula
  del capítol 6.
- `Frame timing over` — la finestra de mostres de temps per fase. Se n'emet un
  per segon; el rellevant és l'últim de cada execució.

## Notes de reproducció

- El motor s'ha d'executar **des de `bin/`**: el sistema de recursos fa servir
  la ruta relativa `assets` i els fitxers SPIR-V són a `bin/assets/shaders`.
- **Sobre Windows la redirecció de la sortida estàndard no captura res**, perquè
  la funció d'escriptura per consola de la capa de plataforma falla quan la
  sortida apunta a un fitxer. Els registres de l'equip B són còpies de
  `bin/console.log`, que el registrador escriu amb bolcat a cada línia.
- Els registres de l'equip B corresponen a un binari amb instrumentació de
  diagnòstic addicional, retirada abans dels commits `0019163` i `68fdf25`. Una
  execució posterior amb el codi net dona 5,268 ms per a la configuració de
  búfer intermedi, dins del rang de les tres repeticions.
- L'anàlisi completa de l'execució sobre GPU dedicada és a
  [`../resultats-gpu-dedicada.md`](../resultats-gpu-dedicada.md).
