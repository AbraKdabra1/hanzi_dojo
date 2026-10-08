// Guarda las capturas de integration_test/ios_test.dart en build/capturas_ios/.
//   flutter drive --driver=test_driver/integration_test.dart \
//                 --target=integration_test/ios_test.dart -d <simulador>

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (nombre, bytes, [argumentos]) async {
        final archivo = File('build/capturas_ios/$nombre.png');
        archivo.parent.createSync(recursive: true);
        archivo.writeAsBytesSync(bytes);
        return true;
      },
    );
