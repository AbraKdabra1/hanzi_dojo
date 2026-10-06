// ─────────────────────────────────────────────────────────────────────────────
// AppDelegate.swift — Lo que en iPhone/iPad hace el sistema por la app
//
// Los mismos canales que MainActivity.kt / Habito.kt en Android, para que el
// código de Flutter no tenga que saber en qué teléfono corre:
//
//   hanzi_dojo/archivos  guardar (Guardar en Archivos…), abrir (elegir un
//                        archivo), abrirEnlace (Safari) e info (versión y
//                        modelo, para el informe de errores).
//   hanzi_dojo/habito    recordatorio diario con notificaciones locales y
//                        compartir la tarjeta de progreso. (El widget de la
//                        pantalla de inicio todavía no existe en iOS.)
//   hanzi_dojo/energia   modo de bajo consumo y batería. Los 120 Hz los
//                        maneja iOS solo (ProMotion, ver Info.plist).
//
// Recordatorio: iOS no deja revisar la base a la hora del aviso (Android sí),
// así que se programan los avisos de los próximos 14 días y, cada vez que se
// sale de la app, se vuelven a programar: si hoy ya cumpliste tu meta, el de
// hoy se quita.
// ─────────────────────────────────────────────────────────────────────────────

import Flutter
import SQLite3
import UIKit
import UniformTypeIdentifiers
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HanziDojoNativo") {
      HanziDojoNativo.register(with: registrar)
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Canales
// ═════════════════════════════════════════════════════════════════════════════

