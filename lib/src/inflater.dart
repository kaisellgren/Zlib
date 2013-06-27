/*!
 * Zlib
 *
 * Copyright (C) 2012, Kai Sellgren
 * Licensed under the MIT License.
 * http://www.opensource.org/licenses/mit-license.php
 */

part of zlib;

class Inflater {
  // Constant parameters.
  static const WSIZE = 32768; // Sliding Window size.
  static const STORED_BLOCK = 0;
  static const STATIC_TREES = 1;
  static const DYN_TREES = 2;

  // Base options.
  int literalBits = 9; // Bits in base literal/length lookup table.
  int distanceBits = 6; // Bits in base distance lookup table.

  // Generic variables.
  List<int> slide;
  int currentSlidePosition = 0; // Current position in slide.

  // Inflate codes.
  HuffmanTableList fixedLiteralTables;
  HuffmanTableList fixedDistanceTables;
  int fixedBitsByLiteral;
  int fixedBitsByDistance;

  int bitBuffer = 0; // Bit buffer.
  int bitCount = 0; // Bits in bit buffer.
  int method = -1;

  bool eof = false;

  int copyLength = 0;
  int copy_dist = 0;

  HuffmanTableList huffmanTableList = new HuffmanTableList(); // Literal length decoder table.

  HuffmanTableList distanceTables; // Literal distance decoder table.
  int bitsByLiteral; // Number of bits decoded by tl.
  int bitsByDistance; // Number of bits decoded by td.

  List<int> inflateData;
  int currentPosition = 0;

  // Constant tables.
  static const MASK_BITS = const [
    0x0000,
    0x0001, 0x0003, 0x0007, 0x000f, 0x001f, 0x003f, 0x007f, 0x00ff,
    0x01ff, 0x03ff, 0x07ff, 0x0fff, 0x1fff, 0x3fff, 0x7fff, 0xffff];

  // Tables for deflate from PKZIP's appnote.txt.
  static const cplens = const [ // Copy lengths for literal codes 257..285.
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258, 0, 0];

  // Note: see note #13 above about the 258 in this list.
  static const cplext = const [ // Extra bits for literal codes 257..285.
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0, 99, 99]; // 99 == invalid.

  // Copy offsets for distance codes 0..29.
  static const cpdist = const [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
    8193, 12289, 16385, 24577];

  // Extra bits for distance codes.
  static const cpdext = const [
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
    12, 12, 13, 13];

