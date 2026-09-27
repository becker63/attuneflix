/**
 * Self-hosted DuckDB-Wasm. Cosmograph requires DuckDB, but we never let it fetch
 * a bundle from a CDN: we build our own `AsyncDuckDB` from the locally bundled
 * exception-handling (eh) worker and wasm, turn extension autoload OFF, and pass
 * the connection to the renderer through `duckDBConnection`.
 *
 * Only the eh bundle ships; every evergreen browser supports Wasm exceptions.
 */
import * as duckdb from "@duckdb/duckdb-wasm";
import ehWorker from "@duckdb/duckdb-wasm/dist/duckdb-browser-eh.worker.js?url";
import ehWasm from "@duckdb/duckdb-wasm/dist/duckdb-eh.wasm?url";

export interface LocalDuckDB {
  readonly duckdb: duckdb.AsyncDuckDB;
  readonly connection: duckdb.AsyncDuckDBConnection;
}

export async function createLocalDuckDB(): Promise<LocalDuckDB> {
  const db = new duckdb.AsyncDuckDB(new duckdb.VoidLogger(), new Worker(ehWorker));
  await db.instantiate(ehWasm);
  const connection = await db.connect();
  // No CDN, no extension download: the graph is plain Arrow tables, never Parquet.
  await connection.query("SET autoinstall_known_extensions = false");
  await connection.query("SET autoload_known_extensions = false");
  return { duckdb: db, connection };
}