final class HanziDojoNativo: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  /// Respuesta pendiente del selector de archivos (solo uno a la vez).
  private var pendiente: FlutterResult?
  private var guardando = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instancia = HanziDojoNativo()
    let mensajero = registrar.messenger()
    FlutterMethodChannel(name: "hanzi_dojo/archivos", binaryMessenger: mensajero)
      .setMethodCallHandler { llamada, resultado in instancia.archivos(llamada, resultado) }
    FlutterMethodChannel(name: "hanzi_dojo/habito", binaryMessenger: mensajero)
      .setMethodCallHandler { llamada, resultado in instancia.habito(llamada, resultado) }
    FlutterMethodChannel(name: "hanzi_dojo/energia", binaryMessenger: mensajero)
      .setMethodCallHandler { llamada, resultado in instancia.energia(llamada, resultado) }
    // Se queda viva mientras viva el registro (los canales la retienen).
    registrar.publish(instancia)
  }

  /// La pantalla desde la que se muestran los diálogos.
  private func presentador() -> UIViewController? {
    let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let ventanas = escenas.flatMap { $0.windows }
    var vc = (ventanas.first { $0.isKeyWindow } ?? ventanas.first)?.rootViewController
    while let encima = vc?.presentedViewController { vc = encima }
    return vc
  }

  // ── Archivos ──────────────────────────────────────────────────────────────

  private func archivos(_ llamada: FlutterMethodCall, _ resultado: @escaping FlutterResult) {
    let args = llamada.arguments as? [String: Any] ?? [:]
    switch llamada.method {
    case "abrirEnlace":
      guard let texto = args["url"] as? String, let url = URL(string: texto) else {
        resultado(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { ok in resultado(ok) }

    case "info":
      let info = Bundle.main.infoDictionary ?? [:]
      let datos: [String: String] = [
        "version": info["CFBundleShortVersionString"] as? String ?? "?",
        "compilacion": info["CFBundleVersion"] as? String ?? "?",
        "modelo": "Apple \(HanziDojoNativo.modelo())",
        "android": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
      ]
      resultado(datos)

    case "guardar":
      guard pendiente == nil else {
        resultado(FlutterError(code: "ocupado", message: "Ya hay un diálogo de archivos abierto", details: nil))
        return
      }
      let nombre = (args["nombre"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "archivo"
      let bytes = (args["bytes"] as? FlutterStandardTypedData)?.data ?? Data()
      let carpeta = FileManager.default.temporaryDirectory.appendingPathComponent("guardar", isDirectory: true)
      let url = carpeta.appendingPathComponent(nombre)
      do {
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: url)
        try bytes.write(to: url)
      } catch {
        resultado(FlutterError(code: "archivo", message: error.localizedDescription, details: nil))
        return
      }
      let selector: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        selector = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      } else {
        selector = UIDocumentPickerViewController(url: url, in: .exportToService)
      }
      mostrarSelector(selector, guardando: true, resultado)

    case "abrir":
      guard pendiente == nil else {
        resultado(FlutterError(code: "ocupado", message: "Ya hay un diálogo de archivos abierto", details: nil))
        return
      }
      let selector: UIDocumentPickerViewController
      if #available(iOS 14.0, *) {
        selector = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
      } else {
        selector = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
      }
      mostrarSelector(selector, guardando: false, resultado)

    default:
      resultado(FlutterMethodNotImplemented)
    }
  }

  private func mostrarSelector(
    _ selector: UIDocumentPickerViewController, guardando: Bool, _ resultado: @escaping FlutterResult
  ) {
    guard let vc = presentador() else {
      resultado(FlutterError(code: "sin_selector", message: "No hay pantalla para el selector", details: nil))
      return
    }
    pendiente = resultado
    self.guardando = guardando
    selector.delegate = self
    selector.allowsMultipleSelection = false
    vc.present(selector, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let resultado = pendiente else { return }
    pendiente = nil
    guard let url = urls.first else {
      resultado(nil)
      return
    }
    if guardando {
      resultado(url.lastPathComponent)
      return
    }
    // Leer fuera del hilo de la interfaz (un respaldo o un EPUB pueden pesar).
    DispatchQueue.global(qos: .userInitiated).async {
      let acceso = url.startAccessingSecurityScopedResource()
      defer { if acceso { url.stopAccessingSecurityScopedResource() } }
      do {
        let datos = try Data(contentsOf: url)
        DispatchQueue.main.async {
          let archivo: [String: Any] = ["nombre": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: datos)]
          resultado(archivo)
        }
      } catch {
        DispatchQueue.main.async {
          resultado(FlutterError(code: "archivo", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendiente?(nil)  // el usuario canceló
    pendiente = nil
  }

  /// "iPhone15,2", "iPad13,4"… (el modelo exacto, para el informe de errores).
  static func modelo() -> String {
    var sistema = utsname()
    uname(&sistema)
    let maquina = withUnsafeBytes(of: &sistema.machine) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    return maquina.isEmpty ? UIDevice.current.model : maquina
  }

  // ── Hábito ────────────────────────────────────────────────────────────────

  private func habito(_ llamada: FlutterMethodCall, _ resultado: @escaping FlutterResult) {
    let args = llamada.arguments as? [String: Any] ?? [:]
    switch llamada.method {
    case "programarRecordatorio":
      let hora = args["hora"] as? Int ?? 20
      let minuto = args["minuto"] as? Int ?? 0
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { permitido, _ in
        DispatchQueue.main.async {
          guard permitido else {
            resultado(false)
            return
          }
          Recordatorios.programar(hora: hora, minuto: minuto)
          resultado(true)
        }
      }

    case "cancelarRecordatorio":
      Recordatorios.cancelar()
      resultado(nil)

    case "actualizarWidget":
      // Sin widget todavía; es el momento de rehacer los recordatorios
      // (se llama al salir de la app).
      Recordatorios.reprogramar()
      resultado(nil)

    case "compartirImagen":
      guard let png = (args["png"] as? FlutterStandardTypedData)?.data, let vc = presentador() else {
        resultado(false)
        return
      }
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("hanzi_dojo.png")
      do {
        try png.write(to: url, options: .atomic)
      } catch {
        resultado(false)
        return
      }
      var cosas: [Any] = [url]
      if let texto = args["texto"] as? String, !texto.isEmpty { cosas.append(texto) }
      let hoja = UIActivityViewController(activityItems: cosas, applicationActivities: nil)
      // En iPad la hoja sale como globo y necesita de dónde salir.
      if let globo = hoja.popoverPresentationController {
        globo.sourceView = vc.view
        globo.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
        globo.permittedArrowDirections = []
      }
      vc.present(hoja, animated: true)
      resultado(true)

    default:
      resultado(FlutterMethodNotImplemented)
    }
  }

  // ── Energía ───────────────────────────────────────────────────────────────

  private func energia(_ llamada: FlutterMethodCall, _ resultado: @escaping FlutterResult) {
    switch llamada.method {
    case "ahorro":
      resultado(ProcessInfo.processInfo.isLowPowerModeEnabled)

    case "fluidez":
      // iOS sube y baja la tasa de refresco por su cuenta (ProMotion).
      resultado(nil)

    case "bateria":
      let dispositivo = UIDevice.current
      dispositivo.isBatteryMonitoringEnabled = true
      let nivel = dispositivo.batteryLevel < 0 ? 0 : Int((dispositivo.batteryLevel * 100).rounded())
      let cargando = dispositivo.batteryState == .charging || dispositivo.batteryState == .full
      let pantalla = presentador()?.view.window?.windowScene?.screen ?? UIScreen.main
      // iOS no da la corriente ni la temperatura de la batería.
      let lectura: [String: Any] = [
        "nivel": nivel,
        "cargando": cargando,
        "tasa": Double(pantalla.maximumFramesPerSecond),
      ]
      resultado(lectura)

    default:
      resultado(FlutterMethodNotImplemented)
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Recordatorio diario
// ═════════════════════════════════════════════════════════════════════════════

enum Recordatorios {
  private static let preferencias = UserDefaults.standard
  private static let dias = 14
  private static func identificador(_ dia: Int) -> String { "recordatorio-\(dia)" }

  static func programar(hora: Int, minuto: Int) {
    preferencias.set(true, forKey: "recordatorio_activo")
    preferencias.set(hora, forKey: "recordatorio_hora")
    preferencias.set(minuto, forKey: "recordatorio_minuto")
    reprogramar()
  }

  static func cancelar() {
    preferencias.set(false, forKey: "recordatorio_activo")
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: (0..<dias).map(identificador))
  }

  /// Avisos de hoy (si todavía no cumples tu meta) y de los próximos días.
  static func reprogramar() {
    let centro = UNUserNotificationCenter.current()
    centro.removePendingNotificationRequests(withIdentifiers: (0..<dias).map(identificador))
    guard preferencias.bool(forKey: "recordatorio_activo") else { return }
    let hora = preferencias.integer(forKey: "recordatorio_hora")
    let minuto = preferencias.integer(forKey: "recordatorio_minuto")
    let resumen = DatosHanzi.resumen()
    let ingles = DatosHanzi.ingles()
    let calendario = Calendar.current
    let ahora = Date()
    for dia in 0..<dias {
      guard let fecha = calendario.date(byAdding: .day, value: dia, to: ahora) else { continue }
      var partes = calendario.dateComponents([.year, .month, .day], from: fecha)
      partes.hour = hora
      partes.minute = minuto
      guard let cuando = calendario.date(from: partes), cuando > ahora else { continue }
      if dia == 0, let r = resumen, r.hoy >= r.meta { continue }  // hoy ya cumpliste
      let contenido = UNMutableNotificationContent()
      contenido.title = "Hanzi Dojo · 汉字道场"
      contenido.body = texto(dia == 0 ? resumen : nil, ingles: ingles)
      contenido.sound = .default
      let disparador = UNCalendarNotificationTrigger(dateMatching: partes, repeats: false)
      centro.add(UNNotificationRequest(identifier: identificador(dia), content: contenido, trigger: disparador))
    }
  }

  /// Los mismos textos que en Android (Habito.kt).
  private static func texto(_ r: DatosHanzi.Resumen?, ingles: Bool) -> String {
    guard let r = r else {
      return ingles ? "Today's practice is waiting for you 🖌️" : "Tu práctica de hoy te espera 🖌️"
    }
    if ingles {
      if r.pendientes > 0 { return "You have \(r.pendientes) reviews waiting. A few minutes is enough 🌸" }
      if r.hoy > 0 { return "\(r.hoy) of \(r.meta) done today. Almost there! 🎯" }
      return "Today's practice is waiting for you 🖌️"
    }
    if r.pendientes > 0 { return "Tienes \(r.pendientes) repasos esperando. Unos minutos bastan 🌸" }
    if r.hoy > 0 { return "Llevas \(r.hoy) de \(r.meta) hoy. ¡Ya casi! 🎯" }
    return "Tu práctica de hoy te espera 🖌️"
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Lectura de progreso.db (solo lectura), como DatosHanzi en Habito.kt
// ═════════════════════════════════════════════════════════════════════════════

enum DatosHanzi {
  struct Resumen {
    let hoy: Int
    let meta: Int
    let pendientes: Int
  }

  /// sqflite guarda las bases en Documentos (getDatabasesPath en iOS).
  private static func ruta(_ nombre: String) -> String? {
    let gestor = FileManager.default
    for carpeta in [FileManager.SearchPathDirectory.documentDirectory, .applicationSupportDirectory] {
      if let base = gestor.urls(for: carpeta, in: .userDomainMask).first {
        let ruta = base.appendingPathComponent(nombre).path
        if gestor.fileExists(atPath: ruta) { return ruta }
      }
    }
    return nil
  }

  private static func conBase<T>(_ nombre: String, _ hacer: (OpaquePointer) -> T) -> T? {
    guard let ruta = ruta(nombre) else { return nil }
    var db: OpaquePointer?
    guard sqlite3_open_v2(ruta, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let abierta = db else {
      sqlite3_close(db)
      return nil
    }
    defer { sqlite3_close(abierta) }
    return hacer(abierta)
  }

  /// Un número de una consulta; 0 si la tabla aún no existe.
  private static func numero(_ db: OpaquePointer, _ sql: String, _ arg: Int64? = nil) -> Int {
    var consulta: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &consulta, nil) == SQLITE_OK else { return 0 }
    defer { sqlite3_finalize(consulta) }
    if let arg = arg { sqlite3_bind_int64(consulta, 1, arg) }
    return sqlite3_step(consulta) == SQLITE_ROW ? Int(sqlite3_column_int64(consulta, 0)) : 0
  }

  private static func ajuste(_ db: OpaquePointer, _ clave: String) -> String? {
    var consulta: OpaquePointer?
    guard sqlite3_prepare_v2(db, "SELECT valor FROM ajustes WHERE clave = ?", -1, &consulta, nil) == SQLITE_OK
    else { return nil }
    defer { sqlite3_finalize(consulta) }
    let transitorio = unsafeBitCast(-1, to: sqlite3_destructor_type.self)  // SQLITE_TRANSIENT
    sqlite3_bind_text(consulta, 1, clave, -1, transitorio)
    guard sqlite3_step(consulta) == SQLITE_ROW, let texto = sqlite3_column_text(consulta, 0) else { return nil }
    return String(cString: texto)
  }

  static func resumen() -> Resumen? {
    conBase("progreso.db") { db in
      let inicio = Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
      let ahora = Int64(Date().timeIntervalSince1970)
      let hoy = numero(db, "SELECT count(*) FROM historial WHERE momento >= ?", inicio)
        + numero(db, "SELECT count(*) FROM ejercicios WHERE momento >= ?", inicio)
      let pendientes = numero(db, "SELECT count(*) FROM progreso WHERE proximo_repaso <= ?", ahora)
        + numero(db, "SELECT count(*) FROM progreso_palabras WHERE proximo_repaso <= ?", ahora)
      let meta = ajuste(db, "meta_diaria").flatMap { Int($0) } ?? 20
      return Resumen(hoy: hoy, meta: meta, pendientes: pendientes)
    }
  }

  /// Ajustes › Idioma: 'en', 'es' o 'auto' (el del teléfono).
  static func ingles() -> Bool {
    let elegido: String? = conBase("progreso.db", { ajuste($0, "idioma") }) ?? nil
    switch elegido {
    case "en"?: return true
    case "es"?: return false
    default: return !(Locale.preferredLanguages.first ?? "es").hasPrefix("es")
    }
  }
}
