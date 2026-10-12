// ─────────────────────────────────────────────────────────────────────────────
// pantalla_desde_cero.dart — «Chino desde cero»
//
// Para quien nunca ha estudiado chino: seis lecciones de 3 a 5 minutos que
// explican lo que la app da por sabido, cada una con algo que hacer (oír,
// tocar, adivinar, escribir), no solo texto:
//   0. ¿Qué es un hanzi?      1. De dónde vienen      2. Los trazos
//   3. El pinyin              4. Los tonos            5. Tus primeras palabras
// Las piezas interactivas están en widgets/piezas_desde_cero.dart; qué
// lecciones terminaste, en datos/desde_cero.dart.
//
// La primera vez, al terminar el tutorial, PantallaComenzarDesdeCero pregunta
// «¿Nunca has estudiado chino?». Si eliges empezar desde cero, las lecciones
// van en el inicio y Estudiar, Leer y Practicar tienen candado hasta que las
// termines (festejarDesbloqueo); si lo omites, quedan al final de Ajustes.
// Qué elegiste y qué terminaste: datos/desde_cero.dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../datos/datos_app.dart';
import '../datos/desde_cero.dart';
import '../idioma.dart';
import '../tema.dart';
import '../widgets/boton_voz.dart';
import '../widgets/comunes.dart';
import '../widgets/fondo_tinta.dart';
import '../widgets/piezas_desde_cero.dart';
import '../widgets/tarjeta_vidrio.dart';
import 'pantalla_modo.dart';

/// Un paso de una lección: título, explicación y algo que hacer.
class PasoLeccion {
  const PasoLeccion({required this.titulo, this.texto = '', required this.contenido});

  final String titulo;
  final String texto;
  final Widget contenido;
}

class Leccion {
  const Leccion({required this.emoji, required this.titulo, required this.resumen, required this.pasos});

  final String emoji;
  final String titulo;
  final String resumen;
  final List<PasoLeccion> pasos;

  /// Minutos aproximados (casi uno por paso).
  int get minutos => pasos.length < 4 ? 3 : (pasos.length < 6 ? 4 : 5);
}

