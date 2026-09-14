# Resultats sobre GPU dedicada — NVIDIA GeForce GTX 1660 Ti (Max-Q)

Mesures preses el 14 de setembre de 2026 sobre la màquina Windows amb GPU
dedicada, per contrastar-les amb les de la màquina Linux amb GPU integrada
(Intel Iris Xe). Aquest fitxer és la font de dades per al capítol de resultats;
`memoria.typ` no s'ha modificat.

Binari mesurat: commit `b5eb866` més les dues correccions `0019163` i `68fdf25`
descrites a la secció 1. Sense cap instrumentació addicional.

---

## 1. Compilació i correccions necessàries

El codi **compila net a Windows sense cap modificació**. Cap dels riscos
previstos es va materialitzar: ni el camp `normal` nou de `vertex_3d` i el pas
de 2 a 3 atributs de *pipeline*, ni l'ús de `getenv` (Clang no exigeix
`getenv_s`, i `build.bat` ja defineix `_CRT_SECURE_NO_WARNINGS`), ni els
subsistemes nous `metrics`, `resource_system`, `geometry_system` i
`material_system`.

Compilar i funcionar, però, no eren el mateix: el motor **no arrencava**.
Fallava sempre amb `0xC0000005` (violació d'accés), mòdul `unknown`,
desplaçament `0x0` — és a dir, un salt a l'adreça zero. Van caldre dues
correccions.

### 1.1. Punter penjant a la creació del *swapchain* (commit `0019163`)

A `vulkan_swapchain.c`, l'array d'índexs de família de cua estava declarat dins
del bloc `if` que selecciona compartició concurrent, però
`swapchain_create_info.pQueueFamilyIndices` hi continua apuntant i només es
llegeix més avall, a `vkCreateSwapchainKHR`. En aquell punt l'array ja és mort.

```c
// abans
if (graphics_queue_index != present_queue_index) {
    u32 queueFamilyIndices[] = { graphics, present };  // vida limitada al bloc
    swapchain_create_info.pQueueFamilyIndices = queueFamilyIndices;
}                                                      // l'array mor aquí
...
VK_CHECK(vkCreateSwapchainKHR(..., &swapchain_create_info, ...));  // llegeix memòria morta
```

**Aquest error només es manifesta en dispositius on les famílies de gràfics i
de presentació són diferents.** Sobre la Iris Xe hi ha una sola família per a
tot, s'agafa la branca `VK_SHARING_MODE_EXCLUSIVE` i el codi defectuós no
s'executa mai. Sobre la GTX 1660 Ti les famílies són 0 (gràfics) i 2
(presentació), s'agafa la branca `VK_SHARING_MODE_CONCURRENT` i el punter queda
penjant.

És comportament indefinit present al codi des de sempre i **també afecta
Linux**; simplement el maquinari integrat no l'exercita.

> **Reserva sobre l'atribució.** La petada va deixar de reproduir-se en afegir
> traces de diagnòstic, *abans* de corregir aquesta línia, perquè desplaçar la
> pila canvia el contingut de la memòria morta que es llegia. No es pot
> demostrar que aquest error fos la causa de la petada concreta. El que sí que
> és cert és que era l'únic comportament indefinit del camí d'inicialització i
> que la seva condició d'activació coincideix exactament amb la diferència
> entre les dues màquines.

### 1.2. Estat del subsistema de registre (commit `68fdf25`)

A `application_create`, tots els subsistemes passen `app_state->x_system_state`
directament; la crida del registre passava `&app_state->logging_system_state`,
és a dir l'adreça del punter. Com que `initialize_logging` fa `state_ptr =
state`, el punter acabava apuntant *dins* d'`application_state` en comptes del
bloc reservat per l'assignador lineal, i els 16 bytes de `file_handle`
trepitjaven el camp `logging_system_state` i el byte baix de
`metrics_system_memory_requirement`.

El dany passava desapercebut perquè `metrics_initialize` reescriu aquest segon
camp immediatament després. És un error latent, **també present a Linux**, que
es trencaria a la mínima modificació de l'estructura.

### 1.3. Qüestions d'execució que no són errors de codi

Dues coses del protocol experimental original no funcionen sobre Windows:

- **El motor s'ha d'executar des de `bin/`.** `resource_system` fa servir la
  ruta relativa `assets`, i `post-build.bat` compila els `.spv` a
  `bin/assets/shaders`. Executat des de l'arrel del repositori troba
  l'`assets/` del projecte, que només conté els `.glsl` font, i falla amb
  `Error opening file: 'assets//shaders/Builtin.MaterialShader.vert.spv'`.
- **La redirecció `> fitxer.log 2>&1` no captura res.**
  `platform_console_write` fa servir `WriteConsoleA`, que només escriu sobre un
  maneigador de consola real i falla silenciosament quan stdout apunta a un
  fitxer. El canal fiable és `bin/console.log`, que el registrador escriu via
  `filesystem_write` amb `fflush` a cada línia.

---

## 2. Entorn

| Element | Valor |
|---|---|
| Processador | AMD Ryzen 7 4800HS with Radeon Graphics |
| Nuclis / fils | 8 nuclis, 16 fils, 2,9 GHz |
| GPU dedicada | NVIDIA GeForce GTX 1660 Ti with Max-Q Design |
| Versió del controlador | **566.14** |
| GPU integrada | AMD Radeon(TM) Graphics (driver 20.10.20.14) |
| Sistema operatiu | Microsoft Windows 11 Pro, versió 10.0.26200, compilació 26200 |
| Arquitectura | 64 bits |
| Memòria RAM | 16 556 593 152 B (15,42 GiB) |
| Clang | 12.0.0, target `x86_64-pc-windows-msvc` |
| Make | GNU Make 3.81 |
| Vulkan SDK | **LunarG 1.4.313.1** |
| `glslc` | shaderc v2023.8 / v2025.2; glslang 11.1.0; SPIR-V 1.0 |
| API Vulkan del dispositiu | 1.3.289 |

Notes:

- La GPU és una **1660 Ti**, no una 1650 Ti.
- El motor informa `GPU Driver Version: 566.56.0`, però la xifra correcta és
  **566.14**, la que dóna `vulkaninfo`. NVIDIA empaqueta el número de versió
  del controlador amb un repartiment de bits propi que no coincideix amb
  `VK_VERSION_MAJOR/MINOR/PATCH`, i la descodificació genèrica del motor el
  malinterpreta. **Per a la memòria cal fer servir 566.14.**
- La màquina exposa **dos** dispositius Vulkan. `select_physical_device` fa una
  primera passada exigint `discrete_gpu` i selecciona la NVIDIA, cosa
  verificada al registre (`Selected device: 'NVIDIA GeForce GTX 1660 Ti with
  Max-Q Design'`, `GPU Type is Discrete`).
- Les famílies de cua són diferenciades: gràfics 0, presentació 2, còmput 2,
  transferència 4. Sobre la Iris Xe n'hi ha una de sola que ho fa tot. Aquesta
  diferència exercita camins (`VK_SHARING_MODE_CONCURRENT`, cua de
  transferència separada) que el maquinari integrat no toca mai.

---

## 3. `VkPhysicalDeviceMemoryProperties`

### Munts (3)

| Munt | Mida | Banderes |
|---|---|---|
| 0 | 6 255 804 416 B (5,83 GiB) | `MEMORY_HEAP_DEVICE_LOCAL_BIT` |
| 1 | 8 278 294 528 B (7,71 GiB) | cap |
| 2 | 224 395 264 B (214,00 MiB) | `MEMORY_HEAP_DEVICE_LOCAL_BIT` |

### Tipus (6)

| Tipus | Munt | `propertyFlags` | Desplegades |
|---|---|---|---|
| 0 | 1 | `0x0000` | cap |
| 1 | 0 | `0x0001` | `DEVICE_LOCAL` |
| 2 | 0 | `0x0001` | `DEVICE_LOCAL` |
| 3 | 1 | `0x0006` | `HOST_VISIBLE`, `HOST_COHERENT` |
| 4 | 1 | `0x000e` | `HOST_VISIBLE`, `HOST_COHERENT`, `HOST_CACHED` |
| **5** | **2** | **`0x0007`** | **`DEVICE_LOCAL`, `HOST_VISIBLE`, `HOST_COHERENT`** |

### Resposta a la pregunta de l'experiment

**Sí. Existeix un tipus de memòria alhora `DEVICE_LOCAL` i `HOST_VISIBLE`: el
tipus 5**, sobre el munt 2, de 214,00 MiB.

Això contradiu la predicció de partida. És la finestra BAR accessible des de la
CPU que alguns controladors exposen, contemplada com a escenari improbable. A
diferència de la Iris Xe, on n'hi ha dos i abasten tota la memòria del sistema,
aquí n'hi ha **un de sol i limitat a 214 MiB**.

Els búfers de geometria del motor sumen **36 MiB**: 32 MiB de vèrtexs
(`sizeof(vertex_3d) * 1024 * 1024`, amb `vertex_3d` de 32 bytes un cop afegit
el camp `normal`) i 4 MiB d'índexs (`sizeof(u32) * 1024 * 1024`). Hi caben amb
marge, però **el sostre és real**: si el vèrtex creix a 48 bytes (per exemple,
afegint-hi tangents), el búfer de vèrtexs sol passa a 48 MiB. Aquesta via té un
límit dur de capacitat que la del búfer intermedi no té.

---

## 4. Experiment de transferència

Tres repeticions per configuració, ~8 s cadascuna, tancades amb `Esc`. S'extreu
l'últim informe de cada execució.

| Configuració | Rep. | Estratègia efectiva registrada | Búfers (8) | Imatges (3) |
|---|---|---|---|---|
| A — búfer intermedi | 1 | `intermediate (staging) buffer` | **5,524 ms** | 5,053 ms |
| A — búfer intermedi | 2 | `intermediate (staging) buffer` | **6,404 ms** | 5,502 ms |
| A — búfer intermedi | 3 | `intermediate (staging) buffer` | **5,554 ms** | 5,113 ms |
| B — escriptura directa | 1 | `direct writes into device-local, host-visible memory` | **0,021 ms** | 4,827 ms |
| B — escriptura directa | 2 | `direct writes into device-local, host-visible memory` | **0,022 ms** | 5,486 ms |
| B — escriptura directa | 3 | `direct writes into device-local, host-visible memory` | **0,019 ms** | 5,599 ms |

`Device timing enabled. One timestamp tick is 1.0000 ns.` a les sis execucions.

### Interpretació

**El desenllaç previst no s'ha produït.** No hi ha hagut cap retorn automàtic
al búfer intermedi: la sonda troba el tipus 5 i l'escriptura directa s'activa
efectivament. La diferència entre configuracions és d'unes **270 vegades**, i
la separació entre A i B és tres ordres de magnitud superior a la dispersió
dins de cada configuració, de manera que és senyal i no soroll.

Es va verificar amb instrumentació temporal que els búfers de geometria cauen
**al tipus 5 i no a un altre**. El filtre de `memoryTypeBits` del búfer és
`0x3b`, que inclou el bit 5, i el tipus 5 és l'únic candidat que satisfà
`0x0007`:

```
size=33554432 filter=0x0000003b requested=0x0007 -> type 5 (heap 2, 214.00 MiB) flags=0x0007
size=4194304  filter=0x0000003b requested=0x0007 -> type 5 (heap 2, 214.00 MiB) flags=0x0007
```

A la configuració A, amb `requested=0x0001`, els candidats són els tipus 1 i 5
i `find_memory_index` retorna el 1 — el correcte per a aquella via.

### Reserves sobre la xifra de 0,021 ms

Dues, importants per no presentar el resultat de manera enganyosa.

1. **Les dues branques no mesuren el mateix treball.** La via del búfer
   intermedi inclou reservar el búfer, copiar-hi les dades, enviar una ordre de
   còpia a la cua i esperar-ne la finalització. La via directa és un `memcpy` a
   memòria mapada i res més. La comparació és vàlida com a comparació de *cost
   d'estratègia* —que és el que el motor paga—, però no com a mesura d'amplada
   de banda de transferència.
2. **Les escriptures a memòria BAR mapada són escriptures publicades sobre
   PCIe**, que la CPU no espera. Els 0,021 ms són el cost del costat de
   l'amfitrió, **no el temps que les dades triguen a arribar realment a la
   GPU**.

La columna d'imatges no varia entre configuracions perquè
`vulkan_renderer_create_texture` fa servir sempre un búfer intermedi,
independentment de `HEFEST_DIRECT_UPLOAD`. Serveix de control: confirma que la
diferència observada als búfers prové de l'estratègia i no d'una deriva entre
execucions.

### Verificació addicional

Una execució posterior amb el codi ja net d'instrumentació, sense
`HEFEST_DIRECT_UPLOAD`, dóna `buffers: 8 in 5.268 ms`, dins del rang de la
configuració A. **La instrumentació no distorsionava les mesures.**

---

## 5. Errors de validació

**Cap error de validació.** Un únic avís, idèntic a les sis execucions:

```
[WARN]: vkCreateGraphicsPipelines(): pCreateInfos[0] (SPIR-V Interface)
VK_SHADER_STAGE_VERTEX_BIT declared to output location 0 Component 0
but is not an Input declared by VK_SHADER_STAGE_FRAGMENT_BIT.
```

L'ombreig de vèrtexs exporta una variable que el de fragments no consumeix. No
té relació amb el maquinari ni amb la transferència i apareixeria igualment
sobre Linux amb les capes de validació actives.

---

## 6. Captures

| Fitxer | Contingut |
|---|---|
| `docs/tfg/figures/cub_texturat_illuminat.png` | Cub amb tres cares visibles i degradat d'il·luminació clar entre elles |
| `docs/tfg/figures/detall_reflex_especular.png` | Primer pla de la superfície |
| `docs/tfg/figures/escena_amb_interficie.png` | Enquadrament ampli amb l'element d'interfície |

Dues reserves:

- **L'element d'interfície es dibuixa incondicionalment** (`application.c`,
  `ui_geometry_count = 1`); no hi ha cap commutador. Apareix a totes tres
  captures, i la tercera només n'és un enquadrament diferent, no un estat
  diferent del motor. La seva projecció ortogràfica és fixa a 1280×720
  independentment de la mida de la finestra, de manera que n'ocupa una fracció
  constant sigui quina sigui la resolució. Les captures es van refer després
  del commit `1dcde10`, que redueix el quad de 512 a 128 unitats i el desplaça
  a (24, 24); amb la mida anterior tapava el 40 % de l'amplada i el 71 % de
  l'alçada i obligava a desplaçar el cub fora del centre.
- **La captura del reflex especular és la més fluixa de les tres.** Amb la
  textura de pedra emprada, el terme especular no produeix cap reflex nítidament
  localitzat; el que es veu és la variació d'il·luminació entre cares més que
  no pas un reflex identificable. Per il·lustrar l'especular convincentment
  caldria una superfície llisa.

---

## 7. Qüestió oberta, no resolta

El càlcul del nombre d'imatges del *swapchain* (`vulkan_swapchain.c`) anul·la
sempre l'increment que pretén aplicar:

```c
u32 image_count = capabilities.minImageCount + 1;
swapchain->max_frames_in_flight = image_count - 1;   // == minImageCount
if (image_count > swapchain->max_frames_in_flight) { // sempre cert
    image_count = swapchain->max_frames_in_flight;   // torna a minImageCount
}
```

`image_count` acaba valent exactament `minImageCount`, i `max_frames_in_flight`
queda **igual** a `image_count` en comptes de ser-ne un menys, que és el que el
patró de sincronització per fotograma sembla pressuposar.

Sobre la Iris Xe, amb `minImageCount = 3`, en resulta triple búfer, que sembla
correcte per coincidència. Sobre la GTX 1660 Ti, amb `minImageCount = 2`
(`maxImageCount = 8`), en resulta doble búfer.

**No s'ha modificat**, perquè canviar-ho alteraria el nombre de fotogrames en
vol i, per tant, les mesures d'aquest informe. No ha produït cap error de
validació. Convé revisar-ho abans de donar les xifres per definitives.
