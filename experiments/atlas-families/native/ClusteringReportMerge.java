package attune.families;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/** Joins independently derived per-world clustering reports without changing their rows. */
public final class ClusteringReportMerge {
  private static final List<String> HEADINGS =
      List.of(
          "**Families**",
          "**Affinity sources** (per member, weighted; ablations count members whose family changes)",
          "**Rollup**",
          "**Largest families**");

  private ClusteringReportMerge() {}

  public static void main(String[] args) throws Exception {
    if (args.length < 2) {
      throw new IllegalArgumentException("expected world reports followed by the output path");
    }
    List<List<Section>> worlds = new ArrayList<>();
    for (int i = 0; i < args.length - 1; i++) {
      worlds.add(parse(Files.readString(Path.of(args[i]), StandardCharsets.UTF_8)));
    }
    StringBuilder merged = new StringBuilder();
    for (int section = 0; section < HEADINGS.size(); section++) {
      Section first = worlds.get(0).get(section);
      if (section > 0) {
        merged.append("\n\n");
      }
      merged.append(HEADINGS.get(section)).append("\n\n");
      merged.append(first.header()).append('\n').append(first.separator());
      for (List<Section> world : worlds) {
        Section current = world.get(section);
        if (!first.header().equals(current.header())
            || !first.separator().equals(current.separator())) {
          throw new IllegalArgumentException("clustering report table schemas differ");
        }
        for (String row : current.rows()) {
          merged.append('\n').append(row);
        }
      }
    }
    merged.append('\n');
    Files.writeString(Path.of(args[args.length - 1]), merged.toString(), StandardCharsets.UTF_8);
  }

  private static List<Section> parse(String report) {
    List<String> lines = List.of(report.split("\n", -1));
    List<Section> result = new ArrayList<>();
    int position = 0;
    for (int index = 0; index < HEADINGS.size(); index++) {
      if (position >= lines.size() || !HEADINGS.get(index).equals(lines.get(position))) {
        throw new IllegalArgumentException("missing or out-of-order section " + HEADINGS.get(index));
      }
      position++;
      while (position < lines.size() && lines.get(position).isEmpty()) {
        position++;
      }
      if (position + 1 >= lines.size()) {
        throw new IllegalArgumentException("missing table header in " + HEADINGS.get(index));
      }
      String header = lines.get(position++);
      String separator = lines.get(position++);
      if (!header.startsWith("|") || !separator.startsWith("|---")) {
        throw new IllegalArgumentException("malformed table in " + HEADINGS.get(index));
      }
      List<String> rows = new ArrayList<>();
      while (position < lines.size() && !lines.get(position).isEmpty()) {
        rows.add(lines.get(position++));
      }
      if (rows.isEmpty()) {
        throw new IllegalArgumentException("empty world table in " + HEADINGS.get(index));
      }
      while (position < lines.size() && lines.get(position).isEmpty()) {
        position++;
      }
      result.add(new Section(header, separator, rows));
    }
    if (position != lines.size()) {
      throw new IllegalArgumentException("unexpected trailing clustering report content");
    }
    return result;
  }

  private record Section(String header, String separator, List<String> rows) {}
}
