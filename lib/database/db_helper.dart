import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

// =========================================================================
// 1. CONFIGURACIÓN E INICIALIZACIÓN (Singleton)
// =========================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hanzi_dojo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Migración incremental ─────────────────────────────────────────────────
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v4: esquema completamente nuevo — recrear todo
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS ejemplos');
      await db.execute('DROP TABLE IF EXISTS vocabulario');
      await db.execute('DROP TABLE IF EXISTS oraciones');
      await db.execute('DROP TABLE IF EXISTS radicales');
      await db.execute('DROP TABLE IF EXISTS caracteres');
      await _createDB(db, newVersion);
      debugPrint("✅ Migración v4: esquema minimalista creado.");
    }
  }

  // ── Creación inicial ──────────────────────────────────────────────────────
  Future _createDB(Database db, int version) async {
    // Tabla principal de caracteres
    await db.execute('''
    CREATE TABLE caracteres (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      caracter         TEXT NOT NULL,
      pinyin           TEXT NOT NULL,
      significado      TEXT,
      nivel_hsk        INTEGER DEFAULT 7,
      es_radical       INTEGER DEFAULT 0,
      numero_radical   INTEGER DEFAULT 0,
      trazos           TEXT,
      medianas         TEXT,
      srs_interval     INTEGER DEFAULT 0,
      e_factor         REAL DEFAULT 2.5,
      proximo_repaso   INTEGER DEFAULT 0,
      veces_visto      INTEGER DEFAULT 0,
      aciertos_seguidos INTEGER DEFAULT 0
    )
    ''');

    // Tabla de ejemplos
    await db.execute('''
    CREATE TABLE ejemplos (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      caracter_id  INTEGER NOT NULL,
      oracion_zh   TEXT NOT NULL,
      oracion_es   TEXT,
      pinyin       TEXT,
      FOREIGN KEY (caracter_id) REFERENCES caracteres (id) ON DELETE CASCADE
    )
    ''');

    // Catálogo fijo de 214 radicales Kangxi
    await db.execute('''
    CREATE TABLE radicales (
      numero     INTEGER PRIMARY KEY,
      caracter   TEXT NOT NULL,
      nombre_es  TEXT,
      pinyin     TEXT
    )
    ''');

    // Poblar tabla de radicales
    await _poblarRadicales(db);
  }

  // ── Catálogo de 214 radicales Kangxi ─────────────────────────────────────
  Future _poblarRadicales(Database db) async {
    final List<Map<String, dynamic>> radicales = [
      {"numero":1,"caracter":"一","nombre_es":"uno","pinyin":"yī"},
      {"numero":2,"caracter":"丨","nombre_es":"línea vertical","pinyin":"gǔn"},
      {"numero":3,"caracter":"丶","nombre_es":"punto","pinyin":"zhǔ"},
      {"numero":4,"caracter":"丿","nombre_es":"trazo oblicuo","pinyin":"piě"},
      {"numero":5,"caracter":"乙","nombre_es":"gancho","pinyin":"yǐ"},
      {"numero":6,"caracter":"亅","nombre_es":"gancho vertical","pinyin":"jué"},
      {"numero":7,"caracter":"二","nombre_es":"dos","pinyin":"èr"},
      {"numero":8,"caracter":"亠","nombre_es":"tapa","pinyin":"tóu"},
      {"numero":9,"caracter":"人","nombre_es":"persona","pinyin":"rén"},
      {"numero":10,"caracter":"儿","nombre_es":"piernas","pinyin":"ér"},
      {"numero":11,"caracter":"入","nombre_es":"entrar","pinyin":"rù"},
      {"numero":12,"caracter":"八","nombre_es":"ocho","pinyin":"bā"},
      {"numero":13,"caracter":"冂","nombre_es":"borde","pinyin":"jiōng"},
      {"numero":14,"caracter":"冖","nombre_es":"cubierta","pinyin":"mì"},
      {"numero":15,"caracter":"冫","nombre_es":"hielo","pinyin":"bīng"},
      {"numero":16,"caracter":"几","nombre_es":"mesa","pinyin":"jǐ"},
      {"numero":17,"caracter":"凵","nombre_es":"recipiente","pinyin":"kǎn"},
      {"numero":18,"caracter":"刀","nombre_es":"cuchillo","pinyin":"dāo"},
      {"numero":19,"caracter":"力","nombre_es":"fuerza","pinyin":"lì"},
      {"numero":20,"caracter":"勹","nombre_es":"envolver","pinyin":"bāo"},
      {"numero":21,"caracter":"匕","nombre_es":"cuchara","pinyin":"bǐ"},
      {"numero":22,"caracter":"匚","nombre_es":"caja","pinyin":"fāng"},
      {"numero":23,"caracter":"匸","nombre_es":"ocultar","pinyin":"xì"},
      {"numero":24,"caracter":"十","nombre_es":"diez","pinyin":"shí"},
      {"numero":25,"caracter":"卜","nombre_es":"adivinación","pinyin":"bǔ"},
      {"numero":26,"caracter":"卩","nombre_es":"sello","pinyin":"jié"},
      {"numero":27,"caracter":"厂","nombre_es":"acantilado","pinyin":"hǎn"},
      {"numero":28,"caracter":"厶","nombre_es":"privado","pinyin":"sī"},
      {"numero":29,"caracter":"又","nombre_es":"otra vez","pinyin":"yòu"},
      {"numero":30,"caracter":"口","nombre_es":"boca","pinyin":"kǒu"},
      {"numero":31,"caracter":"囗","nombre_es":"recinto","pinyin":"wéi"},
      {"numero":32,"caracter":"土","nombre_es":"tierra","pinyin":"tǔ"},
      {"numero":33,"caracter":"士","nombre_es":"erudito","pinyin":"shì"},
      {"numero":34,"caracter":"夂","nombre_es":"caminar despacio","pinyin":"zhǐ"},
      {"numero":35,"caracter":"夊","nombre_es":"caminar despacio","pinyin":"suī"},
      {"numero":36,"caracter":"夕","nombre_es":"atardecer","pinyin":"xī"},
      {"numero":37,"caracter":"大","nombre_es":"grande","pinyin":"dà"},
      {"numero":38,"caracter":"女","nombre_es":"mujer","pinyin":"nǚ"},
      {"numero":39,"caracter":"子","nombre_es":"hijo","pinyin":"zǐ"},
      {"numero":40,"caracter":"宀","nombre_es":"techo","pinyin":"mián"},
      {"numero":41,"caracter":"寸","nombre_es":"pulgada","pinyin":"cùn"},
      {"numero":42,"caracter":"小","nombre_es":"pequeño","pinyin":"xiǎo"},
      {"numero":43,"caracter":"尢","nombre_es":"cojo","pinyin":"wāng"},
      {"numero":44,"caracter":"尸","nombre_es":"cuerpo","pinyin":"shī"},
      {"numero":45,"caracter":"屮","nombre_es":"brote","pinyin":"chè"},
      {"numero":46,"caracter":"山","nombre_es":"montaña","pinyin":"shān"},
      {"numero":47,"caracter":"巛","nombre_es":"río","pinyin":"chuān"},
      {"numero":48,"caracter":"工","nombre_es":"trabajo","pinyin":"gōng"},
      {"numero":49,"caracter":"己","nombre_es":"uno mismo","pinyin":"jǐ"},
      {"numero":50,"caracter":"巾","nombre_es":"tela","pinyin":"jīn"},
      {"numero":51,"caracter":"干","nombre_es":"seco","pinyin":"gān"},
      {"numero":52,"caracter":"幺","nombre_es":"pequeño","pinyin":"yāo"},
      {"numero":53,"caracter":"广","nombre_es":"cobertizo","pinyin":"guǎng"},
      {"numero":54,"caracter":"廴","nombre_es":"caminar largo","pinyin":"yǐn"},
      {"numero":55,"caracter":"廾","nombre_es":"manos unidas","pinyin":"gǒng"},
      {"numero":56,"caracter":"弋","nombre_es":"lanza","pinyin":"yì"},
      {"numero":57,"caracter":"弓","nombre_es":"arco","pinyin":"gōng"},
      {"numero":58,"caracter":"彐","nombre_es":"hocico","pinyin":"jì"},
      {"numero":59,"caracter":"彡","nombre_es":"pelo","pinyin":"shān"},
      {"numero":60,"caracter":"彳","nombre_es":"paso pequeño","pinyin":"chì"},
      {"numero":61,"caracter":"心","nombre_es":"corazón","pinyin":"xīn"},
      {"numero":62,"caracter":"戈","nombre_es":"lanza","pinyin":"gē"},
      {"numero":63,"caracter":"戶","nombre_es":"puerta","pinyin":"hù"},
      {"numero":64,"caracter":"手","nombre_es":"mano","pinyin":"shǒu"},
      {"numero":65,"caracter":"支","nombre_es":"rama","pinyin":"zhī"},
      {"numero":66,"caracter":"攴","nombre_es":"golpear","pinyin":"pū"},
      {"numero":67,"caracter":"文","nombre_es":"escritura","pinyin":"wén"},
      {"numero":68,"caracter":"斗","nombre_es":"cucharón","pinyin":"dǒu"},
      {"numero":69,"caracter":"斤","nombre_es":"hacha","pinyin":"jīn"},
      {"numero":70,"caracter":"方","nombre_es":"cuadrado","pinyin":"fāng"},
      {"numero":71,"caracter":"无","nombre_es":"sin","pinyin":"wú"},
      {"numero":72,"caracter":"日","nombre_es":"sol","pinyin":"rì"},
      {"numero":73,"caracter":"曰","nombre_es":"decir","pinyin":"yuē"},
      {"numero":74,"caracter":"月","nombre_es":"luna","pinyin":"yuè"},
      {"numero":75,"caracter":"木","nombre_es":"árbol","pinyin":"mù"},
      {"numero":76,"caracter":"欠","nombre_es":"deber","pinyin":"qiàn"},
      {"numero":77,"caracter":"止","nombre_es":"parar","pinyin":"zhǐ"},
      {"numero":78,"caracter":"歹","nombre_es":"malo","pinyin":"dǎi"},
      {"numero":79,"caracter":"殳","nombre_es":"arma","pinyin":"shū"},
      {"numero":80,"caracter":"毋","nombre_es":"no","pinyin":"wú"},
      {"numero":81,"caracter":"比","nombre_es":"comparar","pinyin":"bǐ"},
      {"numero":82,"caracter":"毛","nombre_es":"pelo","pinyin":"máo"},
      {"numero":83,"caracter":"氏","nombre_es":"clan","pinyin":"shì"},
      {"numero":84,"caracter":"气","nombre_es":"aire","pinyin":"qì"},
      {"numero":85,"caracter":"水","nombre_es":"agua","pinyin":"shuǐ"},
      {"numero":86,"caracter":"火","nombre_es":"fuego","pinyin":"huǒ"},
      {"numero":87,"caracter":"爪","nombre_es":"garra","pinyin":"zhǎo"},
      {"numero":88,"caracter":"父","nombre_es":"padre","pinyin":"fù"},
      {"numero":89,"caracter":"爻","nombre_es":"líneas del I Ching","pinyin":"yáo"},
      {"numero":90,"caracter":"爿","nombre_es":"tabla","pinyin":"pán"},
      {"numero":91,"caracter":"片","nombre_es":"rebanada","pinyin":"piàn"},
      {"numero":92,"caracter":"牙","nombre_es":"diente","pinyin":"yá"},
      {"numero":93,"caracter":"牛","nombre_es":"vaca","pinyin":"niú"},
      {"numero":94,"caracter":"犬","nombre_es":"perro","pinyin":"quǎn"},
      {"numero":95,"caracter":"玄","nombre_es":"misterioso","pinyin":"xuán"},
      {"numero":96,"caracter":"玉","nombre_es":"jade","pinyin":"yù"},
      {"numero":97,"caracter":"瓜","nombre_es":"melón","pinyin":"guā"},
      {"numero":98,"caracter":"瓦","nombre_es":"teja","pinyin":"wǎ"},
      {"numero":99,"caracter":"甘","nombre_es":"dulce","pinyin":"gān"},
      {"numero":100,"caracter":"生","nombre_es":"nacer","pinyin":"shēng"},
      {"numero":101,"caracter":"用","nombre_es":"usar","pinyin":"yòng"},
      {"numero":102,"caracter":"田","nombre_es":"campo","pinyin":"tián"},
      {"numero":103,"caracter":"疋","nombre_es":"tela","pinyin":"pǐ"},
      {"numero":104,"caracter":"疒","nombre_es":"enfermedad","pinyin":"nè"},
      {"numero":105,"caracter":"癶","nombre_es":"pasos","pinyin":"bō"},
      {"numero":106,"caracter":"白","nombre_es":"blanco","pinyin":"bái"},
      {"numero":107,"caracter":"皮","nombre_es":"piel","pinyin":"pí"},
      {"numero":108,"caracter":"皿","nombre_es":"vasija","pinyin":"mǐn"},
      {"numero":109,"caracter":"目","nombre_es":"ojo","pinyin":"mù"},
      {"numero":110,"caracter":"矛","nombre_es":"lanza larga","pinyin":"máo"},
      {"numero":111,"caracter":"矢","nombre_es":"flecha","pinyin":"shǐ"},
      {"numero":112,"caracter":"石","nombre_es":"piedra","pinyin":"shí"},
      {"numero":113,"caracter":"示","nombre_es":"mostrar","pinyin":"shì"},
      {"numero":114,"caracter":"禸","nombre_es":"pista","pinyin":"róu"},
      {"numero":115,"caracter":"禾","nombre_es":"grano","pinyin":"hé"},
      {"numero":116,"caracter":"穴","nombre_es":"cueva","pinyin":"xué"},
      {"numero":117,"caracter":"立","nombre_es":"estar de pie","pinyin":"lì"},
      {"numero":118,"caracter":"竹","nombre_es":"bambú","pinyin":"zhú"},
      {"numero":119,"caracter":"米","nombre_es":"arroz","pinyin":"mǐ"},
      {"numero":120,"caracter":"糸","nombre_es":"hilo","pinyin":"mì"},
      {"numero":121,"caracter":"缶","nombre_es":"jarro","pinyin":"fǒu"},
      {"numero":122,"caracter":"网","nombre_es":"red","pinyin":"wǎng"},
      {"numero":123,"caracter":"羊","nombre_es":"oveja","pinyin":"yáng"},
      {"numero":124,"caracter":"羽","nombre_es":"pluma","pinyin":"yǔ"},
      {"numero":125,"caracter":"老","nombre_es":"viejo","pinyin":"lǎo"},
      {"numero":126,"caracter":"而","nombre_es":"y además","pinyin":"ér"},
      {"numero":127,"caracter":"耒","nombre_es":"arado","pinyin":"lěi"},
      {"numero":128,"caracter":"耳","nombre_es":"oreja","pinyin":"ěr"},
      {"numero":129,"caracter":"聿","nombre_es":"pincel","pinyin":"yù"},
      {"numero":130,"caracter":"肉","nombre_es":"carne","pinyin":"ròu"},
      {"numero":131,"caracter":"臣","nombre_es":"ministro","pinyin":"chén"},
      {"numero":132,"caracter":"自","nombre_es":"uno mismo","pinyin":"zì"},
      {"numero":133,"caracter":"至","nombre_es":"llegar","pinyin":"zhì"},
      {"numero":134,"caracter":"臼","nombre_es":"mortero","pinyin":"jiù"},
      {"numero":135,"caracter":"舌","nombre_es":"lengua","pinyin":"shé"},
      {"numero":136,"caracter":"舛","nombre_es":"error","pinyin":"chuǎn"},
      {"numero":137,"caracter":"舟","nombre_es":"bote","pinyin":"zhōu"},
      {"numero":138,"caracter":"艮","nombre_es":"límite","pinyin":"gèn"},
      {"numero":139,"caracter":"色","nombre_es":"color","pinyin":"sè"},
      {"numero":140,"caracter":"艸","nombre_es":"hierba","pinyin":"cǎo"},
      {"numero":141,"caracter":"虍","nombre_es":"tigre","pinyin":"hū"},
      {"numero":142,"caracter":"虫","nombre_es":"insecto","pinyin":"chóng"},
      {"numero":143,"caracter":"血","nombre_es":"sangre","pinyin":"xuè"},
      {"numero":144,"caracter":"行","nombre_es":"caminar","pinyin":"xíng"},
      {"numero":145,"caracter":"衣","nombre_es":"ropa","pinyin":"yī"},
      {"numero":146,"caracter":"襾","nombre_es":"cubrir","pinyin":"yà"},
      {"numero":147,"caracter":"见","nombre_es":"ver","pinyin":"jiàn"},
      {"numero":148,"caracter":"角","nombre_es":"cuerno","pinyin":"jiǎo"},
      {"numero":149,"caracter":"言","nombre_es":"palabra","pinyin":"yán"},
      {"numero":150,"caracter":"谷","nombre_es":"valle","pinyin":"gǔ"},
      {"numero":151,"caracter":"豆","nombre_es":"frijol","pinyin":"dòu"},
      {"numero":152,"caracter":"豕","nombre_es":"cerdo","pinyin":"shǐ"},
      {"numero":153,"caracter":"豸","nombre_es":"animal","pinyin":"zhì"},
      {"numero":154,"caracter":"贝","nombre_es":"concha","pinyin":"bèi"},
      {"numero":155,"caracter":"赤","nombre_es":"rojo","pinyin":"chì"},
      {"numero":156,"caracter":"走","nombre_es":"correr","pinyin":"zǒu"},
      {"numero":157,"caracter":"足","nombre_es":"pie","pinyin":"zú"},
      {"numero":158,"caracter":"身","nombre_es":"cuerpo","pinyin":"shēn"},
      {"numero":159,"caracter":"车","nombre_es":"vehículo","pinyin":"chē"},
      {"numero":160,"caracter":"辛","nombre_es":"amargo","pinyin":"xīn"},
      {"numero":161,"caracter":"辰","nombre_es":"hora del dragón","pinyin":"chén"},
      {"numero":162,"caracter":"辵","nombre_es":"caminar","pinyin":"chuò"},
      {"numero":163,"caracter":"邑","nombre_es":"ciudad","pinyin":"yì"},
      {"numero":164,"caracter":"酉","nombre_es":"vino","pinyin":"yǒu"},
      {"numero":165,"caracter":"釆","nombre_es":"distinguir","pinyin":"biàn"},
      {"numero":166,"caracter":"里","nombre_es":"aldea","pinyin":"lǐ"},
      {"numero":167,"caracter":"金","nombre_es":"metal","pinyin":"jīn"},
      {"numero":168,"caracter":"长","nombre_es":"largo","pinyin":"cháng"},
      {"numero":169,"caracter":"门","nombre_es":"puerta","pinyin":"mén"},
      {"numero":170,"caracter":"阜","nombre_es":"colina","pinyin":"fù"},
      {"numero":171,"caracter":"隶","nombre_es":"siervo","pinyin":"lì"},
      {"numero":172,"caracter":"隹","nombre_es":"pájaro","pinyin":"zhuī"},
      {"numero":173,"caracter":"雨","nombre_es":"lluvia","pinyin":"yǔ"},
      {"numero":174,"caracter":"青","nombre_es":"azul-verde","pinyin":"qīng"},
      {"numero":175,"caracter":"非","nombre_es":"no","pinyin":"fēi"},
      {"numero":176,"caracter":"面","nombre_es":"cara","pinyin":"miàn"},
      {"numero":177,"caracter":"革","nombre_es":"cuero","pinyin":"gé"},
      {"numero":178,"caracter":"韦","nombre_es":"cuero curtido","pinyin":"wéi"},
      {"numero":179,"caracter":"韭","nombre_es":"puerro","pinyin":"jiǔ"},
      {"numero":180,"caracter":"音","nombre_es":"sonido","pinyin":"yīn"},
      {"numero":181,"caracter":"页","nombre_es":"página","pinyin":"yè"},
      {"numero":182,"caracter":"风","nombre_es":"viento","pinyin":"fēng"},
      {"numero":183,"caracter":"飞","nombre_es":"volar","pinyin":"fēi"},
      {"numero":184,"caracter":"食","nombre_es":"comida","pinyin":"shí"},
      {"numero":185,"caracter":"首","nombre_es":"cabeza","pinyin":"shǒu"},
      {"numero":186,"caracter":"香","nombre_es":"fragante","pinyin":"xiāng"},
      {"numero":187,"caracter":"马","nombre_es":"caballo","pinyin":"mǎ"},
      {"numero":188,"caracter":"骨","nombre_es":"hueso","pinyin":"gǔ"},
      {"numero":189,"caracter":"高","nombre_es":"alto","pinyin":"gāo"},
      {"numero":190,"caracter":"髟","nombre_es":"cabello largo","pinyin":"biāo"},
      {"numero":191,"caracter":"鬥","nombre_es":"pelear","pinyin":"dòu"},
      {"numero":192,"caracter":"鬯","nombre_es":"vino ceremonial","pinyin":"chàng"},
      {"numero":193,"caracter":"鬲","nombre_es":"trípode","pinyin":"lì"},
      {"numero":194,"caracter":"鬼","nombre_es":"fantasma","pinyin":"guǐ"},
      {"numero":195,"caracter":"鱼","nombre_es":"pez","pinyin":"yú"},
      {"numero":196,"caracter":"鸟","nombre_es":"pájaro","pinyin":"niǎo"},
      {"numero":197,"caracter":"鹵","nombre_es":"sal","pinyin":"lǔ"},
      {"numero":198,"caracter":"鹿","nombre_es":"ciervo","pinyin":"lù"},
      {"numero":199,"caracter":"麦","nombre_es":"trigo","pinyin":"mài"},
      {"numero":200,"caracter":"麻","nombre_es":"cáñamo","pinyin":"má"},
      {"numero":201,"caracter":"黄","nombre_es":"amarillo","pinyin":"huáng"},
      {"numero":202,"caracter":"黍","nombre_es":"mijo","pinyin":"shǔ"},
      {"numero":203,"caracter":"黑","nombre_es":"negro","pinyin":"hēi"},
      {"numero":204,"caracter":"黹","nombre_es":"bordado","pinyin":"zhǐ"},
      {"numero":205,"caracter":"黽","nombre_es":"rana","pinyin":"miǎn"},
      {"numero":206,"caracter":"鼎","nombre_es":"caldero","pinyin":"dǐng"},
      {"numero":207,"caracter":"鼓","nombre_es":"tambor","pinyin":"gǔ"},
      {"numero":208,"caracter":"鼠","nombre_es":"ratón","pinyin":"shǔ"},
      {"numero":209,"caracter":"鼻","nombre_es":"nariz","pinyin":"bí"},
      {"numero":210,"caracter":"齐","nombre_es":"uniforme","pinyin":"qí"},
      {"numero":211,"caracter":"齿","nombre_es":"diente","pinyin":"chǐ"},
      {"numero":212,"caracter":"龙","nombre_es":"dragón","pinyin":"lóng"},
      {"numero":213,"caracter":"龟","nombre_es":"tortuga","pinyin":"guī"},
      {"numero":214,"caracter":"龠","nombre_es":"flauta","pinyin":"yuè"},
    ];

    final Batch batch = db.batch();
    for (final r in radicales) {
      batch.insert('radicales', r);
    }
    await batch.commit(noResult: true);
    debugPrint("✅ 214 radicales Kangxi insertados.");
  }

