import 'package:zlib/zlib.dart';

import 'dart:io';

void main() {
  var deflatedBytes = new File('deflated.jpg').readAsBytesSync();
  var inflatedBytes = inflateBytes(deflatedBytes);

  var file = new File('normal.jpg');
  var raf = file.openSync(FileMode.WRITE);
  raf.writeListSync(inflatedBytes, 0, inflatedBytes.length);
  raf.close();
}