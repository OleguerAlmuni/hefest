// =============================================================================
//  Memòria del TFG — Hefest
//  Esquelet estructurat segons plantilla_memoria_tfm.docx i la guia d'avaluació
//
//  NOTES DE FORMAT (imposades per la plantilla):
//   · Registre impersonal. Primera persona del plural només per emfatitzar
//     implicació alta en una tasca concreta.
//   · Paraules en llengua estrangera SEMPRE en cursiva: #f[shader], #f[swapchain]...
//   · Peus de figura i equació A SOTA; títols de taula A SOBRE.
//   · Tota figura/taula/equació necessita títol i referència creuada des del text.
//   · Referències numerades estil IEEE: [1], [2]...
//
//  PRESSUPOST DE PÀGINES (objectiu ~68 p. de cos, dins del rang 50-70):
//   1. Introducció ................  6
//   2. Estat de l'art ............. 10
//   3. Metodologia i planificació .  6
//   4. Decisions de disseny ....... 13   <- on es defensa el criteri propi
//   5. Disseny i implementació .... 19   <- l'abast del motor ÉS l'aportació
//   6. Resultats i discussió ......  9
//   7. Conclusions ................  5
// =============================================================================

#set document(title: "Hefest: motor de jocs en C amb Vulkan", author: "Oleguer Almuni")

#set page(paper: "a4", margin: (x: 3cm, y: 2.8cm), numbering: "1")
#set text(font: ("Libertinus Serif", "DejaVu Serif"), size: 11pt, lang: "ca")
#set par(justify: true, leading: 0.65em, first-line-indent: 1.2em)
#set heading(numbering: "1.1")

// Cursiva per a estrangerismes — obligatori segons plantilla.
#let f(x) = emph(x)

// Cursiva per a títols d'obra. Es distingeix de #f perquè el motiu és la
// convenció bibliogràfica, no el fet que la paraula sigui estrangera.
#let obra(x) = emph(x)

// Peus de figura a sota, títols de taula a sobre.
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: image): set figure.caption(position: bottom)

#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  block(above: 0em, below: 1.2em, text(size: 17pt, weight: "bold", it))
}

// Marca visual per a text pendent d'escriure. Esborrar abans d'entregar.
#let todo(x) = text(fill: rgb("#b03030"))[#emph[[#x]]]

// =============================================================================
#set page(numbering: none)

#align(center)[
  #v(3cm)
  #text(size: 15pt)[TREBALL DE FINAL DE GRAU]
  #v(1cm)
  #text(size: 24pt, weight: "bold")[
    Hefest: disseny i avaluació d'un motor\ de jocs en C amb Vulkan
  ]
  #v(0.6cm)
  #todo[Títol acordat amb el director.]
  #v(2cm)
  Oleguer Almuni\
  Grau en Enginyeria Multimèdia
  #v(1cm)
  #datetime.today().display("[day]/[month]/[year]")
]

#pagebreak()

// -----------------------------------------------------------------------------
#heading(numbering: none, outlined: false)[Resum]

#todo[Màxim una pàgina. Ha de contenir, en aquest ordre (ho exigeix la
plantilla):
+ Plantejament del problema o de la necessitat a cobrir.
+ Objectiu del treball.
+ Resultats obtinguts que responen a aquest problema.
+ Conclusions obtingudes.

Escriure'l l'últim, quan els resultats ja existeixin. És el primer que llegeix
el tribunal i sovint l'únic que llegeixen sencer abans de la defensa.]

#pagebreak()

#heading(numbering: none, outlined: false)[Agraïments]
#todo[Opcional segons la plantilla.]

#pagebreak()

#outline(depth: 3, indent: 1.2em)
#pagebreak()
#outline(title: [Índex de figures], target: figure.where(kind: image))
#outline(title: [Índex de taules], target: figure.where(kind: table))

#pagebreak()

// -----------------------------------------------------------------------------
#heading(numbering: none)[Acrònims]

#todo[Capítol obligatori. Ordre alfabètic. Els acrònims que provenen de
paraules en una altra llengua van en cursiva. Un cop desplegats aquí, ja no es
tornen a desplegar en tot el document.]

/ API: #f[Application Programming Interface]
/ DOD: #f[Data-Oriented Design]
/ FPS: #f[Frames Per Second]
/ GPU: #f[Graphics Processing Unit]
/ SPIR-V: #f[Standard Portable Intermediate Representation — Vulkan]
/ TFG: Treball de Final de Grau
/ UBO: #f[Uniform Buffer Object]
/ UMA: #f[Unified Memory Architecture]
/ WSI: #f[Window System Integration]

#set page(numbering: "1")
#counter(page).update(1)

// =============================================================================
= Introducció
// Objectiu: ~6 pàgines.
// La plantilla exigeix: antecedents/context, propòsit, resultats,
// organització del document.

== Context i motivació

#todo[Per què un motor de jocs propi, i per què ara. Enllaçar amb la formació
del grau: quins conceptes s'hi han tocat i a quin nivell. Aquí es justifica que
el projecte és una *aprofundiment* en un tema del grau, que és literalment el
que demana RA1.]

== Objectius

L'objectiu general d'aquest treball és dissenyar, implementar i avaluar un motor
de jocs escrit en C amb un renderitzador basat en Vulkan, documentant-ne les
decisions de disseny contra les fonts primàries que les fonamenten.

Aquest objectiu general es concreta en els objectius específics següents, cadascun
dels quals té una resposta explícita al capítol de resultats:

+ Implementar una capa d'abstracció de plataforma que permeti executar el motor
  sobre Windows i Linux sense modificacions al codi dels subsistemes superiors.
+ Implementar un renderitzador sobre Vulkan capaç de carregar geometria,
  textures i materials des de disc, il·luminar-los i dibuixar-los amb una
  càmera controlable.
+ Dissenyar un model de gestió de memòria explícit, en què la ubicació i el
  cicle de vida de l'estat de cada subsistema siguin decisions del motor i no del
  sistema d'assignació subjacent.
+ Validar el funcionament del motor sobre arquitectures de memòria unificada i
  de memòria dedicada, i contrastar-ne el comportament.
+ Documentar cada decisió estructural del motor amb la font primària que la
  fonamenta, de manera que en sigui possible la justificació independent.
+ Dotar el motor d'una capa d'instrumentació pròpia que permeti mesurar-ne el
  comportament sense recórrer a eines externes.
+ Avaluar empíricament un conjunt de decisions del renderitzador i quantificar
  l'impacte de cadascuna.

#todo[Revisar aquesta llista quan el capítol 5 estigui tancat. Cada objectiu ha
de tenir una secció al capítol 6 que hi respongui de manera comprovable; si
algun no s'ha assolit, és preferible reformular-lo aquí que deixar-lo sense
resposta. El rúbric puntua directament que els objectius estiguin ben delimitats.]

== Abast

El treball comprèn el desenvolupament de les capes fonamentals d'un motor de
jocs i d'un renderitzador funcional, tal com s'ha delimitat a la
@tab:capes: capa de plataforma, sistemes bàsics, gestió de recursos,
renderitzador i tractament de dispositius d'entrada. Inclou igualment la
documentació tècnica del disseny i l'avaluació empírica del comportament del
renderitzador.

Queden explícitament fora de l'abast els subsistemes següents, que un motor
comercial inclouria però que no són requisit per als objectius plantejats:

/ Simulació física i detecció de col·lisions: Constitueixen per si soles un
  domini d'una extensió comparable a la del renderitzador.

/ Àudio, animació i xarxa: Són subsistemes funcionals que es recolzen sobre les
  capes fonamentals però que no en condicionen el disseny.

/ Sistema de tasques concurrents: El motor és d'un sol fil d'execució. Es tracta
  de la limitació més rellevant del treball i se'n discuteixen les implicacions
  al capítol 7.

/ Eines d'edició i canonada d'actius: No hi ha editor de nivells ni procés
  automatitzat de conversió d'actius més enllà de la compilació dels
  #f[shaders].

/ Lògica de joc: L'aplicació que acompanya el motor té l'única finalitat de
  demostrar-ne i exercitar-ne les capacitats; no constitueix un joc.

Aquesta delimitació respon al criteri exposat a la secció sobre motors
existents: l'objectiu del treball és la comprensió de les capes que qualsevol
motor necessita abans de poder dibuixar res, no l'assoliment de la paritat
funcional amb un producte comercial.

== Organització del document

#todo[Un paràgraf per capítol. Ho exigeix la plantilla.]

// =============================================================================
= Estat de l'art i marc tecnològic
// Objectiu: ~10 pàgines.

== Arquitectura d'un motor de jocs

Un motor de jocs no és un programa monolític, sinó un conjunt de subsistemes
organitzats en capes, on les capes superiors depenen de les inferiors però no a
la inversa @gregory2018. Quan una capa inferior depèn d'una de superior es
produeix una dependència circular, situació indesitjable en qualsevol sistema de
programari perquè genera acoblament entre subsistemes, en dificulta la
verificació i n'impedeix la reutilització.

Aquest principi no és una consideració merament teòrica. En un motor com el que
es descriu en aquest treball, determina l'ordre en què els subsistemes s'han
d'inicialitzar i, per tant, condiciona directament el disseny de la seqüència
d'arrencada que es tracta al capítol 4.

=== Les capes d'un motor 3D típic

Un motor 3D complet es pot descompondre en setze capes @gregory2018, que al seu
torn s'agrupen en quatre blocs segons la seva naturalesa.

El primer bloc no forma part del motor, sinó del seu fonament: el maquinari
objectiu, els controladors de dispositiu, el sistema operatiu i els SDK de
tercers i programari intermediari. Determinen les possibilitats i els límits de
tot el que hi ha per sobre, però no els escriu qui desenvolupa el motor.

El segon bloc és el fonament del motor pròpiament dit. La capa d'independència
de plataforma encapsula les diferències entre sistemes operatius i biblioteques
natives, de manera que la resta del motor pugui ignorar-les. Els sistemes
bàsics apleguen les utilitats transversals que tota aplicació gran necessita:
assercions, gestió de memòria, biblioteca matemàtica, estructures de dades i
registre d'esdeveniments. El gestor de recursos ofereix una interfície
unificada per accedir als actius del joc, encara que cada motor el resol de
manera diferent, des d'esquemes centralitzats fins a solucions #f[ad hoc] on el
programador accedeix directament als fitxers @gregory2018.

El tercer bloc conté els subsistemes funcionals: el renderitzador, les eines de
perfilatge i depuració, la detecció de col·lisions i la física, l'animació, els
dispositius d'interfície humana, l'àudio i la xarxa i el multijugador en línia.
Són els que donen al motor les seves capacitats visibles, i cadascun és, en si
mateix, un sistema complex.