// =========================================================================
// 2. POBLACIÓN INICIAL
// =========================================================================
  Future<void> poblarBaseDeDatos() async {
    final db = await instance.database;
    final conteo = await db.rawQuery('SELECT COUNT(*) FROM caracteres');
    final int? n = Sqflite.firstIntValue(conteo);
    if (n != null && n > 0) return;

    debugPrint("📖 Leyendo JSON...");
    final String respuesta = await rootBundle
        .loadString('assets/diccionario_supercargado_completo.json');
    final List<dynamic> datos = json.decode(respuesta);

    debugPrint("💾 Inyectando ${datos.length} caracteres...");
    final Batch batch = db.batch();

    for (var item in datos) {
      final String caracter    = item['caracter']       ?? '';
      final String pinyin      = item['pinyin']         ?? '';
      final String significado = item['significado']    ?? '';
      final int nivelHsk       = item['nivel_hsk']      ?? 7;
      final int esRadical      = (item['es_radical'] == true) ? 1 : 0;
      final int numRadical     = item['numero_radical'] ?? 0;
      final String trazosStr   = jsonEncode(item['trazos']   ?? []);
      final String medianasStr = jsonEncode(item['medianas'] ?? []);

      if (caracter.isEmpty) continue;

      batch.insert('caracteres', {
        'caracter'       : caracter,
        'pinyin'         : pinyin,
        'significado'    : significado,
        'nivel_hsk'      : nivelHsk,
        'es_radical'     : esRadical,
        'numero_radical' : numRadical,
        'trazos'         : trazosStr,
        'medianas'       : medianasStr,
      });
    }

    await batch.commit(noResult: true);
    debugPrint("✅ Base de datos poblada con ${datos.length} caracteres.");
  }

