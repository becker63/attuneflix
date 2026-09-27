import { projectTables, type FileHashes, type ViewerGraph } from "./graph.ts";
import { sha256Hex } from "./sha256.ts";
import { decodeWorldFiles, type WorldFiles } from "./tables.ts";

/**
 * Hashes and decodes one world's Parquet bytes, then projects them into a
 * ViewerGraph. Deterministic: identical input bytes produce an identical graph.
 */
export async function projectWorld(files: WorldFiles): Promise<ViewerGraph> {
  const hashes: Promise<FileHashes> = (async () => {
    const [metadata, entities, relations, locations] = await Promise.all([
      sha256Hex(files.metadata),
      sha256Hex(files.entities),
      sha256Hex(files.relations),
      files.locations === undefined ? Promise.resolve(undefined) : sha256Hex(files.locations),
    ]);
    const result: { metadata: string; entities: string; relations: string; locations?: string } = {
      metadata,
      entities,
      relations,
    };
    if (locations !== undefined) result.locations = locations;
    return result;
  })();
  const [tables, fileSha256] = await Promise.all([decodeWorldFiles(files), hashes]);
  return projectTables(tables, fileSha256);
}
