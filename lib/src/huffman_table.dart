/*!
 * Zlib
 *
 * Copyright (C) 2012, Kai Sellgren
 * Licensed under the MIT License.
 * http://www.opensource.org/licenses/mit-license.php
 */

part of zlib;

/**
 * Represents the Huffman table.
 */
class HuffmanTable {
  final BMAX = 16; // Maximum bit length of any code.
  final N_MAX = 288; // Maximum number of codes in any set.
  var status;
  HuffmanTableList root;
  var m;

  /**
   * * [b] code lengths in bits (all assumed <= BMAX)
   * * [n] number of codes (assumed <= N_MAX)
   * * [s] number of simple-valued codes (0..s-1)
   * * [d] list of base values for non-simple codes
   * * [e] list of extra bits for non-simple codes
   * * [mm] maximum lookup bits
   */
  HuffmanTable(b, n, s, d, e, mm) {
    this.status = 0; // 0: success, 1: incomplete table, 2: bad input
    this.root = null; // (HuftList) starting table
    this.m = 0; // maximum lookup bits, returns actual

    /* Given a list of code lengths and a maximum table size, make a set of
       tables to decode that set of codes. Return zero on success, one if
       the given code set is incomplete (the tables are still built in this
       case), two if the input is invalid (all zero length codes or an
       oversubscribed set of lengths), and three if not enough memory.
       The code with value 256 is special, and the tables are constructed
       so that no bits beyond that code are fetched when that code is
       decoded. */
    var a; // counter for codes of length k
    var c = new List(this.BMAX + 1);
    var el; // length of EOB code (value 256)
    var f; // i repeats in table every f entries
    var g; // maximum code length
    var h; // table level
    var i; // counter, current code
    var j; // counter
    var k; // number of bits in current code
    var lx = new List(this.BMAX + 1);
    var p; // pointer into c[], b[], or v[]
    var pidx; // index of p
    var q; // (HuftNode) points to current table
    var r = new HuffmanTableNode(); // table entry for structure assignment
    var u = new List(this.BMAX);
    var v = new List(this.N_MAX);
    var w;
    var x = new List(this.BMAX + 1);
    var xp; // pointer into x or c
    var y; // number of dummy codes added
    var z; // number of entries in current table
    var o;
    var tail; // (HuftList)

    tail = this.root = null;

    // bit length count table
    for (i = 0; i < this.BMAX + 1; i++) {
      c[i] = 0;
    }

    // stack of bits per table
    for (i = 0; i < this.BMAX + 1; i++) {
      lx[i] = 0;
    }

    // HuftNode[BMAX][]  table stack
    for (i = 0; i < this.BMAX; i++) {
      u[i] = null;
    }

    // values in order of bit length
    for (i = 0; i < this.N_MAX; i++) {
      v[i] = 0;
    }

    // bit offsets, then code stack
    for (i = 0; i < this.BMAX + 1; i++) {
      x[i] = 0;
    }

    // Generate counts for each bit length
    el = n > 256 ? b[256] : this.BMAX; // set length of EOB code, if any
    p = b; pidx = 0;
    i = n;
    do {
      c[p[pidx]]++; // assume all entries <= BMAX
      pidx++;
    } while (--i > 0);

    if (c[0] == n) { // null input--all zero length codes
      this.root = null;
      this.m = 0;
      this.status = 0;
      return;
    }

    // Find minimum and maximum length, bound *m by those
    for (j = 1; j <= this.BMAX; j++) {
      if (c[j] != 0) {
        break;
      }
    }

    k = j; // minimum code length
    if (mm < j) {
      mm = j;
    }

    for (i = this.BMAX; i != 0; i--) {
      if (c[i] != 0) {
        break;
      }
    }

    g = i; // maximum code length
    if (mm > i) {
      mm = i;
    }

    // Adjust last length count to fill out codes, if needed
    for (y = 1 << j; j < i; j++, y <<= 1) {
      if ((y -= c[j]) < 0) {
        this.status = 2; // bad input: more codes than bits
        this.m = mm;
        return;
      }
    }

    if ((y -= c[i]) < 0) {
      this.status = 2;
      this.m = mm;
      return;
    }
    c[i] += y;

    // Generate starting offsets into the value table for each length
    x[1] = j = 0;
    p = c;
    pidx = 1;
    xp = 2;
    while (--i > 0) { // note that i == g from above
      x[xp++] = (j += p[pidx++]);
    }

    // Make a table of values in order of bit lengths
    p = b; pidx = 0;
    i = 0;
    do {
      if ((j = p[pidx++]) != 0) {
        v[x[j]++] = i;
      }
    } while (++i < n);
    n = x[g]; // set n to length of v

    // Generate the Huffman codes and for each, make the table entries
    x[0] = i = 0; // first Huffman code is zero
    p = v; pidx = 0; // grab values in bit order
    h = -1; // no tables yet--level -1
    w = lx[0] = 0; // no bits decoded yet
    q = null; // ditto
    z = 0; // ditto

    // go through the bit lengths (k already is bits in shortest code)
    for (null; k <= g; k++) {
      a = c[k];
      while (a-- > 0) {
        // here i is the Huffman code of length k bits for value p[pidx]
        // make tables up to required level
        while (k > w + lx[1 + h]) {
          w += lx[1 + h]; // add bits already decoded
          h++;

          // compute minimum size table less than or equal to *m bits
          z = (z = g - w) > mm ? mm : z; // upper limit
          if ((f = 1 << (j = k - w)) > a + 1) { // try a k-w bit table
            // too few codes for k-w bit table
            f -= a + 1; // deduct codes from patterns left
            xp = k;
            while (++j < z) { // try smaller tables up to z bits
              if ((f <<= 1) <= c[++xp]) {
                break; // enough codes to use up j bits
              }
              f -= c[xp]; // else deduct codes from patterns
            }
          }

          if (w + j > el && w < el) {
            j = el - w; // make EOB code end at table
          }

          z = 1 << j; // table entries for j-bit table
          lx[1 + h] = j; // set table size in stack

          // allocate and link in new table
          q = new List(z);
          for (o = 0; o < z; o++) {
            q[o] = new HuffmanTableNode();
          }

          if (tail == null) {
            tail = this.root = new HuffmanTableList();
          } else {
            tail = tail.next = new HuffmanTableList();
          }
          tail.next = null;
          tail.list = q;
          u[h] = q; // table starts after link

          /* connect to last table, if there is one */
          if (h > 0) {
            x[h] = i; // save pattern for backing up
            r.b = lx[h]; // bits to dump before this table
            r.e = 16 + j; // bits in this table
            r.t = q; // pointer to this table
            j = (i & ((1 << w) - 1)) >> (w - lx[h]);
            u[h - 1][j].e = r.e;
            u[h - 1][j].b = r.b;
            u[h - 1][j].n = r.n;
            u[h - 1][j].t = r.t;
          }
        }

        // set up table entry in r
        r.b = k - w;
        if (pidx >= n) {
          r.e = 99; // out of values--invalid code
        } else if (p[pidx] < s) {
          r.e = (p[pidx] < 256 ? 16 : 15); // 256 is end-of-block code
          r.n = p[pidx++]; // simple code is just the value
        } else {
          r.e = e[p[pidx] - s]; // non-simple--look up in lists
          r.n = d[p[pidx++] - s];
        }

        // fill code-like entries with r //
        f = 1 << (k - w);
        for (j = i >> w; j < z; j += f) {
          q[j].e = r.e;
          q[j].b = r.b;
          q[j].n = r.n;
          q[j].t = r.t;
        }

        // backwards increment the k-bit code i
        for (j = 1 << (k - 1); (i & j) != 0; j >>= 1) {
          i ^= j;
        }
        i ^= j;

        // backup over finished tables
        while ((i & ((1 << w) - 1)) != x[h]) {
          w -= lx[h]; // don't need to update q
          h--;
        }
      }
    }

    /* return actual size of base table */
    this.m = lx[1];

    /* Return true (1) if we were given an incomplete table */
    this.status = ((y != 0 && g != 1) ? 1 : 0);
  }
}