/// Las seis lecciones (se arman al mostrarse, en el idioma de la app).
List<Leccion> leccionesDesdeCero() => [
      Leccion(
        emoji: '字',
        titulo: tr('¿Qué es un hanzi?'),
        resumen: tr('Por qué el chino no tiene alfabeto y cuántos caracteres hace falta saber.'),
        pasos: [
          PasoLeccion(
            titulo: tr('El chino no tiene alfabeto'),
            texto: tr('En español juntas letras para formar palabras. En chino cada signo es un hanzi (汉字, «carácter chino»): una sílaba que casi siempre tiene significado propio. Toca cada uno para oírlo.'),
            contenido: FilaFichas(fichas: [
              FichaHanzi(texto: '人', pinyin: 'rén', significado: tr('persona')),
              FichaHanzi(texto: '山', pinyin: 'shān', significado: tr('montaña')),
              FichaHanzi(texto: '日', pinyin: 'rì', significado: tr('sol, día')),
              FichaHanzi(texto: '大', pinyin: 'dà', significado: tr('grande')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Las palabras se arman con caracteres'),
            texto: tr('Muchas palabras juntan dos caracteres, y a veces se adivina por qué. Toca el signo de interrogación.'),
            contenido: Column(children: [
              SumaHanzi(partes: [('火', tr('fuego')), ('山', tr('montaña'))], resultado: ('火山', 'huǒ shān', tr('volcán'))),
              const SizedBox(height: 14),
              SumaHanzi(
                  partes: [('电', tr('electricidad')), ('脑', tr('cerebro'))],
                  resultado: ('电脑', 'diàn nǎo', tr('computadora'))),
            ]),
          ),
          PasoLeccion(
            titulo: tr('¿Cuántos hay que aprender?'),
            texto: tr('Existen decenas de miles, pero no hace falta saberlos todos: unos pocos se repiten muchísimo.'),
            contenido: Column(children: [
              DatoGrande(numero: '1,000', texto: tr('Los mil más usados cubren cerca del 90 % de lo que lees en un texto común.')),
              const SizedBox(height: 10),
              DatoGrande(numero: '3,000', texto: tr('Los del examen oficial HSK, del nivel 1 al 9. La app te los enseña de los más fáciles a los más difíciles.')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Ahora tú'),
            texto: tr('Muchos caracteres sencillos empezaron como dibujos.'),
            contenido: PreguntaSimple(
              pregunta: tr('¿Qué crees que significa 木?'),
              opciones: [tr('Árbol'), tr('Agua'), tr('Fuego')],
              correcta: 0,
              explicacion: tr('木 (mù) es un árbol: el tronco, las ramas arriba y las raíces abajo.'),
            ),
          ),
        ],
      ),
      Leccion(
        emoji: '日',
        titulo: tr('De dónde vienen'),
        resumen: tr('Dibujos, ideas juntas y partes que dan el sonido: así se forman los caracteres.'),
        pasos: [
          PasoLeccion(
            titulo: tr('Dibujos que se volvieron letras'),
            texto: tr('Los caracteres más antiguos eran dibujos de lo que nombran. Con los siglos se hicieron más simples y rectos, pero todavía se reconocen.'),
            contenido: FilaFichas(fichas: [
              FichaHanzi(texto: '日', pinyin: 'rì', significado: tr('sol'), nota: tr('un círculo con un punto')),
              FichaHanzi(texto: '月', pinyin: 'yuè', significado: tr('luna'), nota: tr('una luna creciente')),
              FichaHanzi(texto: '山', pinyin: 'shān', significado: tr('montaña'), nota: tr('tres picos')),
              FichaHanzi(texto: '口', pinyin: 'kǒu', significado: tr('boca'), nota: tr('una boca abierta')),
              FichaHanzi(texto: '人', pinyin: 'rén', significado: tr('persona'), nota: tr('alguien caminando')),
              FichaHanzi(texto: '木', pinyin: 'mù', significado: tr('árbol'), nota: tr('ramas y raíces')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Dos ideas juntas, una idea nueva'),
            texto: tr('Otros juntan dos caracteres para formar una idea. Toca el signo de interrogación.'),
            contenido: Column(children: [
              SumaHanzi(partes: [('亻', tr('persona')), ('木', tr('árbol'))], resultado: ('休', 'xiū', tr('descansar'))),
              const SizedBox(height: 12),
              SumaHanzi(partes: [('日', tr('sol')), ('月', tr('luna'))], resultado: ('明', 'míng', tr('brillante'))),
              const SizedBox(height: 12),
              SumaHanzi(partes: [('女', tr('mujer')), ('子', tr('hijo'))], resultado: ('好', 'hǎo', tr('bueno'))),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Una parte da el significado y otra el sonido'),
            texto: tr('La mayoría de los caracteres (unos 3 de cada 4) se forman así: una parte dice de qué trata y otra cómo suena. 马 (mǎ) significa caballo, pero aquí solo presta su sonido.'),
            contenido: Column(children: [
              SumaHanzi(partes: [('女', tr('mujer')), ('马', tr('suena «ma»'))], resultado: ('妈', 'mā', tr('mamá'))),
              const SizedBox(height: 12),
              SumaHanzi(partes: [('口', tr('boca')), ('马', tr('suena «ma»'))], resultado: ('吗', 'ma', tr('¿…? (pregunta)'))),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Los radicales'),
            texto: tr('La parte que da el significado se llama radical, y es una gran pista: 氵 (tres gotas) es agua; 口, boca; 木, árbol. En la app puedes estudiar por radical.'),
            contenido: FilaFichas(fichas: [
              FichaHanzi(texto: '河', pinyin: 'hé', significado: tr('río'), tamano: 34),
              FichaHanzi(texto: '海', pinyin: 'hǎi', significado: tr('mar'), tamano: 34),
              FichaHanzi(texto: '洗', pinyin: 'xǐ', significado: tr('lavar'), tamano: 34),
              FichaHanzi(texto: '吃', pinyin: 'chī', significado: tr('comer'), tamano: 34),
              FichaHanzi(texto: '喝', pinyin: 'hē', significado: tr('beber'), tamano: 34),
              FichaHanzi(texto: '林', pinyin: 'lín', significado: tr('bosque'), tamano: 34),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Ahora tú'),
            contenido: PreguntaSimple(
              pregunta: tr('¿Qué tienen en común 河, 海 y 洗?'),
              opciones: [tr('El agua (氵)'), tr('La boca (口)'), tr('Los árboles (木)')],
              correcta: 0,
              explicacion: tr('Los tres llevan 氵, el radical del agua: río, mar y lavar.'),
            ),
          ),
        ],
      ),
      Leccion(
        emoji: '✍️',
        titulo: tr('Los trazos'),
        resumen: tr('Los trazos básicos, las reglas del orden y tus primeros caracteres en el lienzo.'),
        pasos: [
          PasoLeccion(
            titulo: tr('Todo carácter se escribe con trazos'),
            texto: tr('Un trazo es lo que dibujas sin levantar el dedo. Hay pocos tipos; estos son los más comunes:'),
            contenido: TablaReglas(filas: [
              ('一', tr('Horizontal'), tr('De izquierda a derecha →')),
              ('十', tr('Vertical'), tr('De arriba hacia abajo ↓ (el segundo trazo)')),
              ('人', tr('Diagonales'), tr('Una baja a la izquierda ↙ y otra a la derecha ↘')),
              ('六', tr('Punto'), tr('Corto, hacia abajo y a la derecha (el de arriba)')),
              ('口', tr('Quiebre'), tr('Cambia de dirección sin levantar el dedo (arriba y a la derecha)')),
              ('小', tr('Gancho'), tr('Termina con un pequeño gancho (el del centro)')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('El orden sí importa'),
            texto: tr('Los trazos tienen un orden fijo: así la escritura sale más rápida y bonita, y la app sabe qué trazo esperas. Las reglas principales:'),
            contenido: TablaReglas(filas: [
              ('三', tr('Arriba antes que abajo'), tr('Los tres horizontales, de arriba hacia abajo')),
              ('川', tr('Izquierda antes que derecha'), tr('Los tres trazos, de izquierda a derecha')),
              ('十', tr('Horizontal antes que vertical'), tr('Cuando se cruzan')),
              ('日', tr('De afuera hacia adentro'), tr('El marco primero; la base que lo cierra, al final')),
              ('小', tr('El centro antes que los lados'), tr('Cuando el centro destaca')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Míralo'),
            texto: tr('Así se escribe 十: primero el horizontal, luego el vertical. Toca para repetirlo.'),
            contenido: const OrdenHanzi(caracter: '十'),
          ),
          PasoLeccion(
            titulo: tr('Escribe 十'),
            texto: tr('Con el dedo: el horizontal de izquierda a derecha y luego el vertical de arriba hacia abajo.'),
            contenido: const EscribirHanzi(caracter: '十'),
          ),
          PasoLeccion(
            titulo: tr('Escribe 口'),
            texto: tr('Tres trazos: el lado izquierdo; arriba y a la derecha en uno solo (el quiebre); y la base, que cierra.'),
            contenido: const EscribirHanzi(caracter: '口'),
          ),
        ],
      ),
      Leccion(
        emoji: '🔤',
        titulo: tr('El pinyin'),
        resumen: tr('Cómo se escribe la pronunciación con nuestras letras, y los sonidos que engañan.'),
        pasos: [
          PasoLeccion(
            titulo: tr('El chino escrito con nuestras letras'),
            texto: tr('Los caracteres no dicen cómo suenan. Para eso existe el pinyin: la pronunciación escrita con letras latinas. No reemplaza a los caracteres; es una ayuda para leer y para escribir en el teléfono.'),
            contenido: Center(
              child: FichaHanzi(texto: '你好', pinyin: 'nǐ hǎo', significado: tr('hola'), audio: const ['ní', 'hǎo'], tamano: 48),
            ),
          ),
          PasoLeccion(
            titulo: tr('Muchos sonidos ya los conoces'),
            texto: tr('m, f, n, l, s, w, y y las vocales a, i, o, u suenan casi como en español. Toca para oír:'),
            contenido: TablaSonidos(sonidos: [
              SonidoPinyin('ma', 'ma1', tr('Como en «mamá».')),
              SonidoPinyin('ni', 'ni3', tr('Como en «niño».')),
              SonidoPinyin('lu', 'lu4', tr('Como en «luna».')),
              SonidoPinyin('wo', 'wo3', tr('Como «uo»: la w es una u rápida.')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Los que engañan (1)'),
            texto: tr('Se escriben con letras conocidas, pero suenan distinto:'),
            contenido: TablaSonidos(sonidos: [
              SonidoPinyin('h', 'ha1', tr('Como la «j» de «jamón», pero suave.')),
              SonidoPinyin('x', 'xi1', tr('Una «s» con la lengua abajo, sonriendo: casi «si».')),
              SonidoPinyin('q', 'qi1', tr('Una «ch» con un soplo de aire.')),
              SonidoPinyin('j', 'ji1', tr('Una «ch» suave, sin soplo.')),
              SonidoPinyin('z', 'zi1', tr('Como «ds», sin soplo.')),
              SonidoPinyin('c', 'ci2', tr('Como «ts», con un soplo de aire.')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Los que engañan (2)'),
            texto: tr('Y estos, que no existen en español:'),
            contenido: TablaSonidos(sonidos: [
              SonidoPinyin('zh', 'zhi1', tr('Una «ch» con la punta de la lengua hacia atrás.')),
              SonidoPinyin('ch', 'chi1', tr('Igual que zh, pero con un soplo de aire.')),
              SonidoPinyin('sh', 'shi1', tr('Como la «sh» del inglés, con la lengua hacia atrás.')),
              SonidoPinyin('r', 'ri4', tr('Como la «r» del inglés: nunca vibra.')),
              SonidoPinyin('ü', 'nv3', tr('Di «i» con los labios redondos, como para decir «u».')),
              SonidoPinyin('e', 'e4', tr('Una «e» con la boca relajada, sin sonreír.')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('¿Cuál oíste?'),
            texto: tr('Escucha y elige. Puedes repetirlo las veces que quieras.'),
            contenido: const AdivinaSonido(grupos: [
              ['xi1', 'shi1', 'si1'],
              ['qi1', 'chi1', 'ci1'],
              ['ji1', 'zhi1', 'zi1'],
              ['nv3', 'nu3'],
              ['re4', 'le4'],
            ]),
          ),
        ],
      ),
      Leccion(
        emoji: '🎵',
        titulo: tr('Los tonos'),
        resumen: tr('La melodía de cada sílaba: cuatro tonos (y uno ligero) que cambian el significado.'),
        pasos: [
          PasoLeccion(
            titulo: tr('El tono cambia el significado'),
            texto: tr('En chino cada sílaba tiene una melodía, el tono. La misma sílaba con otro tono es otra palabra. Escucha:'),
            contenido: FilaFichas(fichas: [
              FichaHanzi(texto: '妈', pinyin: 'mā', significado: tr('mamá')),
              FichaHanzi(texto: '麻', pinyin: 'má', significado: tr('cáñamo')),
              FichaHanzi(texto: '马', pinyin: 'mǎ', significado: tr('caballo')),
              FichaHanzi(texto: '骂', pinyin: 'mà', significado: tr('regañar')),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Cuatro tonos (y uno ligero)'),
            texto: tr('La marca sobre la vocal dibuja la melodía. Toca cada uno:'),
            contenido: const DibujoTonos(),
          ),
          PasoLeccion(
            titulo: tr('¿Qué tono oíste?'),
            texto: tr('Al principio cuesta: es lo más difícil para quien habla español, y mejora rápido con práctica. En Practicar → Tonos hay un entrenador completo.'),
            contenido: const AdivinaTono(),
          ),
          PasoLeccion(
            titulo: tr('Un truco para después'),
            texto: tr('Cuando van dos terceros tonos seguidos, el primero se dice como segundo: 你好 se escribe nǐ hǎo, pero suena «ní hǎo». No hace falta memorizarlo: escucha e imita.'),
            contenido: Center(
              child: FichaHanzi(texto: '你好', pinyin: 'nǐ hǎo', significado: tr('hola'), audio: const ['ní', 'hǎo'], tamano: 48),
            ),
          ),
        ],
      ),
      Leccion(
        emoji: '👋',
        titulo: tr('Tus primeras palabras'),
        resumen: tr('Saludar, agradecer y escribir tres caracteres que vas a ver todo el tiempo.'),
        pasos: [
          PasoLeccion(
            titulo: tr('Saludar y agradecer'),
            texto: tr('Toca cada palabra para oírla.'),
            contenido: FilaFichas(fichas: [
              FichaHanzi(texto: '你好', pinyin: 'nǐ hǎo', significado: tr('hola'), audio: const ['ní', 'hǎo'], tamano: 32),
              FichaHanzi(texto: '谢谢', pinyin: 'xièxie', significado: tr('gracias'), audio: const ['xiè', 'xie'], tamano: 32),
              FichaHanzi(texto: '再见', pinyin: 'zàijiàn', significado: tr('adiós'), audio: const ['zài', 'jiàn'], tamano: 32),
              FichaHanzi(texto: '我', pinyin: 'wǒ', significado: tr('yo'), tamano: 32),
              FichaHanzi(texto: '你', pinyin: 'nǐ', significado: tr('tú'), tamano: 32),
              FichaHanzi(texto: '不', pinyin: 'bù', significado: tr('no'), tamano: 32),
            ]),
          ),
          PasoLeccion(
            titulo: tr('Escribe 大'),
            texto: tr('«Grande»: una persona con los brazos abiertos. Tres trazos: el horizontal y luego las dos diagonales.'),
            contenido: const EscribirHanzi(caracter: '大'),
          ),
          PasoLeccion(
            titulo: tr('Escribe 小'),
            texto: tr('«Pequeño»: primero el gancho del centro, luego el lado izquierdo y el derecho.'),
            contenido: const EscribirHanzi(caracter: '小'),
          ),
          PasoLeccion(
            titulo: tr('Escribe 不'),
            texto: tr('«No»: el horizontal de arriba, la diagonal a la izquierda, el vertical y el punto.'),
            contenido: const EscribirHanzi(caracter: '不'),
          ),
          PasoLeccion(
            titulo: tr('¡Ya tienes las bases!'),
            texto: tr('Sigue en Estudiar, en modo novato y nivel 1: la app te enseña cada carácter con su silueta y te avisa cuándo repasarlo. En Practicar entrenas los tonos y en Leer hay cuentos cortos con audio.'),
            contenido: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pastilla(emoji: '✍️', texto: tr('Estudiar')),
                _Pastilla(emoji: '🎧', texto: tr('Practicar')),
                _Pastilla(emoji: '📖', texto: tr('Leer')),
              ],
            ),
          ),
        ],
      ),
    ];

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.emoji, required this.texto});

  final String emoji;
  final String texto;

  @override
  Widget build(BuildContext context) => TarjetaVidrio(
        radio: 24,
        relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Minutos de las lecciones que te faltan (todas si [hechas] está vacío).
int minutosDesdeCero([Set<int> hechas = const {}]) {
  final lecciones = leccionesDesdeCero();
  var total = 0;
  for (var i = 0; i < lecciones.length; i++) {
    if (!hechas.contains(i)) total += lecciones[i].minutos;
  }
  return total;
}

/// La pregunta de la primera vez, al terminar el tutorial: «¿Nunca has
/// estudiado chino?». Devuelve true (empezar desde cero), false (omitir) o
/// null si se cerró sin elegir (se vuelve a preguntar la próxima vez).
class PantallaComenzarDesdeCero extends StatelessWidget {
  const PantallaComenzarDesdeCero({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final lecciones = leccionesDesdeCero();
    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, restricciones) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: restricciones.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              const Text('🌱', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 10),
                              Text(
                                tr('¿Nunca has estudiado chino?'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tr('Empieza desde cero: {0} lecciones cortas (unos {1} minutos en total) te explican lo básico antes de escribir.',
                                    [lecciones.length, minutosDesdeCero()]),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15.5, color: c.suave, height: 1.45),
                              ),
                              const SizedBox(height: 18),
                              TarjetaVidrio(
                                relleno: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                child: Column(
                                  children: [
                                    for (final l in lecciones)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 30,
                                              child: Text(l.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(child: Text(l.titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 17, color: c.suave),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tr('Estudiar, Leer y Practicar se abren al terminarlas. ¿Ya sabes algo de chino? Omítelo: las lecciones quedan al final de Ajustes.'),
                                      style: TextStyle(fontSize: 13.5, color: c.suave, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.boton,
                          foregroundColor: c.textoBoton,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(tr('Empezar desde cero')),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(tr('Omitir'), style: TextStyle(fontSize: 16, color: c.suave)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «¡Terminaste Chino desde cero!»: ya se abrió todo. true = ir a Estudiar.
Future<bool> festejarDesbloqueo(BuildContext context) async {
  final c = context.colores;
  final ir = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(tr('🎉 ¡Terminaste «Chino desde cero»!')),
      content: Text(
        tr('Ya se abrieron Estudiar, Leer y Practicar. Empieza por Estudiar, en modo novato y nivel 1. Las lecciones quedan al final de Ajustes, por si quieres repasarlas.'),
        style: TextStyle(fontSize: 15, color: c.suave, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(contexto, false), child: Text(tr('Después'))),
        FilledButton(onPressed: () => Navigator.pop(contexto, true), child: Text(tr('Ir a Estudiar'))),
      ],
    ),
  );
  return ir ?? false;
}

/// La lista de lecciones, con las que ya terminaste.
class PantallaDesdeCero extends StatefulWidget {
  const PantallaDesdeCero({super.key});

  @override
  State<PantallaDesdeCero> createState() => _PantallaDesdeCeroState();
}

class _PantallaDesdeCeroState extends State<PantallaDesdeCero> {
  Set<int>? _hechas;
  RutaDesdeCero? _ruta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final repo = DatosApp.de(context);
    final hechas = await repo.leccionesTerminadas();
    // ¿Acabas de terminar la última? Se abre todo (y se festeja aquí mismo).
    final desbloqueado = await repo.desbloquearSiTerminaste();
    final ruta = await repo.rutaDesdeCero();
    if (!mounted) return;
    setState(() {
      _hechas = hechas;
      _ruta = ruta;
    });
    if (!desbloqueado) return;
    final estudiar = await festejarDesbloqueo(context);
    if (!mounted || !estudiar) return;
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const PantallaModo()));
  }

  Future<void> _abrir(int i) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PantallaLeccion(indice: i)));
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final hechas = _hechas;
    final lecciones = leccionesDesdeCero();
    final todas = hechas != null && hechas.length >= lecciones.length;
    // La que sigue: la primera sin terminar.
    final siguiente = hechas == null ? 0 : List.generate(lecciones.length, (i) => i).firstWhere((i) => !hechas.contains(i), orElse: () => -1);
    return FondoTintaChina(
      child: Scaffold(
        appBar: BarraSuperior(titulo: tr('Chino desde cero')),
        body: hechas == null
            ? Center(child: CircularProgressIndicator(color: c.icono))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  TarjetaVidrio(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todas
                              ? tr('¡Terminaste las seis! Ya sabes qué es un hanzi, cómo se escribe y cómo suena. Ahora sigue en Estudiar, en modo novato y nivel 1.')
                              : tr('¿Nunca has estudiado chino? Empieza aquí: seis lecciones cortas, de unos minutos cada una, para entender lo básico antes de escribir.'),
                          style: TextStyle(fontSize: 14, color: c.suave, height: 1.4),
                        ),
                        if (_ruta?.bloquea ?? false) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 17, color: c.tinta),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tr('Al terminarlas se abren Estudiar, Leer y Practicar.'),
                                  style: TextStyle(fontSize: 14, color: c.tinta, fontWeight: FontWeight.w600, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (todas) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const PantallaModo()),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(tr('Ir a Estudiar')),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (var i = 0; i < lecciones.length; i++) ...[
                    _FilaLeccion(
                      numero: i + 1,
                      leccion: lecciones[i],
                      hecha: hechas.contains(i),
                      siguiente: i == siguiente,
                      onTap: () => _abrir(i),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _FilaLeccion extends StatelessWidget {
  const _FilaLeccion({
    required this.numero,
    required this.leccion,
    required this.hecha,
    required this.siguiente,
    required this.onTap,
  });

  final int numero;
  final Leccion leccion;
  final bool hecha;
  final bool siguiente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return TarjetaVidrio(
      onTap: onTap,
      colorBorde: siguiente ? c.tinta : null,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(leccion.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$numero. ${leccion.titulo}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(leccion.resumen, style: TextStyle(fontSize: 13, color: c.suave, height: 1.3)),
                const SizedBox(height: 4),
                Text(tr('{0} min', [leccion.minutos]), style: TextStyle(fontSize: 12, color: c.tenue)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          hecha
              ? Icon(Icons.check_circle, color: c.oscuro ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
              : Icon(Icons.arrow_forward_ios, size: 14, color: c.tenue),
        ],
      ),
    );
  }
}

/// Una lección: sus pasos, uno tras otro (con botones; deslizar no cambia de
/// paso para que se pueda escribir con el dedo sin saltar).
class PantallaLeccion extends StatefulWidget {
  const PantallaLeccion({super.key, required this.indice});

  final int indice;

  @override
  State<PantallaLeccion> createState() => _PantallaLeccionState();
}

class _PantallaLeccionState extends State<PantallaLeccion> {
  final _paginas = PageController();
  int _paso = 0;

  @override
  void dispose() {
    _paginas.dispose();
    Voz.detener();
    super.dispose();
  }

  Future<void> _ir(int paso, int total) async {
    Voz.detener();
    if (paso >= total) {
      await DatosApp.de(context).terminarLeccion(widget.indice);
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    await _paginas.animateToPage(paso, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final leccion = leccionesDesdeCero()[widget.indice];
    final total = leccion.pasos.length;
    final ultimo = _paso == total - 1;
    return FondoTintaChina(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: BarraSuperior(titulo: leccion.titulo, subtitulo: tr('Paso {0} de {1}', [_paso + 1, total])),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_paso + 1) / total,
                    minHeight: 5,
                    backgroundColor: c.separador,
                    color: c.tinta,
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _paso = i),
                  children: [for (final p in leccion.pasos) _VistaPaso(paso: p)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    if (_paso > 0) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18)),
                        onPressed: () => _ir(_paso - 1, total),
                        child: Text(tr('Atrás')),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.boton,
                          foregroundColor: c.textoBoton,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _ir(_paso + 1, total),
                        child: Text(ultimo ? tr('Terminar') : tr('Siguiente')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VistaPaso extends StatelessWidget {
  const _VistaPaso({required this.paso});

  final PasoLeccion paso;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(paso.titulo,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.25)),
              if (paso.texto.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(paso.texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, color: c.suave, height: 1.45)),
              ],
              const SizedBox(height: 20),
              paso.contenido,
            ],
          ),
        ),
      ),
    );
  }
}
