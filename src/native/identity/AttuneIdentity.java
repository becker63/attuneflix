package attune.identity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/** JDK cryptographic primitive; Flix owns every identity payload and version. */
public final class AttuneIdentity {
    private AttuneIdentity() {}

    public static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException impossible) {
            throw new AssertionError("JDK has no SHA-256", impossible);
        }
    }
}