El quart bloc és el més proper al joc concret: els sistemes fonamentals de joc i
els subsistemes específics del joc. És on la frontera entre motor i joc es
difumina, i on cada projecte pren decisions pròpies.

#figure(
  block(width: 82%)[
    #let ext(t) = rect(width: 100%, inset: 5pt, radius: 2pt,
      fill: rgb("#eeeeee"), stroke: 0.5pt + rgb("#bbb"))[#align(center)[#text(size: 9pt, t)]]
    #let si(t) = rect(width: 100%, inset: 5pt, radius: 2pt,
      fill: rgb("#dbe7f3"), stroke: 0.5pt + rgb("#7d9dc0"))[#align(center)[#text(size: 9pt, weight: "bold", t)]]
    #let no(t) = rect(width: 100%, inset: 5pt, radius: 2pt,
      fill: white, stroke: (paint: rgb("#bbb"), thickness: 0.5pt, dash: "dashed"))[#align(center)[#text(size: 9pt, fill: rgb("#888"), t)]]
    #stack(spacing: 3pt,
      no("Subsistemes específics del joc  ·  Sistemes fonamentals de joc"),
      grid(columns: (1fr, 1fr, 1fr, 1fr), column-gutter: 3pt,
        no("Física"), no("Animació"), no("Àudio"), no("Xarxa")),
      grid(columns: (2fr, 1fr), column-gutter: 3pt,
        si("Renderitzador"), si("Entrada")),
      si("Gestor de recursos"),
      si("Sistemes bàsics"),
      si("Capa d'independència de plataforma"),
      ext("SDK de tercers i programari intermediari"),
      ext("Sistema operatiu"),
      ext("Controladors de dispositiu"),
      ext("Maquinari objectiu"),
    )
    #v(4pt)
    #text(size: 8pt)[
      #box(width: 8pt, height: 8pt, fill: rgb("#dbe7f3"), stroke: 0.5pt + rgb("#7d9dc0")) implementat a Hefest #h(10pt)
      #box(width: 8pt, height: 8pt, fill: white, stroke: (paint: rgb("#bbb"), thickness: 0.5pt, dash: "dashed")) fora d'abast #h(10pt)
      #box(width: 8pt, height: 8pt, fill: rgb("#eeeeee"), stroke: 0.5pt + rgb("#bbb")) extern al motor
    ]
  ],
  caption: [Model en capes d'un motor de jocs, adaptat de @gregory2018, amb
    indicació de les capes cobertes per Hefest.],
) <fig:capes>

=== Correspondència amb el motor desenvolupat

La @fig:capes situa el treball dins d'aquest model. Hefest implementa les tres
capes fonamentals —independència de plataforma, sistemes bàsics i gestor de
recursos— i dues de les funcionals: el renderitzador i els dispositius
d'interfície humana. La resta queda explícitament fora de l'abast, tal com
s'estableix a la secció corresponent del capítol 1.

Aquesta delimitació no és arbitrària. Les capes implementades són precisament
les que qualsevol motor necessita abans de poder mostrar res per pantalla, i les
que constitueixen els sistemes de suport del motor @gregory2018. Les capes
omeses —física, animació, àudio, xarxa— són
subsistemes funcionals que es recolzen sobre les anteriors però que no en són
requisit previ. Un motor sense àudio continua sent un motor; un motor sense
gestió de memòria ni capa de plataforma, no.