// =========================================================================
// 3. MOTOR SRS — SM-2
// =========================================================================
  Future<void> actualizarProgresoSRS(int id, int calificacion) async {
    final db = await instance.database;
    final rows = await db.query('caracteres',
        columns: ['srs_interval', 'e_factor', 'aciertos_seguidos'],
        where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;

    int    intervalo  = rows.first['srs_interval']      as int;
    double eFactor    = rows.first['e_factor']           as double;
    int    aciertos   = rows.first['aciertos_seguidos']  as int;

    if (calificacion < 3) {
      intervalo = 1;
      aciertos  = 0;
    } else {
      intervalo = aciertos == 0 ? 1 : aciertos == 1 ? 6 : (intervalo * eFactor).round();
      aciertos++;
    }

    eFactor = (eFactor + 0.1 - (5 - calificacion) * (0.08 + (5 - calificacion) * 0.02))
        .clamp(1.3, 2.5);

    final int proximoRepaso = DateTime.now()
        .add(Duration(days: intervalo))
        .millisecondsSinceEpoch ~/ 1000;

    await db.update('caracteres', {
      'srs_interval'     : intervalo,
      'e_factor'         : eFactor,
      'aciertos_seguidos': aciertos,
      'veces_visto'      : (rows.first['veces_visto'] as int? ?? 0) + 1,
      'proximo_repaso'   : proximoRepaso,
    }, where: 'id = ?', whereArgs: [id]);
  }

// =========================================================================
// 4. CONSULTAS DE ESTUDIO
// =========================================================================

  // Por nivel HSK
  Future<Map<String, dynamic>?> obtenerSiguienteHanziParaEstudiar(
      int nivelHSK) async {
    final db = await instance.database;
    final int ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final vencidos = await db.query('caracteres',
        where: 'proximo_repaso <= ? AND veces_visto > 0 AND nivel_hsk = ?',
        whereArgs: [ahora, nivelHSK],
        orderBy: 'proximo_repaso ASC', limit: 1);
    if (vencidos.isNotEmpty) return vencidos.first;

    final nuevos = await db.query('caracteres',
        where: 'veces_visto = 0 AND nivel_hsk = ?',
        whereArgs: [nivelHSK],
        orderBy: 'RANDOM()', limit: 1);
    if (nuevos.isNotEmpty) return nuevos.first;

    return null;
  }

  // Por radical
  Future<Map<String, dynamic>?> obtenerSiguienteRadicalParaEstudiar() async {
    final db = await instance.database;
    final int ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final vencidos = await db.query('caracteres',
        where: 'proximo_repaso <= ? AND veces_visto > 0 AND es_radical = 1',
        whereArgs: [ahora],
        orderBy: 'numero_radical ASC', limit: 1);
    if (vencidos.isNotEmpty) return vencidos.first;

    final nuevos = await db.query('caracteres',
        where: 'veces_visto = 0 AND es_radical = 1',
        whereArgs: [],
        orderBy: 'numero_radical ASC', limit: 1);
    if (nuevos.isNotEmpty) return nuevos.first;

    return null;
  }

  // Familia de un radical (todos los caracteres que lo contienen)
  Future<List<Map<String, dynamic>>> obtenerFamiliaDeRadical(
      int numeroRadical) async {
    final db = await instance.database;
    return await db.query('caracteres',
        where: 'numero_radical = ?',
        whereArgs: [numeroRadical],
        orderBy: 'nivel_hsk ASC, caracter ASC');
  }

  // Lista de todos los radicales para PantallaRadicales
  Future<List<Map<String, dynamic>>> obtenerTodosLosRadicales() async {
    final db = await instance.database;
    return await db.query('caracteres',
        where: 'es_radical = 1',
        orderBy: 'numero_radical ASC');
  }

  // Búsqueda general
  Future<List<Map<String, dynamic>>> buscar(String query) async {
    final db = await instance.database;
    final q = '%$query%';
    return await db.query('caracteres',
        where: 'caracter LIKE ? OR pinyin LIKE ? OR significado LIKE ?',
        whereArgs: [q, q, q],
        limit: 20);
  }

  // Catálogo de radicales con nombre en español
  Future<List<Map<String, dynamic>>> obtenerCatalogoRadicales() async {
    final db = await instance.database;
    return await db.query('radicales', orderBy: 'numero ASC');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}