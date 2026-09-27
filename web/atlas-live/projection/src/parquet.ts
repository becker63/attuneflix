/**
 * A minimal Parquet writer for the synthetic stress fixture.
 *
 * The viewer's bundled worlds are Parquet written by the Java/Arrow seam; the
 * synthetic fixture must be the SAME projection input format (metadata /
 * entities / relations / locations Parquet) so it flows through the identical
 * `projectWorld` path, with no reader special-case. Rather than add a Parquet
 * writer dependency, this module emits the smallest file `hyparquet` reads:
 *
 * - one row group, one data page per column;
 * - PLAIN encoding, UNCOMPRESSED codec, Data Page V1;
 * - flat REQUIRED or OPTIONAL columns (definition levels RLE-encoded, no
 *   repetition levels, no dictionary, no statistics).
 *
 * It is deliberately not a general writer: it exists only for the synthetic
 * fixture, and `//web/atlas-live/projection:data` re-decodes and re-projects the
 * fixture at build time, so any incompatibility fails the build loudly.
 */

const PARQUET_INT32 = 1;
const PARQUET_BYTE_ARRAY = 6;
const REPETITION_REQUIRED = 0;
const REPETITION_OPTIONAL = 1;
const CONVERTED_UTF8 = 0;
const ENCODING_PLAIN = 0;
const ENCODING_RLE = 3;
const CODEC_UNCOMPRESSED = 0;
const PAGE_DATA = 0;

const T_I32 = 5;
const T_I64 = 6;
const T_BINARY = 8;
const T_LIST = 9;
const T_STRUCT = 12;

const textEncoder = new TextEncoder();

/** Thrift zigzag for a 32-bit integer (i32 fields). */
function zigzag32(value: number): bigint {
  const v = BigInt(value);
  return v >= 0n ? v * 2n : -v * 2n - 1n;
}

export type ParquetKind = "int32" | "string";

export interface ParquetColumn {
  readonly name: string;
  readonly kind: ParquetKind;
  /** OPTIONAL when true (definition levels written); REQUIRED otherwise. */
  readonly nullable?: boolean;
  /** One entry per row; a null marks a missing OPTIONAL value. */
  readonly values: ReadonlyArray<number | string | null>;
}

/** Thrift compact-protocol writer, limited to the Parquet metadata structures. */
class Compact {
  private readonly out: number[] = [];
  private lastId = 0;

  byte(value: number): void {
    this.out.push(value & 0xff);
  }

  raw(bytes: Uint8Array): void {
    for (const byte of bytes) this.out.push(byte & 0xff);
  }

  /** Unsigned LEB128 varint. */
  varint(value: number | bigint): void {
    let rest = typeof value === "bigint" ? value : BigInt(Math.trunc(value));
    while (rest >= 0x80n) {
      this.byte(Number(rest & 0x7fn) | 0x80);
      rest >>= 7n;
    }
    this.byte(Number(rest));
  }

  private zigzag(value: number): bigint {
    return zigzag32(value);
  }

  private fieldHeader(type: number, id: number): void {
    const delta = id - this.lastId;
    if (delta >= 1 && delta <= 15) {
      this.byte((delta << 4) | type);
    } else {
      this.byte(type);
      this.varint(this.zigzag(id));
    }
    this.lastId = id;
  }

  i32(id: number, value: number): void {
    this.fieldHeader(T_I32, id);
    this.varint(this.zigzag(value));
  }

  i64(id: number, value: number): void {
    this.fieldHeader(T_I64, id);
    this.varint(this.zigzag(value));
  }

  binary(id: number, value: string): void {
    this.fieldHeader(T_BINARY, id);
    const bytes = textEncoder.encode(value);
    this.varint(bytes.length);
    this.raw(bytes);
  }

  listHeader(id: number, elementType: number, size: number): void {
    this.fieldHeader(T_LIST, id);
    if (size < 15) this.byte((size << 4) | elementType);
    else {
      this.byte(0xf0 | elementType);
      this.varint(size);
    }
  }

  list(id: number, elementType: number, size: number, write: (writer: Compact) => void): void {
    this.listHeader(id, elementType, size);
    write(this);
  }

  /** A list whose elements are STRUCTs: field ids restart for each element. */
  listStructs(id: number, size: number, writeElement: (writer: Compact, index: number) => void): void {
    this.listHeader(id, T_STRUCT, size);
    const outer = this.lastId;
    for (let index = 0; index < size; index++) {
      this.lastId = 0;
      writeElement(this, index);
      this.byte(0); // element STOP
    }
    this.lastId = outer;
  }

  struct(id: number, write: (writer: Compact) => void): void {
    this.fieldHeader(T_STRUCT, id);
    const outer = this.lastId;
    this.lastId = 0;
    write(this);
    this.byte(0); // struct STOP
    this.lastId = outer;
  }

  stop(): void {
    this.byte(0);
  }

  bytes(): Uint8Array {
    return Uint8Array.from(this.out);
  }
}

