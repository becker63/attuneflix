package attune.families;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/** Packs declared evidence inputs into one deterministic, content-addressed Bazel output. */
public final class EvidenceArchive {
  private static final Pattern ADDRESS = Pattern.compile(
      "\\{\\\"protocol\\\":\\\"atlas-families-evidence-address-v1\\\","
          + "\\\"snapshot_digest\\\":\\\"([0-9a-f]{64})\\\","
          + "\\\"sha256\\\":\\\"([0-9a-f]{64})\\\","
          + "\\\"size_bytes\\\":([1-9][0-9]*)\\}");

  private EvidenceArchive() {}

  public static void main(String[] args) throws Exception {
    if (args.length == 4 && args[0].equals("--describe")) {
      describe(args[1], Path.of(args[2]), Path.of(args[3]));
      return;
    }
    List<String> arguments = expandArguments(args);
    if (!arguments.isEmpty() && arguments.getFirst().equals("--index")) {
      index(arguments);
      return;
    }
    if (arguments.size() < 3 || arguments.size() % 2 != 1) {
      throw new IllegalArgumentException("expected output followed by archive-name/input-path pairs");
    }
    Path output = Path.of(arguments.getFirst());
    Files.createDirectories(output.getParent());
    Set<String> names = new HashSet<>();
    String previous = "";
    try (ZipOutputStream archive = new ZipOutputStream(
        new BufferedOutputStream(Files.newOutputStream(output)))) {
      archive.setLevel(9);
      for (int index = 1; index < arguments.size(); index += 2) {
        String name = arguments.get(index);
        Path input = Path.of(arguments.get(index + 1));
        if (!name.startsWith(".attune/") || name.startsWith("/") || name.contains("..")
            || !names.add(name) || name.compareTo(previous) <= 0) {
          throw new IllegalArgumentException("unsafe or unsorted evidence archive entry: " + name);
        }
        if (!Files.isRegularFile(input)) {
          throw new IllegalArgumentException("missing declared evidence input: " + input);
        }
        ZipEntry entry = new ZipEntry(name);
        entry.setTime(0L);
        archive.putNextEntry(entry);
        try (BufferedInputStream source = new BufferedInputStream(Files.newInputStream(input))) {
          source.transferTo(archive);
        }
        archive.closeEntry();
        previous = name;
      }
    }
  }

  private static void describe(String digest, Path input, Path output) throws Exception {
    if (!digest.matches("[0-9a-f]{64}")) {
      throw new IllegalArgumentException("invalid snapshot digest");
    }
    MessageDigest sha256 = MessageDigest.getInstance("SHA-256");
    try (BufferedInputStream source = new BufferedInputStream(Files.newInputStream(input))) {
      byte[] buffer = new byte[131072];
      for (int length; (length = source.read(buffer)) != -1; ) {
        sha256.update(buffer, 0, length);
      }
    }
    String hash = HexFormat.of().formatHex(sha256.digest());
    String json = "{\"protocol\":\"atlas-families-evidence-address-v1\",\"snapshot_digest\":\""
        + digest + "\",\"sha256\":\"" + hash + "\",\"size_bytes\":" + Files.size(input) + "}\n";
    Files.createDirectories(output.getParent());
    Files.writeString(output, json, StandardCharsets.UTF_8);
  }

  private static void index(List<String> arguments) throws IOException {
    if (arguments.size() < 4 || arguments.size() % 2 != 0) {
      throw new IllegalArgumentException("expected --index output followed by digest/address pairs");
    }
    Path output = Path.of(arguments.get(1));
    StringBuilder json = new StringBuilder(
        "{\"protocol\":\"atlas-families-evidence-cas-index-v1\",\"worlds\":[");
    String previous = "";
    for (int i = 2; i < arguments.size(); i += 2) {
      String digest = arguments.get(i);
      if (!digest.matches("[0-9a-f]{64}") || digest.compareTo(previous) <= 0) {
        throw new IllegalArgumentException("invalid or unsorted evidence digest: " + digest);
      }
      Matcher address = ADDRESS.matcher(
          Files.readString(Path.of(arguments.get(i + 1)), StandardCharsets.UTF_8).trim());
      if (!address.matches() || !address.group(1).equals(digest)) {
        throw new IllegalArgumentException("evidence address disagrees with " + digest);
      }
      if (i > 2) json.append(',');
      json.append("{\"snapshot_digest\":\"").append(digest)
          .append("\",\"sha256\":\"").append(address.group(2))
          .append("\",\"size_bytes\":").append(address.group(3)).append('}');
      previous = digest;
    }
    json.append("]}\n");
    Files.createDirectories(output.getParent());
    Files.writeString(output, json, StandardCharsets.UTF_8);
  }

  private static List<String> expandArguments(String[] args) throws IOException {
    if (args.length == 1 && args[0].startsWith("@")) {
      return Files.readAllLines(Path.of(args[0].substring(1)));
    }
    return new ArrayList<>(List.of(args));
  }
}
