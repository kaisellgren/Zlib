import 'package:zlib/zlib.dart';

import 'dart:io';

void main() {
  /*var deflatedBytes = new File('deflated.jpg').readAsBytesSync();
  var inflatedBytes = inflateBytes(deflatedBytes);

  var file = new File('inflated-test.jpg');
  var raf = file.openSync(mode: FileMode.WRITE);
  raf.writeFromSync(inflatedBytes, 0, inflatedBytes.length);
  raf.close();
*/

  var inflatedBytes = new File('inflated.jpg').readAsBytesSync();
  var deflatedBytes = deflateBytes(inflatedBytes);
  inflatedBytes = inflateBytes(deflatedBytes);

  new File('d.jpg').writeAsBytesSync(deflatedBytes);

  var file = new File('test-result.jpg');

  var raf = file.openSync(mode: FileMode.WRITE);
  raf.writeFromSync(inflatedBytes, 0, inflatedBytes.length);
  raf.close();
}