function concat(chunks: readonly Uint8Array[]): Uint8Array {
  let total = 0;
  for (const chunk of chunks) total += chunk.length;
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

function uint32le(value: number): Uint8Array {
  const bytes = new Uint8Array(4);
  new DataView(bytes.buffer).setUint32(0, value, true);
  return bytes;
}

/** RLE/bit-packed hybrid for definition levels, with the V1 4-byte length prefix. */
function encodeDefinitionLevels(levels: readonly number[], bitWidth: number): Uint8Array {
  const runs: Uint8Array[] = [];
  let index = 0;
  while (index < levels.length) {
    const level = levels[index] ?? 0;
    let end = index;
    while (end < levels.length && levels[end] === level) end++;
    const run = new Compact();
    run.varint((end - index) * 2); // RLE header: count << 1
    const width = (bitWidth + 7) >> 3;
    for (let byte = 0; byte < width; byte++) run.byte((level >> (8 * byte)) & 0xff);
    runs.push(run.bytes());
    index = end;
  }
  const payload = concat(runs);
  return concat([uint32le(payload.length), payload]);
}

function plainValues(column: ParquetColumn): Uint8Array {
  if (column.kind === "string") {
    const parts: Uint8Array[] = [];
    for (const value of column.values) {
      if (value === null) continue;
      if (typeof value !== "string") throw new Error(`string column ${column.name} has a non-string value`);
      const bytes = textEncoder.encode(value);
      parts.push(uint32le(bytes.length), bytes);
    }
    return concat(parts);
  }
  const numbers: number[] = [];
  for (const value of column.values) {
    if (value === null) continue;
    if (typeof value !== "number") throw new Error(`int32 column ${column.name} has a non-number value`);
    numbers.push(value);
  }
  const out = new Uint8Array(numbers.length * 4);
  const view = new DataView(out.buffer);
  for (let i = 0; i < numbers.length; i++) view.setInt32(i * 4, numbers[i] ?? 0, true);
  return out;
}

function buildChunk(column: ParquetColumn, numRows: number): Uint8Array {
  const parts: Uint8Array[] = [];
  if (column.nullable === true) {
    const levels = column.values.map((value) => (value === null ? 0 : 1));
    parts.push(encodeDefinitionLevels(levels, 1));
  }
  parts.push(plainValues(column));
  const pageData = concat(parts);

  const header = new Compact();
  header.i32(1, PAGE_DATA);
  header.i32(2, pageData.length);
  header.i32(3, pageData.length);
  header.struct(5, (writer) => {
    writer.i32(1, numRows);
    writer.i32(2, ENCODING_PLAIN);
    writer.i32(3, ENCODING_RLE);
    writer.i32(4, ENCODING_RLE);
  });
  header.stop(); // PageHeader STOP
  return concat([header.bytes(), pageData]);
}

function parquetType(column: ParquetColumn): number {
  return column.kind === "string" ? PARQUET_BYTE_ARRAY : PARQUET_INT32;
}

/** Serializes `columns` as one Parquet file (all columns share the row count). */
export function writeParquet(columns: readonly ParquetColumn[]): Uint8Array {
  const first = columns[0];
  if (first === undefined) throw new Error("writeParquet requires at least one column");
  const numRows = first.values.length;
  for (const column of columns) {
    if (column.values.length !== numRows) {
      throw new Error(`column ${column.name} has ${column.values.length} values, expected ${numRows}`);
    }
  }

  const chunks = columns.map((column) => buildChunk(column, numRows));
  const magic = textEncoder.encode("PAR1");
  const offsets: number[] = [];
  let position = magic.length;
  for (const chunk of chunks) {
    offsets.push(position);
    position += chunk.length;
  }
  const body = concat([magic, ...chunks]);

  const footer = new Compact();
  footer.i32(1, 2); // FileMetaData.version
  footer.listStructs(2, columns.length + 1, (writer, index) => {
    if (index === 0) {
      writer.binary(4, "schema");
      writer.i32(5, columns.length);
      return;
    }
    const column = columns[index - 1];
    if (column === undefined) throw new Error(`missing schema column ${index}`);
    writer.i32(1, parquetType(column));
    writer.i32(3, column.nullable === true ? REPETITION_OPTIONAL : REPETITION_REQUIRED);
    writer.binary(4, column.name);
    if (column.kind === "string") writer.i32(6, CONVERTED_UTF8);
  });
  footer.i64(3, numRows);

  let totalBytes = 0;
  for (const chunk of chunks) totalBytes += chunk.length;
  footer.listStructs(4, 1, (rowGroup) => {
    rowGroup.listStructs(1, columns.length, (columnChunk, index) => {
      const column = columns[index];
      const chunk = chunks[index];
      const offset = offsets[index];
      if (column === undefined || chunk === undefined || offset === undefined) {
        throw new Error(`missing column chunk ${index}`);
      }
      columnChunk.i64(2, offset); // ColumnChunk.file_offset
      columnChunk.struct(3, (meta) => {
        meta.i32(1, parquetType(column));
        meta.list(2, T_I32, 2, (list) => {
          list.varint(zigzag32(ENCODING_PLAIN));
          list.varint(zigzag32(ENCODING_RLE));
        });
        meta.list(3, T_BINARY, 1, (list) => {
          const bytes = textEncoder.encode(column.name);
          list.varint(bytes.length);
          list.raw(bytes);
        });
        meta.i32(4, CODEC_UNCOMPRESSED);
        meta.i64(5, numRows);
        meta.i64(6, chunk.length);
        meta.i64(7, chunk.length);
        meta.i64(9, offset); // data_page_offset
      });
    });
    rowGroup.i64(2, totalBytes);
    rowGroup.i64(3, numRows);
  });
  footer.stop();
  const footerBytes = footer.bytes();

  return concat([body, footerBytes, uint32le(footerBytes.length), magic]);
}
