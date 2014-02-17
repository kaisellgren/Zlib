/*!
 * Zlib
 *
 * Copyright (C) 2012, Kai Sellgren
 * Licensed under the MIT License.
 * http://www.opensource.org/licenses/mit-license.php
 */

library zlib;

part 'src/deflater.dart';
part 'src/inflater.dart';
part 'src/huffman_table_list.dart';
part 'src/huffman_table_node.dart';
part 'src/huffman_table.dart';

/**
 * Deflates the given bytes.
 */
List<int> deflateBytes(List<int> data) => (new Deflater()).deflate(data);

/**
 * Deflates the given string.
 */
String deflateString(String data) => new String.fromCharCodes((new Deflater()).deflate(data.codeUnits));

/**
 * Inflates the given bytes.
 */
List<int> inflateBytes(List<int> data) => (new Inflater()).inflate(data);

/**
 * Inflates the given string.
 */
String inflateString(String data) => new String.fromCharCodes((new Inflater()).inflate(data.codeUnits));

// TODO: Zlib.
compress() {
  throw new UnimplementedError();
}

decompress() {
  throw new UnimplementedError();
}

// TODO: Gzip.
gzip() {
  throw new UnimplementedError();
}

gunzip() {
  throw new UnimplementedError();
}