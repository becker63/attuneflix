package attune.identity;

public final class AttuneIdentityTest {
    private AttuneIdentityTest() {}

    public static void main(String[] args) {
        String actual = AttuneIdentity.sha256("abc");
        String expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        if (!expected.equals(actual)) throw new AssertionError("wrong SHA-256: " + actual);
    }
}