  // Order of the bit length code lengths.
  static const border = const [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

  /**
   * Inflates the given data.
   */
  List<int> inflate(data) {
    var buffer = new List<int>();

    slide = new List(2 * WSIZE);

    inflateData = data;

    // Start the inflation.
    var i = 1;
    while (i > 0) {
      i = inflateInternalEntry(buffer, buffer.length, 1024);
    }

    inflateData = null;

    return buffer;
  }

  /**
   * Returns the next byte in the data.
   *
   * Returns `-1` if we are done.
   */
  int get nextByte {
    if (inflateData.length == currentPosition)
      return -1;

    return inflateData[currentPosition++] & 0xff;
  }

  /**
   * Fetches [amount] of bytes to the bit buffer as needed.
   */
  void fetchBytes(int amount) {
    while (bitCount < amount) {
      bitBuffer |= nextByte << bitCount;
      bitCount += 8;
    }
  }

  /**
   * Gets bits from the bit buffer.
   */
  int getBits(int n) {
    return bitBuffer & MASK_BITS[n];
  }

  /**
   * Throw [amount] of bits.
   */
  void throwBits(int amount) {
    bitBuffer >>= amount;
    bitCount -= amount;
  }

  /**
   * Inflate (decompress) the codes in a deflated (compressed) block.
   *
   * Returns an error code or zero if it all goes ok.
   */
  int inflateCompressedBlockCodes(List<int> buffer, off, int size) {
    var e; // Table entry flag/number of extra bits.
    var t; // (HuffmanTableNode) pointer to table entry.
    var n = 0, bits;

    if (size == 0)
      return 0;

    // Inflate the coded data.
    while (true) {
      fetchBytes(bitsByLiteral);
      bits = getBits(bitsByLiteral);
      t = huffmanTableList.list[bits];
      e = t.e;

      while (e > 16) {
        if (e == 99)
          return -1;

        throwBits(t.b);
        e -= 16;
        fetchBytes(e);
        t = t.t[getBits(e)];
        e = t.e;
      }

      throwBits(t.b);

      // It's a literal.
      if (e == 16) {
        currentSlidePosition &= WSIZE - 1;
        slide[currentSlidePosition] = t.n;
        currentSlidePosition++;
        buffer.add(t.n);
        n++;

        if (n == size)
          return size;

        continue;
      }

      // End of block.
      if (e == 15)
        break;

      // If we got this far, the block is an EOB or a length.

      // Get length of block to copy.
      fetchBytes(e);
      copyLength = t.n + getBits(e);
      throwBits(e);

      // Decode distance of block to copy.
      fetchBytes(bitsByDistance);
      bits = getBits(bitsByDistance);
      t = distanceTables.list[bits];
      e = t.e;

      while (e > 16) {
        if (e == 99)
          return -1;

        throwBits(t.b);
        e -= 16;
        fetchBytes(e);
        t = t.t[getBits(e)];
        e = t.e;
      }

      throwBits(t.b);
      fetchBytes(e);
      copy_dist = currentSlidePosition - t.n - getBits(e);
      throwBits(e);

      // The actual copying.
      while (copyLength > 0 && n < size) {
        copyLength--;
        copy_dist &= WSIZE - 1;
        currentSlidePosition &= WSIZE - 1;

        slide[currentSlidePosition] = slide[copy_dist];
        buffer.add(slide[currentSlidePosition]);

        n++;
        currentSlidePosition++;
        copy_dist++;
      }

      if (n == size)
        return size;
    }

    method = -1;
    return n;
  }

  /**
   * Decompress an inflated type 0 stored block.
   */
  int inflateStoredBlock(List<int> buffer, off, int size) {
    var n;

    // Go to byte boundary.
    n = bitCount & 7;
    throwBits(n);

    // Get the length and its complement.
    fetchBytes(16);
    n = getBits(16);
    throwBits(16);
    fetchBytes(16);

    // Error in compressed data!
    if (n != ((~bitBuffer) & 0xffff))
      return -1;

    throwBits(16);

    // Read and output the compressed data.
    copyLength = n;

    n = 0;
    while (copyLength > 0 && n < size) {
      copyLength--;
      currentSlidePosition &= WSIZE - 1;
      fetchBytes(8);

      slide[currentSlidePosition] = getBits(8);
      buffer.add(slide[currentSlidePosition]);

      n++;
      currentSlidePosition++;
      throwBits(8);
    }

    if (copyLength == 0)
      method = -1;

    return n;
  }

  /**
   * Decompress an inflated type 1 (fixed Huffman codes) block.  We should either replace this with a custom decoder,
   * or at least pre-compute the Huffman tables.
   */
  int inflateFixedHuffmanCodesBlock(List<int> buffer, off, int size) {
    // If first time, set up tables for fixed blocks.
    if (fixedLiteralTables == null) {
      var i;
      var l = []; // 288 length list for huft_build (initialized below).
      var h; // HuftBuild

      // Literal table.
      for (i = 0; i < 144; i++)
        l[i] = 8;

      for (; i < 256; i++)
        l[i] = 9;

      for (; i < 280; i++)
        l[i] = 7;

      // Make a complete, but wrong code set.
      for (; i < 288; i++)
        l[i] = 8;

      fixedBitsByLiteral = 7;

      h = new HuffmanTable(l, 288, 257, cplens, cplext, fixedBitsByLiteral);

      if (h.status != 0) {
        print("HufBuild error: ${h.status}!");
        return -1;
      }

      fixedLiteralTables = h.root;
      fixedBitsByLiteral = h.m;

      // Distance table. Make an incomplete code set.
      for (i = 0; i < 30; i++)
        l[i] = 5;

      fixedBitsByDistance = 5;

      h = new HuffmanTable(l, 30, 0, cpdist, cpdext, fixedBitsByDistance);

      if (h.status > 1) {
        fixedLiteralTables = null;
        print("HufBuild error: ${h.status}!");
        return -1;
      }

      fixedDistanceTables = h.root;
      fixedBitsByDistance = h.m;
    }

    huffmanTableList = fixedLiteralTables;
    distanceTables = fixedDistanceTables;
    bitsByLiteral = fixedBitsByLiteral;
    bitsByDistance = fixedBitsByDistance;

    return inflateCompressedBlockCodes(buffer, off, size);
  }

  /**
   * Decompress an inflated type 2 (dynamic Huffman codes) block.
   */
  int inflateDynamicHuffmanCodesBlock(List<int> buffer, off, int size) {
    var i; // temporary variables
    var j;
    var l; // last length
    var n; // number of lengths to get
    var t; // (HuftNode) literal/length code table
    var nb; // number of bit length codes
    var nl; // number of literal/length codes
    var nd; // number of distance codes
    var ll = new List(316);
    var h; // (HuftBuild)

    // Literal/length and distance code lengths.
    for (i = 0; i < 316; i++)
      ll[i] = 0;

    // Read in table lengths.
    fetchBytes(5);
    nl = 257 + getBits(5); // Number of literal/length codes.
    throwBits(5);
    fetchBytes(5);
    nd = 1 + getBits(5); // Number of distance codes.
    throwBits(5);
    fetchBytes(4);
    nb = 4 + getBits(4); // Number of bit length codes.
    throwBits(4);

    // Bad lengths.
    if (nl > 286 || nd > 30)
      return -1;

    // Read in bit-length-code lengths.
    for (j = 0; j < nb; j++) {
      fetchBytes(3);
      ll[border[j]] = getBits(3);
      throwBits(3);
    }

    for (null; j < 19; j++)
      ll[border[j]] = 0;

    // Build decoding table for trees--single level, 7 bit lookup.
    bitsByLiteral = 7;
    h = new HuffmanTable(ll, 19, 19, null, null, bitsByLiteral);

    // Incomplete code set.
    if (h.status != 0)
      return -1;

    huffmanTableList = h.root;
    bitsByLiteral = h.m;

    // Read in literal and distance code lengths.
    n = nl + nd;
    i = l = 0;

    while (i < n) {
      fetchBytes(bitsByLiteral);
      t = huffmanTableList.list[getBits(bitsByLiteral)];
      j = t.b;
      throwBits(j);
      j = t.n;

      // Length of code in bits (0..15).
      if (j < 16) {
        ll[i] = l = j; // Save last length in l.
        i++;
      } else if (j == 16) { // Repeat last length 3 to 6 times.
        fetchBytes(2);
        j = 3 + getBits(2);
        throwBits(2);

        if (i + j > n)
          return -1;

        while (j-- > 0) {
          ll[i] = l;
          i++;
        }
      } else if (j == 17) { // 3 to 10 zero length codes.
        fetchBytes(3);
        j = 3 + getBits(3);
        throwBits(3);

        if (i + j > n)
          return -1;

        while (j-- > 0) {
          ll[i] = 0;
          i++;
        }

        l = 0;
      } else { // j === 18: 11 to 138 zero length codes.
        fetchBytes(7);
        j = 11 + getBits(7);
        throwBits(7);

        if (i + j > n)
          return -1;

        while (j-- > 0) {
          ll[i] = 0;
          i++;
        }

        l = 0;
      }
    }

    // Build the decoding tables for literal/length and distance codes.
    bitsByLiteral = literalBits;
    h = new HuffmanTable(ll, nl, 257, cplens, cplext, bitsByLiteral);

    // No literals or lengths.
    if (bitsByLiteral == 0)
      h.status = 1;

    // Incomplete literal tree.
    if (h.status != 0 && h.status != 1)
      return -1;

    huffmanTableList = h.root;
    bitsByLiteral = h.m;

    for (i = 0; i < nd; i++)
      ll[i] = ll[i + nl];

    bitsByDistance = distanceBits;
    h = new HuffmanTable(ll, nd, 0, cpdist, cpdext, bitsByDistance);
    distanceTables = h.root;
    bitsByDistance = h.m;

    // Lengths but no distances. Incomplete distance tree.
    if (bitsByDistance == 0 && nl > 257)
      return -1;

    if (h.status != 0)
      return -1;

    // Decompress until an end-of-block code.
    return inflateCompressedBlockCodes(buffer, off, size);
  }

  /**
   * Decompress an inflated entry.
   */
  int inflateInternalEntry(List<int> buffer, off, int size) {
    var n = 0, i;

    while (n < size) {
      if (eof && method == -1)
        return n;

      if (copyLength > 0) {
        if (method != STORED_BLOCK) {
          // STATIC_TREES or DYN_TREES
          while (copyLength > 0 && n < size) {
            copyLength--;
            copy_dist &= WSIZE - 1;
            currentSlidePosition &= WSIZE - 1;

            slide[currentSlidePosition] = slide[copy_dist];
            buffer.add(slide[currentSlidePosition]);

            n++;
            currentSlidePosition++;
            copy_dist++;
          }
        } else {
          while (copyLength > 0 && n < size) {
            copyLength--;
            currentSlidePosition &= WSIZE - 1;
            fetchBytes(8);

            slide[currentSlidePosition] = getBits(8);
            buffer.add(slide[currentSlidePosition]);

            n++;
            currentSlidePosition++;
            throwBits(8);
          }

          // We are done.
          if (copyLength == 0)
            method = -1;
        }

        if (n == size)
          return n;
      }

      if (method == -1) {
        if (eof)
          break;

        // Read in last block bit.
        fetchBytes(1);
        if (getBits(1) != 0)
          eof = true;

        throwBits(1);

        // Read in block type.
        fetchBytes(2);
        method = getBits(2);
        throwBits(2);
        huffmanTableList = null;
        copyLength = 0;
      }

      switch (method) {
        case STORED_BLOCK:
          i = inflateStoredBlock(buffer, off + n, size - n);
          break;

        case STATIC_TREES:
          if (huffmanTableList is HuffmanTableList)
            i = inflateCompressedBlockCodes(buffer, off + n, size - n);
          else
            i = inflateFixedHuffmanCodesBlock(buffer, off + n, size - n);

          break;

        case DYN_TREES:
          if (huffmanTableList is HuffmanTableList)
            i = inflateCompressedBlockCodes(buffer, off + n, size - n);
          else
            i = inflateDynamicHuffmanCodesBlock(buffer, off + n, size - n);

          break;

        default: // Houston, we have a problem.
          i = -1;
          break;
      }

      if (i == -1) {
        if (eof)
          return 0;

        return -1;
      }

      n += i;
    }

    return n;
  }
}