#figure(
  table(
    columns: (auto, auto, auto),
    inset: 6pt,
    align: (left, left, left),
    stroke: 0.4pt + rgb("#ccc"),
    table.header([*Capa*], [*Estat a Hefest*], [*On es tracta*]),
    [Independència de plataforma], [Implementada (Win32, XCB/X11)], [Cap. 4 i 5],
    [Sistemes bàsics], [Implementats], [Cap. 5],
    [Gestor de recursos], [Parcial: textures i materials], [Cap. 4 i 5],
    [Renderitzador], [Implementat sobre Vulkan], [Cap. 4, 5 i 6],
    [Perfilatge i depuració], [Parcial: instrumentació pròpia], [Cap. 5 i 6],
    [Dispositius d'interfície humana], [Implementada: teclat i ratolí], [Cap. 5],
    [Col·lisions i física], [No implementada], [Fora d'abast],
    [Animació], [No implementada], [Fora d'abast],
    [Àudio], [No implementada], [Fora d'abast],
    [Xarxa i multijugador], [No implementada], [Fora d'abast],
    [Sistemes fonamentals de joc], [No implementats], [Fora d'abast],
    [Subsistemes específics del joc], [Mínims: aplicació de proves], [Cap. 5],
  ),
  caption: [Correspondència entre les capes del model @gregory2018 i l'estat del
    motor desenvolupat.],
) <tab:capes>

Convé remarcar una asimetria que la @tab:capes no mostra: el fet que una capa
estigui implementada no vol dir que ho estigui de manera completa. El gestor de
recursos, per exemple, existeix en forma de dos sistemes especialitzats —textures
i materials— sense la capa genèrica d'accés unificat als actius que el model
preveu @gregory2018. Aquesta mena de
limitacions es documenten al lloc corresponent de cada subsistema i es recullen
de manera conjunta a les conclusions.

Cal precisar el que la taula recull com a perfilatge i depuració: el motor
disposa de comptadors d'ocupació de memòria per etiqueta i d'una capa
d'instrumentació temporal que mesura el cost de cada fase del #f[frame]. No hi
ha, en canvi, cap eina de depuració visual ni mesura de temps de dispositiu, de
manera que la cobertura d'aquesta capa és parcial. El capítol 6 en detalla
l'abast i les limitacions.

== De OpenGL a Vulkan: per què existeix Vulkan

Aquesta secció no és un excurs històric. La forma d'un motor de jocs modern està
determinada en bona part per la naturalesa de l'API gràfica sobre la qual es
construeix, i entendre per què Vulkan és com és equival a entendre per què el
motor descrit en aquest treball ha de contenir un assignador de memòria, un
model explícit de ritme de #f[frames] i un sistema de recursos propi.

=== El model clàssic i el seu cost

Durant més de dues dècades, la interacció entre aplicació i maquinari gràfic va
seguir un model en què el controlador feia gran part de la feina difícil: la
gestió dels riscos d'accés concurrent a la memòria, la sincronització entre
processador i GPU, i l'assignació de memòria de vídeo @everitt2014. Aquest
repartiment de responsabilitats tenia virtuts considerables. El model era
estable —codi escrit vint anys enrere continuava funcionant—, era senzill
d'utilitzar, i va ser suficient per a una gamma molt àmplia d'aplicacions
@everitt2014.

El problema és que aquesta comoditat té un preu mesurable. El sobrecost del
controlador es tradueix en cicles de processador, ocupació de la memòria cau,
consum energètic i, indirectament, rendiment de la GPU @everitt2014. Per a
aplicacions poc exigents el preu és irrellevant; per a jocs amb escenes complexes
deixa de ser-ho. Els límits identificats del model clàssic són concrets: no
escala amb la complexitat de l'escena, el seu model de fils d'execució és
inadequat per a processadors multinucli, i l'abstracció del maquinari que
proposa ja no es correspon amb l'arquitectura de les GPU modernes
@everitt2014.

El diagnòstic que el mateix consorci Khronos en fa uns anys més tard és més
detallat i val la pena enumerar-lo, perquè cada punt té una conseqüència directa
sobre el disseny d'un motor @olson2016. El model de programació no es
correspon amb el maquinari de la GPU —especialment en dispositius mòbils— i és
el controlador qui n'amaga el desajust. El cost en processador prové sobretot de
la validació d'estat i del seguiment de dependències que el controlador ha de
fer. Els controladors resultants són complexos i difícils de predir, amb errors
i camins ràpids diferents a cada GPU. I, de manera fonamental, el model és d'un
sol fil d'execució, cosa que impedeix aprofitar els processadors multinucli.

=== Un primer intent des de dins: AZDO

La primera resposta a aquests límits no va ser substituir l'API, sinó intentar
resoldre'ls dins del marc existent. Aquesta és exactament la pregunta que
planteja la iniciativa AZDO —#f[Approaching Zero Driver Overhead]—: si els
inconvenients del model clàssic es poden corregir sense renunciar-ne als
avantatges @everitt2014.

La resposta tècnica consisteix a desacoblar el processador de la GPU i fer que
es comuniquin a través de la memòria en lloc de fer-ho a través de crides a
l'API. L'aplicació escriu a memòria les ordres de dibuix indirectes, els objectes
de #f[buffer] i les referències a textures; la GPU llegeix les ordres
directament de memòria; i la intervenció del controlador es redueix al mínim.
Com que la comunicació passa per memòria i no per l'API, diversos fils
d'execució hi poden escriure simultàniament sense necessitat de cap mecanisme
nou @everitt2014.

Els resultats reportats són d'entre cinc i quinze vegades el rendiment original
en els casos limitats pel controlador @everitt2014. Es tracta, doncs, d'una
millora substancial obtinguda sense trencar res: AZDO destaca explícitament com
a avantatges que la proposta no requereix un model d'objectes nou ni invalida les
aplicacions existents @everitt2014.

Aquest darrer punt és el que fa que AZDO sigui rellevant per a entendre Vulkan.
La direcció que assenyala —comunicar a través de memòria, minimitzar la
intervenció del controlador, permetre el paral·lelisme real— és precisament la
que Vulkan acabarà adoptant. La diferència és que Vulkan la porta fins al final,
i per fer-ho pren la decisió contrària respecte de la compatibilitat: sí que
defineix un model d'objectes nou i sí que trenca amb les aplicacions existents.

=== Mantle: traslladar la responsabilitat a l'aplicació

El pas següent el marca Mantle, l'API que AMD va publicar el 2014 i que
documenta el 2015 @riguer2015. El diagnòstic de partida és el mateix: els models
de programació de la generació anterior no són solucions idònies en escenaris on
el desenvolupador necessita un control més estret del sistema gràfic i un
sobrecost d'execució menor @riguer2015.

La solució proposada s'articula al voltant d'un principi que val la pena citar
literalment, perquè és el que explica la forma de tot el que ve després:

#quote(block: true, attribution: [@riguer2015, traducció pròpia])[
  L'aplicació és l'àrbitre del renderitzat correcte i l'únic dipositari de
  l'estat persistent. L'anàlisi de les API actuals indica que una solució
  eficient per a lots petits només es pot assolir quan el controlador és tan
  mancat d'estat com sigui possible.
]

D'aquest principi se'n deriva un segon, encara més explícit: quan la
implementació genèrica d'una funcionalitat s'ha demostrat massa ineficient en
altres API, la responsabilitat es trasllada a l'aplicació, perquè aquesta coneix
millor el context de renderitzat i pot aplicar estratègies d'optimització més
intel·ligents. L'exemple que se'n dona és precisament el que més afecta
l'arquitectura d'un motor: la gestió de la memòria de vídeo passa a ser
responsabilitat de l'aplicació @riguer2015.

El manifest per a desenvolupadors que tanca el capítol introductori de Mantle és
inusualment franc sobre què implica això. El controlador deixa de proporcionar
seguretat, millores de rendiment i solucions de compromís; no crea fils
d'execució addicionals d'amagat de l'aplicació, no fa validació extensiva als
camins crítics de rendiment i no recompila #f[shaders] en segon pla. A canvi,
el desenvolupador ha d'assumir la validació, la correcció d'usos indeguts de
l'API i la sincronització. El document ho formula sense embuts: aquesta
responsabilitat addicional és el preu que s'ha de pagar per obtenir-ne els
avantatges @riguer2015.

=== De Mantle a Vulkan

La correspondència entre els conceptes de Mantle i els de Vulkan és directa i es
pot comprovar comparant l'estructura dels dos documents de referència, tal com
recull la @tab:mantle-vulkan.

#figure(
  table(
    columns: (auto, auto),
    inset: 6pt,
    align: (left, left),
    stroke: 0.4pt + rgb("#ccc"),
    table.header([*Concepte a Mantle* @riguer2015], [*Equivalent a Vulkan* @vulkanspec]),
    [#f[GPU memory heaps], objectes de memòria], [`VkMemoryHeap`, `VkDeviceMemory`],
    [Cues i #f[command buffers]], [`VkQueue`, `VkCommandBuffer`],
    [#f[Command buffer fences]], [`VkFence`],
    [#f[Queue semaphores]], [`VkSemaphore`],
    [#f[Events]], [`VkEvent`],
    [#f[Descriptor sets] i les seves actualitzacions], [`VkDescriptorSet`],
    [Imatges i vistes d'imatge], [`VkImage`, `VkImageView`],
    [Estats de recurs i preparació], [Disposicions d'imatge i barreres],
    [Estat estàtic i estat dinàmic], [Estat de #f[pipeline] i estat dinàmic],
    [#f[Graphics pipelines]], [`VkPipeline`],
    [Capa de validació], [Capes de validació],
  ),
  caption: [Correspondència entre els conceptes de Mantle i els de Vulkan.],
) <tab:mantle-vulkan>

La coincidència no es limita a la nomenclatura. La descripció del model
d'execució és pràcticament la mateixa als dos documents: l'execució dels
#f[command buffers] dins d'una cua és sèrie, però cues diferents poden executar-se
de manera asíncrona, i és responsabilitat de l'aplicació sincronitzar-les;
l'enviament a una cua retorna el control a l'aplicació abans que la feina
s'executi @riguer2015. La formulació de Vulkan és equivalent: les ordres
d'enviament a cua haurien de retornar tan bon punt la feina s'ha enviat, sense
esperar-ne la finalització, i no hi ha restriccions d'ordenació implícites entre
operacions de cues diferents @vulkanspec.

El mateix passa amb el model de memòria. Tots dos documents descriuen un
dispositiu que exposa diversos #f[heaps] amb propietats diferents, adverteixen
que no tota la memòria de la GPU és necessàriament accessible des del
processador, i prescriuen que l'aplicació no faci cap suposició sobre aquesta
visibilitat sinó que consulti les propietats que el sistema reporta
@riguer2015 @vulkanspec. Mantle ja hi descriu, el 2015, el patró que se'n deriva:
quan un #f[heap] concret no és accessible des del processador, les dades s'hi
carreguen mitjançant operacions de còpia de GPU des d'un objecte de memòria que
sí que ho és @riguer2015. Aquesta advertència no és una formalitat, i el capítol
6 en mostra les conseqüències pràctiques sobre maquinari amb memòria unificada.

Aquesta correspondència no és casual. Les discussions de disseny de Vulkan
comencen l'octubre de 2012 i s'acceleren entre el juliol i l'agost de 2014 amb
dos fets decisius: el compromís de diversos desenvolupadors de programari clau i
la cessió de Mantle per part d'AMD @olson2016. L'API resultant es publica el
febrer de 2016, acompanyada de controladors conformes de quatre fabricants, un
compilador de GLSL a SPIR-V i eines de depuració i validació @olson2016.

=== El principi de control explícit

El fonament de Vulkan es formula com un pacte recíproc, i no com una simple
transferència de càrrega cap a l'aplicació @olson2016. L'aplicació es compromet a dir al
controlador què farà, amb prou detall perquè no ho hagi d'endevinar i en el
moment en què el controlador necessita saber-ho. A canvi, el controlador es
compromet a fer exactament allò que se li ha demanat, quan se li ha demanat, i
molt de pressa.

El contrast amb el model anterior és explícit. Les API clàssiques permeten
especificar informació important molt tard i canviar-la en qualsevol moment, la
qual cosa és còmoda però té un cost de rendiment elevat; i els seus controladors
sovint ajornen feina, la traslladen a un altre fil o fins i tot ignoren ordres
basant-se en suposicions sobre la intenció de l'aplicació @olson2016. Els
controladors de Vulkan no ho fan.

D'aquest pacte se'n deriva la política de gestió d'errors, que és igualment
explícita: Vulkan està optimitzat per a aplicacions correctes i, en general, no
comprova usos indeguts, no fa seguiment de dependències i no proporciona
seguretat entre fils; incomplir-ne les regles produeix comportament indefinit
@olson2016. Sí que informa dels errors que l'aplicació no pot preveure —manca de
memòria, pèrdua del dispositiu— i deixa la resta de la comprovació a les capes
de validació, pensades per activar-se durant el desenvolupament. Aquesta divisió
és la que justifica que el motor descrit en aquest treball habiliti la validació
únicament a les compilacions de depuració, tal com es detalla al capítol 4.

=== Conseqüència: l'API imposa l'arquitectura

Convé tornar a la llista de responsabilitats que el model clàssic assignava al
controlador: gestió de riscos d'accés, sincronització i assignació de memòria
@everitt2014. Vulkan les trasllada totes tres a l'aplicació. Aquest trasllat no
és un detall d'implementació, sinó el fet que determina quins subsistemes ha de
tenir qualsevol motor construït sobre aquesta API:

/ Assignació de memòria: si el controlador no gestiona la memòria del
  dispositiu, el motor necessita una estratègia pròpia d'assignació i
  subassignació, i ha de decidir com transfereix les dades cap a memòria no
  visible des del processador.

/ Sincronització: si no hi ha ordenació implícita entre operacions, el motor ha
  de construir explícitament el seu model de ritme de #f[frames] amb primitives
  de sincronització, i ha de decidir quantes imatges processa simultàniament.

/ Estat i validació: si el controlador és mancat d'estat i no valida als camins
  crítics, el motor ha de decidir on col·loca l'estat de renderitzat i com
  n'obté diagnòstic durant el desenvolupament sense pagar-ne el cost en producció.

Aquests tres punts són, precisament, l'índex del capítol 4. Les decisions de
disseny que s'hi documenten no responen a preferències estètiques sinó a
obligacions que l'API imposa, i és per això que aquesta secció ocupa el lloc que
ocupa dins de l'estat de l'art.

== Motors existents i per què construir-ne un

El panorama actual dels motors de propòsit general està dominat per unes poques
solucions madures. Unity @unity_docs i Unreal Engine @unreal_docs ocupen la
major part del mercat comercial, mentre que Godot @godot_docs s'ha consolidat
com l'alternativa de codi obert més estesa. Totes tres ofereixen editors
visuals, sistemes de física, àudio, animació i interfície d'usuari, exportació a
múltiples plataformes i comunitats extenses de documentació i recursos.

Davant d'aquesta oferta, construir un motor propi no té sentit com a proposta de
producte. Cap projecte individual pot competir amb l'abast d'aquestes eines, i
per a desenvolupar un joc la decisió racional és gairebé sempre fer servir-ne
una. La justificació d'aquest treball és d'una altra naturalesa: allò que aquests
motors aporten com a valor —abstreure la complexitat del maquinari gràfic, de la
gestió de memòria i de la sincronització— és precisament allò que aquí
constitueix l'objecte d'estudi. Un motor comercial resol aquests problemes i
n'amaga la solució; l'objectiu d'aquest projecte és entendre-los.

=== El llinatge com a norma en el desenvolupament de motors

Convé situar aquesta decisió en el context de com es construeixen realment els
motors de jocs, perquè la imatge del motor escrit des de zero és poc
representativa de la pràctica del sector. Els motors deriven habitualment
d'altres motors. La tecnologia de Quake, per exemple, va donar lloc a una
successió de títols i motors que passa per Sin, F.A.K.K. 2 i els diversos Medal
of Honor, i fins i tot el motor Source de Valve en té arrels llunyanes
@gregory2018.

Aquesta pràctica té una dimensió pedagògica reconeguda. El codi font de Quake i
Quake II és lliurement accessible i, tot i estar escrit íntegrament en C i haver
quedat desfasat, es considera un exemple net i ben estructurat de com es
construeixen motors de nivell industrial; la recomanació explícita és
descarregar-lo, compilar-lo i analitzar-ne el funcionament executant-lo pas a pas
sota un depurador @gregory2018.

Estudiar una implementació existent i construir-hi a sobre no és, doncs, una
drecera respecte del mètode habitual, sinó el mètode habitual. Aquest treball
adopta aquesta aproximació de manera deliberada i explícita, i el capítol 3
en detalla la metodologia i les fonts.

== Projectes i materials de referència

El desenvolupament d'aquest motor s'ha recolzat en un conjunt de projectes de
codi obert i materials formatius que aborden problemes equivalents. Se'n
detallen aquí els que han tingut un pes real, per ordre d'importància.

/ Kohi: Sèrie de desenvolupament d'un motor de jocs en C i Vulkan, publicada com
  a llista de reproducció de vídeos @vroman_kohi amb el codi font associat
  disponible públicament @vroman_kohi_repo. És la implementació de referència
  principal del projecte: n'estableix l'arquitectura general, l'ordre
  d'incorporació dels subsistemes i bona part de les convencions de nomenclatura.
  El capítol 3 en documenta l'ús concret i delimita què s'ha pres com a base i
  què constitueix aportació pròpia.

/ Handmade Hero: Sèrie que desenvolupa un joc complet en C des de zero, sense
  biblioteques externes @muratori_handmade. Rellevant sobretot pel tractament de
  la gestió de memòria basada en regions i per l'argumentació sobre control
  explícit dels recursos.

/ bgfx: Biblioteca de renderitzat multiplataforma que abstreu diverses API
  gràfiques rere una interfície comuna @bgfx. Serveix com a referència de com es
  dissenya la frontera entre la part del renderitzador independent de l'API i la
  part específica de cada implementació, qüestió que es tracta al capítol 4.

/ Exemples de Vulkan de Sascha Willems: Col·lecció extensa d'exemples que cobreix
  la major part de les funcionalitats de l'API @willems_examples. Emprada com a
  referència puntual de contrast en la implementació de tècniques concretes.

A aquests projectes cal afegir-hi les dues obres que han servit de fonament
teòric al llarg de tot el treball: #obra[Game Engine Architecture]
@gregory2018, per a l'arquitectura de motors, i l'especificació de Vulkan
@vulkanspec, com a font normativa per a tot el que afecta l'API gràfica.

// =============================================================================
= Metodologia i planificació
// Objectiu: ~6 pàgines. Val 0,5 punts directes del ponent (RA2).

== Metodologia de desenvolupament

El desenvolupament s'ha organitzat de manera incremental per subsistemes. Cada
subsistema s'ha portat fins a un estat funcional, s'ha integrat amb els
anteriors i se n'ha documentat el disseny abans de començar el següent. El
resultat és un historial de 38 #f[commits] repartits entre l'agost de 2025 i el
juny de 2026, en què cada un correspon a una unitat de treball coherent i
identificable.

L'ordre d'aquesta incorporació no és arbitrari. L'estructura en capes descrita a
la @fig:capes imposa un ordre de dependències que en determina bona part: no es
pot construir el renderitzador sense una capa de plataforma que proporcioni una
finestra, ni el sistema de textures sense un renderitzador capaç de crear
recursos a la GPU. Dins d'aquesta restricció s'ha prioritzat sempre arribar com
abans millor a un estat executable, encara que fos mínim, per disposar de
verificació empírica contínua.

=== Fases del desenvolupament

Retrospectivament, el treball s'agrupa en tres fases amb caràcter metodològic
diferenciat, recollides a la @tab:fases.

#figure(
  table(
    columns: (auto, auto, 1fr),
    inset: 6pt,
    align: (left, left, left),
    stroke: 0.4pt + rgb("#ccc"),
    table.header([*Fase*], [*Període*], [*Contingut*]),
    [Posada en marxa],
    [ago. -- set. 2025],
    [Registre i assercions, capa de plataforma, capa d'aplicació, memòria,
     esdeveniments, entrada, arrencada de Vulkan fins a esborrar la pantalla,
     biblioteca matemàtica.],
    [Refactorització],
    [des. 2025],
    [Revisió de contenidors i tipus booleans, projecte de proves unitàries,
     assignador lineal, adopció del patró d'inicialització en dues crides i
     migració de tots els subsistemes existents.],
    [Consolidació],
    [des. 2025 -- jun. 2026],
    [Sistema de fitxers, canonada gràfica completa, uniformes i descriptors,
     constants d'inserció, textures des de disc, sistema de textures, suport per
     a Linux, documentació i adaptació a GPU integrades.],
    [Ampliació],
    [set. 2026],
    [Sistemes de materials, de geometria i de recursos amb carregadors
     especialitzats; suport per a múltiples passades de renderitzat i passada
     d'interfície d'usuari; il·luminació direccional; capa d'instrumentació.],
  ),
  caption: [Fases del desenvolupament del motor.],
) <tab:fases>

La fase de refactorització mereix un comentari, perquè il·lustra com ha
funcionat realment el procés. El patró d'inicialització en dues crides que
caracteritza tots els subsistemes del motor no es va dissenyar per endavant:
va aparèixer en aquesta fase, quan ja existien set subsistemes amb esquemes
d'arrencada heterogenis, i es va aplicar retroactivament a tots. El mateix va
passar amb l'assignador lineal, que es va introduir simultàniament perquè el
patró nou el necessitava. L'arquitectura, doncs, no estava completament
planificada des de l'inici; una part es va estabilitzar només després de tenir
prou subsistemes com per veure què tenien en comú.

=== Verificació

La verificació s'ha fet per tres vies complementàries, cadascuna amb un abast
diferent.

La primera és l'execució de l'aplicació de proves, que ha funcionat com a
comprovació contínua d'integració: qualsevol regressió en el camí de renderitzat
es manifesta immediatament de manera visible.

La segona són les capes de validació de Vulkan, que constitueixen l'eina
principal de correcció per a tot el codi gràfic. Com s'ha vist a la secció
corresponent del capítol 2, l'API no comprova els usos indeguts als camins
crítics, de manera que aquestes capes són l'únic mecanisme sistemàtic de
detecció d'errors d'ús durant el desenvolupament.

La tercera són les proves unitàries, incorporades a la fase de refactorització
juntament amb un projecte de proves independent. La seva cobertura és limitada
—únicament l'assignador lineal i la taula de dispersió— perquè s'han aplicat
només als components amb comportament aïllable i verificable sense context
gràfic. Aquesta limitació es discuteix al capítol 7.

=== Documentació com a part del mètode

Paral·lelament al codi s'ha mantingut un corpus de documentació tècnica de 32
documents i aproximadament 1.800 línies, amb un document per subsistema i una
estructura fixa: propòsit, fitxers, interfície pública, funcionament, decisions
de disseny i justificació, limitacions conegudes i referències creuades.

Aquesta documentació no és un subproducte redactat al final, sinó una part del
mètode de treball, i respon a un objectiu concret: obligar a explicitar la
justificació de cada decisió en el moment de prendre-la, i registrar-ne les
limitacions mentre encara són presents. Bona part del material dels capítols 4 i
7 en prové directament. La secció de limitacions conegudes de cada document ha
resultat especialment útil, perquè documentar allò que un subsistema no fa bé és
el que permet, més endavant, distingir una decisió deliberada d'un descuit.

== Procedència de les fonts i ús de projectes de referència

Tal com s'ha exposat a la secció sobre el llinatge en el desenvolupament de
motors, construir sobre una implementació existent és la pràctica habitual del
sector i una via d'aprenentatge reconeguda @gregory2018. Aquest treball hi
recorre de manera deliberada, i aquesta secció en detalla l'abast amb precisió.

=== Base emprada

La implementació de referència principal ha estat la sèrie Kohi
@vroman_kohi, amb el codi font associat @vroman_kohi_repo. Se n'han pres
l'arquitectura general del motor, l'ordre d'incorporació dels subsistemes i les
convencions de nomenclatura, que en el codi d'aquest projecte apareixen amb el
prefix `h` en lloc del prefix original.

La sèrie s'ha fet servir com a implementació de referència, no com a
transcripció. El criteri de treball ha estat que cada decisió estructural
s'estudiés de manera independent contra les fonts primàries —#obra[Game Engine
Architecture] @gregory2018 per a les qüestions d'arquitectura, i l'especificació
de Vulkan @vulkanspec per a tot el que afecta l'API gràfica— abans de
documentar-la. El capítol 4 recull el resultat d'aquest exercici, i l'Annex A en
conté la correspondència detallada entre cada decisió i la font que la fonamenta.

=== Aportacions pròpies

Els elements següents no provenen de la implementació de referència i són
verificables a l'historial del repositori.

/ Adaptació a GPU integrades: El #f[commit] `a0f9a24` adapta el codi de Vulkan a
  dispositius no discrets i corregeix un defecte de sincronització subjacent que
  ho impedia. El defecte només es manifesta quan el nombre d'imatges de la
  #f[swapchain] i el nombre de #f[frames] en vol difereixen, cosa que no succeeix
  al maquinari sobre el qual es desenvolupa la sèrie de referència. Localitzar-lo
  va requerir entendre el model de sincronització de l'API, no reproduir-lo. El
  capítol 5 en detalla el mecanisme.

/ Portabilitat i conformitat: El #f[commit] `317f497` elimina els vectors de
  longitud variable del codi i resol diversos problemes que impedien l'execució
  sobre Linux.

/ Corpus de documentació tècnica: Els 32 documents descrits a la secció anterior,
  amb la justificació i les limitacions de cada subsistema.

/ Anàlisi de correspondència amb les fonts primàries: El document que relaciona
  cada decisió de disseny del motor amb la secció corresponent de les fonts
  normatives, recollit a l'Annex A.

/ Capa d'instrumentació: El subsistema que mesura el cost de cada fase del
  #f[frame], dissenyat a partir de la descripció de perfilatge integrat i
  d'estadístiques de memòria d'@gregory2018. Manté una finestra mòbil de mostres
  per obtenir xifres estables i acumuladors independents del bucle per a les
  operacions que només succeeixen a l'arrencada. El capítol 5 en descriu el
  disseny i el capítol 6 el fa servir.

/ Avaluació empírica: El disseny experimental i les mesures del capítol 6.

#todo[Ampliar aquesta llista si s'implementa l'assignador de #f[frame] amb
marcadors descrit a @gregory2018, que ara mateix consta com a línia de
continuació al capítol 7.]

=== Delimitació

Convé ser explícit sobre el revers d'aquesta llista: la major part dels
subsistemes del motor segueixen l'estructura de la implementació de referència, i
el treball propi en aquests casos consisteix a haver-los comprès, integrats,
depurats i documentats, no a haver-los concebut. Aquesta distinció es manté al
llarg del capítol 5, on cada subsistema indica quina és la seva procedència.

== Planificació temporal

=== Premissa de disponibilitat

La planificació d'aquest treball es va dissenyar sobre una restricció coneguda
des de l'inici: el projecte s'ha desenvolupat de manera simultània a una activitat
laboral a jornada completa, essent el TFG l'única assignatura matriculada del
curs. Aquesta circumstància no permet una dedicació uniforme al llarg de l'any
acadèmic, i la planificació ho va incorporar com a premissa en lloc de
tractar-ho com una contingència.

L'estratègia adoptada va ser concentrar l'esforç als períodes d'alta
disponibilitat i mantenir una cadència reduïda però contínua durant la resta del
temps. En conseqüència, una part substancial del desenvolupament —tota la fase
de posada en marxa descrita a la @tab:fases— es va dur a terme durant l'estiu de
2025, i les fases posteriors es van planificar amb una càrrega setmanal
compatible amb la jornada laboral.

=== Pressupost d'hores

El treball té assignats 16 crèdits ECTS, que constitueixen l'ancoratge del
pressupost de dedicació. #todo[Completar amb la ràtio d'hores per crèdit que
estableix el pla d'estudis —habitualment entre 25 i 30— i el total resultant,
que se situaria entre 400 i 480 hores. Verificar-ho a la normativa del grau en
lloc d'estimar-ho.]

Aquest total s'ha distribuït entre les fases de desenvolupament, l'avaluació i
la redacció de la memòria segons la @tab:planificacio.

#todo[Completar la @tab:planificacio amb les hores previstes i reals per fase.
El rúbric valora que s'hagin «definit tasques, valorant-ne les càrregues i
complert la temporització»; amb la premissa de disponibilitat declarada més
amunt, una distribució desigual entre fases és coherent amb el pla i no
constitueix una desviació.]

=== Fases, càrrega i temporització

#figure(
  table(
    columns: (auto, auto, auto, auto),
    inset: 6pt,
    align: (left, left, right, right),
    stroke: 0.4pt + rgb("#ccc"),
    table.header([*Fase*], [*Període*], [*Hores previstes*], [*Hores reals*]),
    [Posada en marxa], [ago. -- set. 2025], [#todo[--]], [#todo[--]],
    [Refactorització], [des. 2025], [#todo[--]], [#todo[--]],
    [Consolidació], [des. 2025 -- jun. 2026], [#todo[--]], [#todo[--]],
    [Avaluació i mesures], [#todo[--]], [#todo[--]], [#todo[--]],
    [Redacció de la memòria], [#todo[--]], [#todo[--]], [#todo[--]],
    [*Total*], [], [#todo[--]], [#todo[--]],
  ),
  caption: [Distribució de la càrrega de treball per fases.],
) <tab:planificacio>

#todo[Afegir aquí el diagrama de Gantt. L'Annex E n'ha de contenir la versió
detallada; al cos hi va la vista resumida per fases.]

=== Desviacions

#todo[Secció breu i honesta. Reconèixer una desviació i explicar-ne la causa
puntua més que presentar una planificació sense incidències que l'historial del
repositori contradiu. Candidats a esmentar:
+ El sistema de materials es va endarrerir respecte de la previsió inicial.
+ L'adaptació a GPU integrades no estava planificada; va sorgir en detectar que
  el motor no s'executava correctament sobre el maquinari de desenvolupament, i
  va consumir temps no previst. Va acabar sent una de les aportacions pròpies
  del treball, de manera que la desviació té un resultat defensable.]

== Eines i entorn de desenvolupament

=== Llenguatge, compilació i construcció

El motor està escrit en C i es compila exclusivament amb Clang, en la versió
22.1.8 sobre l'entorn de desenvolupament descrit més avall. La construcció es
gestiona amb GNU Make 4.4.1 mitjançant fitxers de construcció separats per
component i per sistema operatiu, de manera que el motor, l'aplicació de proves
i el projecte de proves unitàries es compilen de manera independent. El motor es
genera com a biblioteca compartida i l'aplicació de proves s'hi enllaça.

=== API gràfica i eines associades

El renderitzador es construeix sobre Vulkan. Els #f[shaders] s'escriuen en GLSL i
es compilen a SPIR-V amb `glslc` com a pas posterior a la construcció, atès que
l'API només accepta aquest format intermedi @vulkanspec. La correcció de l'ús de
l'API es verifica amb les capes de validació de Khronos, habilitades únicament a
les compilacions de depuració.

Les eines de Vulkan emprades corresponen a la versió 1.4.357.

#todo[Aclarir si es tracta del SDK de LunarG o dels paquets de la distribució.
En l'entorn Linux, `glslc` reporta la versió 2026.3 (paquet 1:1.4.357.0) i la
variable `VULKAN_SDK` no consta definida, cosa que suggereix paquets del
sistema; el fitxer README del projecte, en canvi, la indica com a requisit.
Convé deixar el requisit documentat de manera coherent entre la memòria i el
README.

Nota sobre les versions, que són tres i cal no barrejar-les: les eines són la
1.4.357; l'especificació citada com a font normativa és la 1.4.361; i la versió
d'API que reporta el dispositiu en temps d'execució depèn del controlador
—1.4.354 a la màquina amb GPU integrada—. Aquesta última és una dada de mesura
i el seu lloc és el capítol 6, no aquí.]

=== Control de versions i documentació

El control de versions s'ha fet amb Git 2.55.0, amb un historial de
#f[commits] d'unitat funcional que és, alhora, el registre cronològic del
desenvolupament. La documentació tècnica del projecte es manté en format Markdown
dins del mateix repositori, i aquesta memòria s'ha redactat amb Typst 0.15.1.
L'anàlisi del codi durant el desenvolupament s'ha recolzat en `clangd`.

=== Maquinari de desenvolupament

L'entorn de desenvolupament i de mesura es detalla a la @tab:maquinari. Les seves
característiques no són un detall administratiu: el fet que la GPU sigui
integrada i comparteixi memòria amb el sistema condiciona directament una part
de les decisions del capítol 4 i és la premissa dels experiments del capítol 6.

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    inset: 6pt,
    align: (left, left, left),
    stroke: 0.4pt + rgb("#ccc"),
    table.header([], [*Equip A --- GPU integrada*], [*Equip B --- GPU discreta*]),
    [Processador],
    [Intel Core i7-1255U (12a gen.), 10 nuclis / 12 fils],
    [AMD Ryzen #todo[model]],
    [GPU],
    [Intel Iris Xe Graphics (ADL GT2), integrada],
    [NVIDIA GeForce GTX 1650 Ti, dedicada],
    [Arquitectura de memòria],
    [Unificada amb el sistema],
    [Memòria de vídeo dedicada],
    [Controlador],
    [Mesa 26.2.1 (codi obert d'Intel)],
    [#todo[Controlador i versió]],
    [Memòria del sistema], [16 GB], [16 GB],
    [Sistema operatiu],
    [#todo[Distribució i nucli]],
    [#todo[Sistema i versió]],
  ),
  caption: [Equips emprats per al desenvolupament i les mesures.],
) <tab:maquinari>

La disponibilitat de dos equips amb arquitectures de memòria diferents no és
una circumstància accessòria, sinó una condició que el treball aprofita de manera
deliberada. L'equip A reporta el dispositiu com a
`PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU`: no disposa de memòria local dedicada, i
els tipus de memòria visibles des del processador coincideixen en bona part amb
els locals al dispositiu. L'equip B, amb GPU dedicada, presenta la separació
clàssica entre les dues.

Aquesta diferència travessa tot el treball. És la que va fer aflorar el defecte
de sincronització documentat a la secció d'aportacions pròpies, que només es
manifesta sobre l'equip A; és la que dona sentit a l'advertència de la
documentació de Mantle sobre no presuposar la visibilitat directa de la memòria
@riguer2015; i és la que permet que els experiments del capítol 6 siguin
comparatius en lloc de descriptius, contrastant el comportament de les dues
arquitectures en lloc de caracteritzar-ne una de sola.

// =============================================================================
= Decisions de disseny
// Objectiu: ~13 pàgines. Aquest capítol és on es guanya la defensa.
//
// Format recomanat per a cada secció, perquè és el que resisteix preguntes:
//   (a) quin problema es planteja
//   (b) quines alternatives hi havia
//   (c) quin criteri s'ha aplicat
//   (d) què s'hi ha guanyat i què s'hi ha perdut  ← no ometre mai (d)

Les decisions que recull aquest capítol no es presenten com a solucions òptimes.
En programari rarament n'hi ha cap que ho sigui en termes absoluts: hi ha
opcions que encaixen millor amb uns objectius determinats i pitjor amb uns
altres, i el que fa útil una decisió és haver-la pres sabent amb quins objectius
havia d'encaixar. El criteri que ha guiat el projecte ha estat, doncs, escollir
en funció dels objectius plantejats al capítol 1 —i, en algun cas, de l'interès
per entendre un mecanisme concret— després d'haver considerat les alternatives
disponibles.

Cada secció segueix la mateixa estructura: quin problema planteja la decisió,
quines alternatives es van considerar, quin criteri es va aplicar i què s'hi va
guanyar i què s'hi va perdre. L'últim punt hi consta sempre, perquè és el que
permet jutjar si el criteri era encertat.

== Vulkan com a API gràfica

=== Problema i alternatives

La primera decisió del projecte condiciona la resta: sobre quina API gràfica es
construeix el renderitzador. El criteri previ que va delimitar el conjunt
d'alternatives va ser que es tractés d'una API amb ús professional real a la
indústria del videojoc, atès que un dels propòsits del treball és entendre les
eines que s'hi fan servir. Aquest criteri va deixar fora opcions com WebGPU, que
no es van arribar a considerar.

Van quedar, per tant, tres candidates: OpenGL, Vulkan i DirectX 12.

OpenGL era la més coneguda de partida, atès que s'ha tractat durant el grau. Ara
bé, el seu ús en desenvolupament professional de videojocs ha anat disminuint,
i —cosa més determinant per a aquest projecte— el seu model clàssic delega al
controlador la gestió de riscos d'accés, la sincronització i l'assignació de
memòria @everitt2014, que són precisament els mecanismes que el treball es
proposa entendre. Una API que els resol de manera transparent en fa impossible
l'estudi.

Descartada OpenGL, la tria quedava entre les dues API de control explícit d'ús
generalitzat: Vulkan i DirectX 12.

=== Criteri i decisió

Convé ser explícit sobre un punt: qualsevol de les dues hauria servit. L'objectiu
plantejat no és dominar una API concreta sinó entendre com funciona una API
gràfica moderna de control explícit, i tant Vulkan com DirectX 12 responen a
aquesta descripció i tenen ús professional consolidat. La decisió, doncs, no es
va prendre sobre la superioritat tècnica d'una respecte de l'altra.

El factor que la va determinar va ser la flexibilitat quant al sistema operatiu.
DirectX 12 està limitat a plataformes de Microsoft, mentre que Vulkan permet
executar el mateix codi sobre Windows i Linux, cosa que encaixava amb l'objectiu
de portabilitat plantejat al capítol 1.

Aquesta previsió es va acabar exercint de manera efectiva, i no només com a
possibilitat teòrica. El projecte va començar sobre Windows —la capa de
plataforma inicial és la d'aquest sistema— i posteriorment es va portar a Linux,
que ha estat l'entorn de desenvolupament principal durant els darrers mesos.
Aquest canvi d'entorn, que respon a circumstàncies alienes al disseny del motor,
no hauria estat possible amb DirectX 12. És, per tant, un cas en què el criteri
aplicat va resultar rellevant per raons que en el moment de decidir només es
podien anticipar de manera genèrica.

La portabilitat que aquesta decisió proporciona no s'esgota, a més, en els dos
sistemes operatius emprats. Vulkan és igualment accessible sobre les
plataformes d'Apple, si bé cal precisar per quina via: macOS no dona suport
natiu a Vulkan —el seu entorn gràfic propi és Metal—, sinó que aquest suport
s'obté mitjançant MoltenVK, una implementació que desplega un subconjunt gairebé
complet de Vulkan per sobre de Metal i que tradueix els #f[shaders] de SPIR-V al
llenguatge d'ombreig de Metal @moltenvk. Aquesta implementació dona suport a la
versió 1.4 de l'API, que és la que el motor sol·licita. Incorporar macOS
requeriria, per tant, escriure la capa de plataforma corresponent i la creació de
superfície específica, però no afectaria la resta del renderitzador. Queda fora
de l'abast del treball, tal com s'ha delimitat al capítol 1.

Aquesta manera d'entendre la decisió té reflex, també, en l'arquitectura del
motor. El renderitzador se separa en una part independent de l'API i una
implementació concreta, i el tipus enumerat que identifica la implementació
activa preveu, a més de Vulkan, els casos d'OpenGL i DirectX. Incorporar una
segona implementació requeriria escriure-la i afegir una branca a la funció que
en fa la selecció, sense modificar ni la part independent de l'API ni el codi del
joc. Aquesta separació es descriu en detall més endavant en aquest mateix
capítol.

Convé no exagerar l'abast de cap d'aquestes dues afirmacions. Ni existeix una
implementació per a una API alternativa ni una capa de plataforma per a macOS, i
escriure qualsevol de les dues no seria un exercici menor; en el cas de macOS,
caldria a més verificar quines restriccions imposa un subconjunt de portabilitat
sobre les funcionalitats concretes que el motor utilitza. El que la decisió
preserva no és la portabilitat immediata, sinó el fet que triar Vulkan no hagi
tancat cap d'aquestes portes.

=== Cost de la decisió

El cost principal no prové de triar Vulkan en lloc de DirectX 12 —on hauria
estat comparable— sinó d'haver optat per una API de control explícit en lloc
d'una de clàssica, i convé enunciar-lo sense atenuants. El mateix consorci
Khronos reconeix que l'API és verbosa i complexa, que exposa nombroses arestes i
que hi ha molt per aprendre @olson2016. La conseqüència pràctica és que la
quantitat de codi necessària per arribar a dibuixar el primer triangle és d'un
ordre de magnitud superior a la que requeriria OpenGL, i que una part
substancial del calendari descrit al capítol 3 es va destinar a construir
infraestructura que no produeix cap resultat visible.

A canvi, l'API ofereix un sobrecost de controlador molt inferior, repartible
entre múltiples fils d'execució, i un rendiment més predictible @olson2016.
D'aquests avantatges, aquest treball només n'aprofita parcialment el primer i el
tercer: el motor és d'un sol fil, de manera que la capacitat de repartir la feina
entre nuclis —que és probablement el guany estructural més important de l'API—
queda sense explotar. Aquesta limitació es discuteix al capítol 7.

== C com a llenguatge

=== Problema i alternatives

L'elecció del llenguatge es va plantejar entre C i C++, que són les dues
opcions realistes per a un motor que ha d'interoperar amb una API en C i
mantenir control sobre la disposició de la memòria.

C++ ofereix genèrics, gestió automàtica de recursos mitjançant el patró de
concessió de recursos en la inicialització, sobrecàrrega d'operadors i una
biblioteca estàndard extensa @stroustrup2013. Aquest patró, en particular,
permet adquirir recursos en el constructor i alliberar-los en el destructor,
cosa que elimina les operacions d'assignació explícites del codi general
@stroustrup2013.

=== Una precisió sobre el disseny orientat a dades

L'interès per les tècniques de disseny orientat a dades va motivar inicialment
la inclinació cap a C. Convé, però, precisar l'abast d'aquest argument, perquè
formulat de manera descuidada no se sosté.

El disseny orientat a dades és la pràctica de dissenyar programari desenvolupant
transformacions sobre dades ben formades, on el criteri del que és ben format ve
determinat pel maquinari objectiu i pels patrons de transformació que s'hi han
d'aplicar @fabian_dod. És, per tant, una qüestió de disposició de les dades i de
coneixement del maquinari, i no d'elecció de llenguatge: la font de referència
afirma explícitament que no està arrelat en un sol llenguatge @fabian_dod.

Aquesta mateixa font assenyala que el llenguatge que més se'n beneficia és C++.
La construcció de la frase és, però, paral·lela a la que fa servir per al
maquinari, on sosté que el que més se'n beneficia és aquell que presenta colls
d'ampolla desequilibrats @fabian_dod; és a dir, aquell on el problema és més
acusat i, en conseqüència, el marge de millora més gran. Llegida en aquest
sentit, l'afirmació no diu que C++ sigui el vehicle més adequat per al disseny
orientat a dades, sinó que és on hi ha més a guanyar-hi.

Aquesta lectura és coherent amb l'objecte real de la crítica que l'obra
desenvolupa, que no és cap llenguatge concret sinó el disseny orientat a
objectes com a metodologia: el retret central és que acobla el domini del
problema amb la implementació, i que aquest acoblament genera una inèrcia que
dificulta l'adaptació quan les dades canvien @fabian_dod. C++ no obliga a
programar així, i el disseny orientat a dades hi és plenament practicable.

Cal admetre, tanmateix, un matís que la distinció anterior no cobreix del tot:
si bé el llenguatge no imposa aquell estil, sí que en facilita l'adopció. Els
constructors i destructors que s'executen implícitament en entrar i sortir
d'àmbit, el despatx virtual i els contenidors genèrics d'objectes fan que
l'organització que la crítica desaconsella sigui també el camí de mínima
resistència. La distinció útil, doncs, no és entre llenguatges que permeten el
disseny orientat a dades i llenguatges que no, sinó entre llenguatges que hi
empenyen i llenguatges que empenyen cap a una altra banda.

En qualsevol cas, aquest treball no fa servir el disseny orientat a dades com a
argument per triar C. El que sí que va aportar l'interès per aquestes tècniques
va ser orientar l'atenció cap a la disposició explícita de les dades en memòria,
i és aquesta preocupació —no la metodologia en si— la que té conseqüències sobre
l'elecció del llenguatge.

=== Criteri i decisió

El criteri efectiu és l'explicitud. C no disposa de constructors ni destructors
implícits, ni de gestió automàtica de recursos, ni d'assignacions ocultes rere
abstraccions. Tota reserva de memòria, tot alliberament i tota còpia són
visibles al lloc on succeeixen, i el llenguatge no ofereix cap mecanisme per
delegar-ne la responsabilitat. Programar-hi obliga, per tant, a un tracte
deliberat amb la memòria en cada punt on s'hi accedeix.

En un motor construït sobre una API que trasllada deliberadament a l'aplicació
la gestió de memòria, la sincronització i el cicle de vida dels recursos —tal
com s'ha exposat al capítol 2—, aquesta correspondència entre el model del
llenguatge i el model de l'API té valor pràctic: allò que cal fer explícit a la
GPU també ho és al codi que la governa. En un treball on la disposició i el
cicle de vida de les dades constitueixen l'objecte d'estudi, un llenguatge que
els gestioni en nom del programador n'obstaculitza l'anàlisi, encara que
permetés obtenir el mateix resultat amb menys codi.

Convé precisar l'ordre en què es van prendre aquestes decisions, atès que el
capítol 3 documenta l'ús d'una implementació de referència també escrita en C.
L'elecció del llenguatge va ser prèvia: la cerca de materials de referència es va
fer un cop presa, i el fet que estiguessin escrits en C va ser un criteri de
selecció d'aquests materials i no un factor que intervingués en la decisió.

=== Cost de la decisió

L'absència de genèrics obliga a implementar els contenidors mitjançant macros i
aritmètica de mides en temps d'execució, amb la pèrdua de comprovació de tipus
que això comporta. La gestió manual de recursos trasllada al programador la
responsabilitat que el patró de concessió de recursos en la inicialització
automatitza, amb el risc de fuites i alliberaments duplicats que se'n deriva. I
la biblioteca estàndard, molt més reduïda, obliga a implementar funcionalitat
que en C++ seria immediata, com ara la manipulació de cadenes o les estructures
de dades associatives.

Aquests costos són reals i el motor els paga. La decisió es defensa perquè
l'objectiu del treball no és minimitzar l'esforç d'implementació, sinó fer
visible el comportament que un motor de jocs ha de controlar.

== El motor com a biblioteca compartida i #f[framework]

=== Problema i alternatives

Un motor i el joc que s'hi construeix han de repartir-se el control del flux
d'execució, i cal decidir quina de les dues parts el posseeix. Hi ha dues
maneres habituals de resoldre-ho @gregory2018. Una biblioteca és un conjunt de
funcions i classes que l'aplicació invoca com li convé: ofereix màxima
flexibilitat al programador, a canvi que aquest hagi d'entendre com utilitzar-la
correctament. Un #f[framework], en canvi, és una aplicació parcialment
construïda en què el bucle principal ja està escrit però buit, i que el
programador completa proporcionant les implementacions que hi manquen; en aquest
cas té poc o cap control sobre el flux general.

=== Criteri i decisió

El motor s'ha construït com a #f[framework]. La funció `main` resideix dins de
la biblioteca del motor i no al costat del joc, i és el motor qui condueix la
seqüència d'arrencada, el bucle principal i el tancament.

El joc, per la seva banda, ha de proporcionar una funció que construeixi la seva
instància i n'ompli una estructura amb quatre punters a funció —inicialització,
actualització, renderitzat i resposta a canvis de mida— juntament amb la
configuració de l'aplicació i un punter a l'estat propi del joc, del qual el
motor no coneix l'estructura interna. Abans de continuar, el punt d'entrada
verifica que els quatre punters existeixin i avorta amb un diagnòstic si no és
així.

El criteri que va portar a aquesta decisió és que el bucle principal conté
ordenacions que no són negociables i que no convé que cada joc hagi de tornar a
resoldre. El capítol 5 en detalla un cas concret: l'actualització de l'estat
d'entrada ha de ser l'última operació de cada iteració, perquè és la que
converteix l'estat actual en estat previ i permet consultar transicions de tecla
a la iteració següent. Fer-ho en un altre punt no produeix cap error visible,
però trenca silenciosament la detecció de polsacions. Ordenacions d'aquesta mena
justifiquen que el bucle sigui responsabilitat del motor.

=== Cost de la decisió

El cost és el que s'atribueix habitualment a aquest enfocament: el joc perd el
control del flux @gregory2018. Un joc que necessités una estructura de bucle diferent —per
exemple, per integrar-se dins d'una aplicació amfitriona amb el seu propi bucle
d'esdeveniments— no podria fer-ho sense modificar el motor.

Hi ha, a més, una conseqüència tècnica de la implementació escollida que convé
fer explícita: la funció `main` es proporciona dins d'una capçalera que el codi
del joc inclou, de manera que és la unitat de compilació del joc la que
efectivament la compila. És una solució que funciona i que manté el punt
d'entrada sota control del motor, però que implica que la capçalera només es pot
incloure des d'un únic fitxer del projecte del joc.

== Gestió explícita de memòria

Aquesta és la decisió més característica del motor i la que millor il·lustra la
tesi que travessa el treball: que les fonts consultades, tot i respondre a
preocupacions diferents, convergeixen en la mateixa solució.

=== Problema i alternatives

Cada subsistema del motor manté un estat intern que ha de viure mentre duri
l'execució. Cal decidir qui el reserva, on resideix i quan es allibera.

L'opció immediata és que cada subsistema reservi el seu estat pel seu compte
mitjançant l'assignador general, i que l'alliberi en tancar-se. És senzilla i no
requereix cap coordinació, però reparteix l'estat del motor per tot el munt de
memòria, obliga cada subsistema a dependre d'un assignador concret i no dona al
motor cap control sobre la ubicació ni sobre el moment de l'alliberament.

=== La convergència de dues exigències

La solució adoptada respon a dues exigències de procedència independent.

La primera prové de l'arquitectura de motors. Com s'ha exposat al capítol 2, les
dependències entre subsistemes imposen un ordre d'arrencada, i la recomanació
és fer aquest ordre explícit mitjançant funcions d'arrencada i tancament que
s'invoquen des d'un únic lloc, en lloc de confiar-lo als mecanismes implícits
del llenguatge @gregory2018.

La segona prové de l'API gràfica. Vulkan no reserva memòria en nom de
l'aplicació, i això li imposa una convenció de crida característica: per obtenir
una llista d'elements, la primera crida es fa amb el punter de destinació nul i
retorna el nombre d'elements disponibles; la segona, amb l'espai ja reservat per
l'aplicació, l'omple @vulkanspec. Qui reserva l'emmagatzematge ha de saber-ne
primer la mida.

El patró d'inicialització del motor és la composició d'ambdues. Cada funció
d'inicialització s'invoca dues vegades: la primera amb el punter d'estat nul,
cas en què es limita a informar de la mida que necessita; entre les dues
crides, l'aplicació reserva aquesta quantitat de memòria; i la segona crida ja
rep el bloc i hi construeix l'estat. Aquesta seqüència es repeteix per a cada
subsistema, en l'ordre que les dependències imposen, dins d'una única funció.

La memòria surt d'un assignador lineal, que reserva un bloc de 64 MiB en
iniciar-se i el reparteix de manera incremental sense alliberar-ne mai peces
individuals. L'estat de tots els subsistemes acaba, doncs, en una única regió
contigua amb un cicle de vida igual al del procés.

=== Criteri i decisió

El resultat és que ni la ubicació de l'estat ni el seu moment d'alliberament són
decisions del subsistema, sinó de qui el condueix. Un subsistema que no reserva
la seva pròpia memòria no pot imposar cap assignador a la resta del motor, no
pot fragmentar el munt i no pot sobreviure al bloc que se li ha lliurat.
S'obté, a més, una propietat associada a l'ús d'assignadors d'aquesta mena: la
proximitat en memòria de l'estat que s'utilitza conjuntament @gregory2018.

=== Cost de la decisió

Aquest patró té tres costos que convé enunciar.

El primer és que cada subsistema desa el bloc rebut en un punter estàtic de la
seva unitat de compilació, cosa que fa ergonòmic el patró —cap funció no ha de
rebre un paràmetre de context— però limita el motor a una única instància de
cada subsistema per procés. No hi pot haver dos renderitzadors ni una cua
d'esdeveniments per fil d'execució.

El segon és que la reserva no imposa cap alineació: retorna el següent byte
lliure. Els estats dels subsistemes queden correctament alineats per la mida de
les estructures que els precedeixen, no per garantia de l'assignador. És una
limitació coneguda i es discuteix al capítol 7.

El tercer és que la xifra de 64 MiB descriu l'estat dels subsistemes, però no la
petjada real del motor: els subsistemes que reserven memòria durant la seva
inicialització —el registre obre un fitxer, el sistema d'esdeveniments crea
vectors dinàmics— ho fan fora d'aquest bloc.

== Separació entre la part independent de l'API i la implementació

=== Problema i alternatives

Perquè la decisió documentada a la secció sobre l'API gràfica no quedés en una
declaració d'intencions, calia que el motor no assumís Vulkan arreu. Es tracta
de decidir on se situa la frontera entre allò que qualsevol renderitzador ha de
fer i allò que només té sentit sobre una API concreta.

=== Criteri i decisió

La frontera es materialitza en una estructura de punters a funció que la part
independent de l'API invoca i que una funció de selecció omple segons la
implementació activa. Aquesta estructura declara nou operacions: inicialització,
tancament, notificació de canvi de mida, inici i final de #f[frame],
actualització de l'estat global, actualització d'un objecte, i creació i
destrucció de textures.

El criteri que governa aquesta llista és el nivell d'abstracció. Les operacions
parlen de #f[frames], d'objectes i de textures, no de primitives de la GPU: no
hi ha cap entrada per crear una canonada gràfica, iniciar una passada de
renderitzat o vincular un conjunt de descriptors. Aquesta elecció és deliberada.
Una interfície de gra fi que exposés els conceptes de Vulkan hauria estat més
flexible, però hauria traslladat el model d'aquesta API a la part que se
suposava independent, i qualsevol implementació alternativa hauria hagut
d'emular-lo.

La conseqüència és que la part independent pot mantenir les matrius de
projecció i de vista i un punter a la textura activa sense saber què és un
conjunt de descriptors, i que tot allò específic de l'API —memòria de
dispositiu, #f[command buffers], sincronització, disposicions d'imatge— queda
confinat rere aquestes nou funcions.

=== Cost de la decisió

Els punters a funció no reben cap paràmetre de context. La implementació manté,
per tant, el seu propi estat de manera estàtica, cosa que simplifica les
signatures a canvi d'impedir que hi hagi dues implementacions actives
simultàniament. Per a un motor que selecciona la implementació en temps de
construcció, la limitació no té conseqüències pràctiques.

Hi ha, a més, una fuita coneguda i documentada al codi. La funció que estableix
la matriu de vista s'exporta fora del motor perquè l'aplicació de proves hi
pugui empènyer la matriu de la càmera, i la capçalera la marca explícitament com
una solució provisional. La via correcta seria que el joc escrivís un estat de
més alt nivell i que el renderitzador el llegís del paquet de renderitzat que ja
rep a cada #f[frame], però aquest paquet encara no transporta informació d'escena.
És una excepció reconeguda al criteri que la resta de la secció defensa.

== Model de recursos: referències, identificadors i generacions

=== Problema i alternatives

Els recursos que el motor carrega des de disc —textures i, posteriorment,
materials— es comparteixen entre diverses parts de l'escena i tenen un cost
d'ocupació a la GPU. Cal decidir quan se'n reclama la memòria.

Aquesta qüestió es planteja habitualment com la gestió del cicle de vida dels
recursos, i cada recurs hi té requisits propis: alguns han de romandre en
memòria durant tota la partida, altres tenen un cicle de vida lligat al d'un
nivell concret, i altres encara més breu @gregory2018. La solució establerta és
el recompte de referències, amb la descàrrega del recurs quan el recompte arriba
a zero @gregory2018.

=== Criteri i decisió

El motor implementa aquest esquema mitjançant una taula de dispersió que associa
el nom del recurs amb una estructura que en registra el recompte de referències,
un identificador i un indicador d'alliberament automàtic. Adquirir un recurs
n'incrementa el recompte i, si encara no existeix, en desencadena la càrrega;
alliberar-lo el decrementa.

L'indicador d'alliberament automàtic és el que aporta la política de cicle de
vida. Un recurs adquirit amb aquest indicador desactivat es comporta com un actiu
global @gregory2018: roman carregat encara que el recompte arribi a zero. Amb
l'indicador actiu, es descarrega en deixar de tenir referències. És una versió
d'un sol bit d'una taxonomia de cicles de vida més detallada @gregory2018, però
n'expressa la distinció essencial.

A aquest esquema s'hi afegeix un segon mecanisme. Cada recurs manté, a més de
l'identificador, un camp de generació que s'incrementa cada vegada que el
contingut es torna a carregar. Un punter per si sol no permet saber que allò que
apunta ha estat substituït; la parella formada per l'identificador i la generació
sí que ho permet.

Aquest mecanisme té una utilitat concreta al renderitzador. Els conjunts de
descriptors que vinculen una textura a un #f[shader] han de reescriure's quan la
textura canvia, però reescriure'ls a cada #f[frame] seria innecessari. La
implementació desa, per a cada descriptor, l'identificador i la generació de la
textura que hi té vinculada, i només emet l'operació d'actualització quan algun
dels dos difereix del valor actual del recurs.

=== Cost de la decisió

El recompte de referències és manual: si una part del motor adquireix un recurs i
no l'allibera, aquest no es descarregarà mai. El llenguatge no ofereix cap
mecanisme que ho previngui, cosa que és conseqüència directa de la decisió
documentada a la secció sobre el llenguatge.

Hi ha, a més, una limitació estructural. Aquest esquema s'implementa de manera
independent per a cada tipus de recurs, de manera que el sistema de textures i el
de materials repeteixen la mateixa estructura —taula de dispersió, vector de
registres, recompte i indicador d'alliberament— sense compartir-ne cap. Falta la
capa genèrica de gestió de recursos que unificaria l'accés a qualsevol tipus
d'actiu @gregory2018. Es tracta d'una de les línies de continuació
que es recullen al capítol 7.

El mateix esquema s'aplica avui a tres tipus de recurs —textures, materials i
geometries—, cosa que fa que la mancança descrita al paràgraf anterior sigui més
visible: la repetició no afecta dos subsistemes sinó tres.

// =============================================================================
= Disseny i implementació
// Objectiu: ~16 pàgines.
//
// AVÍS: NO documentar tots els subsistemes amb la mateixa profunditat: es
// llegeix com un manual d'usuari, no com una memòria. Cinc o sis en
// profunditat, la resta en una taula resum amb remissió a l'Annex C.
//
// Aquest capítol és on es fa visible l'abast del motor, que és l'argument
// central del treball: un motor complet queda molt per sobre del que s'ha
// tractat al grau. Val la pena que això es noti.

== Arquitectura general i cicle de vida

#todo[Diagrama de capes + seqüència d'arrencada + cicle d'un #f[frame]. Aquesta
secció és el mapa; les quatre següents són el detall.]

== Gestió de memòria

#todo[`hmemory` amb etiquetes, assignador lineal, i l'assignador de #f[frame]
implementat des de [GEA §6.2.1.3]. Marcar clarament què és aportació pròpia.]

== Sincronització CPU/GPU i el bucle de #f[frame]

#todo[La secció amb més valor de defensa que teniu. Tres sincronitzacions
diferents (CPU per davant de GPU, dibuix després d'adquisició, presentació
després de dibuix) i per què els vectors de semàfors tenen mides diferents.
Explicar el defecte trobat: quan `image_count` i `max_frames_in_flight`
divergeixen — cosa que no passa al maquinari del tutorial — la indexació
incorrecta del semàfor de senyalització provoca l'error. Trobar-lo va exigir
entendre el model, no transcriure'l.]

== Sistemes de recursos

#todo[Textures, materials, geometria. El format `.hmt` com a primer actiu
dirigit per dades. Traçar el camí sencer: fitxer → configuració → recurs →
descriptor de GPU.]

== Resta de subsistemes

Les seccions anteriors tracten en profunditat els quatre subsistemes amb més
càrrega de decisió. Aquesta recull l'inventari complet del motor, per situar-los
dins del conjunt.

El codi font del motor consta de 84 fitxers i aproximadament 12.700 línies,
sense comptar-hi la biblioteca de tercers emprada per descodificar imatges. La
@tab:subsistemes els agrupa segons les capes del model presentat al capítol 2.

#figure(
  table(
    columns: (auto, 1fr, auto),
    inset: 6pt,
    align: (left, left, left),
    stroke: 0.4pt + rgb("#ccc"),
    table.header([*Subsistema*], [*Responsabilitat*], [*Detall*]),

    table.cell(colspan: 3)[_Capa d'independència de plataforma_],
    [Plataforma],
    [Finestra, drenatge d'esdeveniments del sistema, rellotge absolut, reserva de
     memòria i sortida per consola. Implementada per a Windows i per a Linux
     sobre XCB, X11 i xkbcommon.],
    [§5.1],
    [Sistema de fitxers],
    [Lectura i escriptura de fitxers en mode text i binari.],
    [Annex C],

    table.cell(colspan: 3)[_Sistemes bàsics_],
    [Registre i assercions],
    [Sis nivells de severitat, amb els inferiors eliminats en compilacions de
     producció.],
    [Annex C],
    [Memòria],
    [Reserva etiquetada per categoria, amb totals acumulats per etiqueta i
     recompte d'assignacions.],
    [§5.2],
    [Assignador lineal],
    [Repartiment incremental sobre un bloc fix, sense alliberament individual.],
    [§5.2],
    [Instrumentació],
    [Mesura del cost de cada fase del #f[frame] sobre una finestra mòbil, amb
     acumuladors independents per a operacions fora del bucle.],
    [§5.2],
    [Esdeveniments],
    [Publicació i subscripció per codi d'esdeveniment.],
    [Annex C],
    [Entrada],
    [Estat de teclat i ratolí, amb comparació entre l'estat actual i el previ per
     detectar transicions.],
    [Annex C],
    [Rellotge],
    [Mesura de temps transcorregut, base del càlcul del pas de temps.],
    [Annex C],
    [Cadenes],
    [Manipulació de cadenes i conversió a tipus numèrics i vectorials.],
    [Annex C],
    [Contenidors],
    [Vector dinàmic amb capçalera de metadades i taula de dispersió.],
    [Annex C],
    [Matemàtiques],
    [Vectors, matrius, quaternions i les projeccions i transformacions que el
     renderitzador necessita.],
    [Annex C],

    table.cell(colspan: 3)[_Gestió de recursos_],
    [Sistema de recursos],
    [Registre de carregadors especialitzats i resolució de rutes a partir d'una
     arrel configurable.],
    [§5.4],
    [Carregadors],
    [Quatre implementacions especialitzades: text, binari, imatge i material.],
    [§5.4],
    [Textures],
    [Adquisició per nom amb recompte de referències i textura per defecte
     generada per codi.],
    [§5.4],
    [Materials],
    [Adquisició per nom a partir de fitxers de configuració, amb color difús i
     mapa de textura.],
    [§5.4],
    [Geometria],
    [Registre de geometries i generadors de plans i de cubs amb normals.],
    [§5.4],

    table.cell(colspan: 3)[_Renderitzador_],
    [Part independent de l'API],
    [Estat de projecció, vista i il·luminació, i despatx cap a la implementació
     activa mitjançant una taula de punters a funció.],
    [§5.1],
    [Implementació de Vulkan],
    [Instància, dispositiu, cadena d'intercanvi, passades de renderitzat,
     #f[command buffers], canonades, búfers, imatges i sincronització.],
    [§5.3],
    [#f[Shaders] integrats],
    [Dos programes: el de materials, amb il·luminació direccional, i el
     d'interfície d'usuari.],
    [§5.3],
  ),
  caption: [Inventari de subsistemes del motor.],
) <tab:subsistemes>

=== Evolució de l'estructura

L'inventari actual no coincideix amb el que hauria resultat d'anar afegint
subsistemes sense revisar-ne cap. Dos casos il·lustren com ha canviat
l'estructura durant el desenvolupament.

El primer és la incorporació del suport per a múltiples passades de renderitzat.
Fins aleshores el motor tenia una única passada i mòduls independents per als
#f[framebuffers] i per a les tanques de sincronització. En generalitzar el
tractament de passades, tots dos van deixar de tenir entitat pròpia i van passar
a formar part de l'abstracció de passada, de manera que els fitxers
corresponents es van eliminar. El nombre de mòduls va disminuir mentre la
funcionalitat augmentava.

El segon és l'aparició del sistema de recursos. Els sistemes de textures i de
materials havien nascut accedint directament al sistema de fitxers i component
les rutes amb literals dins del codi. La introducció d'una capa de càrrega amb
carregadors especialitzats va permetre retirar aquest accés directe i centralitzar
la resolució de rutes. Es tracta, precisament, del tipus de capa genèrica que la
secció sobre el model de recursos del capítol 4 assenyalava com a mancança, tot i
que la unificació encara no és completa.

#todo[Aquesta última afirmació cal contrastar-la amb l'estat final del codi: el
sistema de recursos resol la càrrega, però els sistemes de textures, materials i
geometria continuen mantenint cadascun la seva pròpia taula de referències. Cal
decidir si això es presenta com a unificació parcial o com a mancança pendent.]

// =============================================================================
= Resultats i discussió
// Objectiu: ~9 pàgines.
//
// El rúbric exigeix «resultados» com a element estructural (RA3) i valora la
// «capacidad de análisis» (RA1). No cal que aquest capítol carregui l'argument
// d'originalitat — això ho fa l'abast del motor — però sí que ha de tancar el
// cercle amb els objectius de §1.2 i demostrar criteri analític.
//
// El títol conté literalment «resultats» i «discussió» perquè el rúbric els
// busca a l'índex.

== Metodologia de mesura

#todo[Com es mesura: instrumentació pròpia, nombre de repeticions, què es
descarta (#f[frames] d'escalfament), maquinari i controlador exactes. Sense
això, els resultats no són defensables.]

== Assoliment dels objectius funcionals

#todo[Per a cada objectiu específic de §1.2, l'evidència que s'ha assolit.
Captures del motor en funcionament. Aquesta secció és la que tanca el cercle
amb «los objetivos están bien delimitados».]

== Experiments

#todo[Dos o tres n'hi ha prou. Candidats, per ordre de valor:

+ *#f[Staging buffer] enfront d'escriptura directa sobre memòria unificada.*
  Sobre GPU integrada, `DEVICE_LOCAL` i `HOST_VISIBLE` coincideixen, de manera
  que la còpia intermèdia pot ser sobrecost pur. La mateixa especificació preveu
  el cas d'un únic munt [VkSpec §3.2].
+ *`max_frames_in_flight` a 1, 2 i 3.* Temps de #f[frame] enfront de latència
  d'entrada.
+ *Modes de presentació MAILBOX i FIFO.*
+ *Reescriptura de descriptors cada #f[frame] enfront de reescriptura només quan
  canvia `generation`.*

Els experiments s'executen sobre els dos equips de la @tab:maquinari, de manera
que cada resultat es pot llegir en contrast entre una arquitectura de memòria
unificada i una de separada.

Cada un: hipòtesi, muntatge, gràfic, lectura. Un gràfic amb una lectura honesta
val més que quatre gràfics sense.]

== Discussió

#todo[Què signifiquen els resultats i què impliquen per al disseny del motor.
Interessa especialment on el consell general de la literatura no s'ajusta al cas
concret mesurat — per exemple, si la còpia intermèdia resulta innecessària sobre
memòria unificada.]

== Limitacions de l'avaluació

#todo[Una sola màquina, un sol controlador, escena mínima. Reconèixer-ho
enforteix la secció; amagar-ho la debilita si algú del tribunal ho pregunta.]

// =============================================================================
= Conclusions
// Objectiu: ~5 pàgines.
// La plantilla exigeix EXACTAMENT aquests quatre continguts:

== Conclusions del treball realitzat

#todo[Tancar contra els objectius de §1.2, un per un.]

== Punts forts i punts febles

#todo[Exigit per la plantilla. Els punts febles escrits per un mateix són el
senyal més fort de comprensió que es pot donar — i desactiven la meitat de les
preguntes hostils possibles.]

== Limitacions

#todo[Un sol fil d'execució, un sol #f[render pass], sense alineació a
l'assignador, geometria limitada. Les seccions «Known limitations» de `docs/`
ja contenen aquest material.]

== Línies de continuació

#todo[Sistema de tasques concurrents, cua de renderitzat, subassignador de
memòria de GPU, sistema de recursos genèric. Cada una amb la font que en
descriu el disseny.]

// =============================================================================
#heading(numbering: none)[Referències]

#todo[Estil numerat [1], [2]... referenciat de manera creuada des del text.
El fitxer `refs.bib` conté una base inicial. Verificar cada entrada: any,
editorial, ISBN, URL i data de consulta. Val 0,5 punts, i és el criteri més
barat de tot el rúbric.]

#bibliography("refs.bib", style: "ieee", title: none)

// =============================================================================
#heading(numbering: none)[Annexos]

#todo[
/ Annex A: Mapatge de decisions de disseny a fonts primàries. (Traducció i
  adaptació de `docs/analysis/concepts-and-sources.typ`.)
/ Annex B: Manual de compilació i execució.
/ Annex C: Referència de l'API pública dels subsistemes.
/ Annex D: Resultats complets de les mesures. (Al cos, només els gràfics.)
/ Annex E: Planificació detallada i diagrama de Gantt.
]
