/*!
 * Zlib
 *
 * Copyright (C) 2012, Kai Sellgren
 * Licensed under the MIT License.
 * http://www.opensource.org/licenses/mit-license.php
 */

part of zlib;

class HuffmanTableNode {
  var e = 0; // Number of extra bits or operation.
  var b = 0; // Number of bits in this code or sub-code.

  // Union.
  var n = 0; // Literal, length base, or distance base.
  var t; // (HuffmanTableNode) pointer to next level of table.
}