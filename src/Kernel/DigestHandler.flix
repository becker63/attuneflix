/// The digest capability handler on its own: the narrow effectful shell for
/// analytical code that needs content addressing and nothing else. Splitting
/// it out of `Kernel.Handler` keeps a digest-only computation off the Grit and
/// Parquet native seams, and gives the SHA-256 primitive exactly one owner
/// (`Kernel.Handler` delegates its own `Digest` clause here).
pub mod Kernel.DigestHandler {
    import attune.identity.AttuneIdentity

    /// The SHA-256 primitive this capability is a door to. Payload construction
    /// and protocol versioning stay in Flix, above this seam.
    pub def hash(payload: String): String \ IO = AttuneIdentity.sha256(payload)

    /// Handle only `Digest`, bridging it to the native identity seam.
    pub def runDigest(computation: Unit -> a \ ef): a \ ((ef - Kernel.Effect.Digest) + IO) =
        run {
            computation()
        } with handler Kernel.Effect.Digest {
            def digest(payload, resume) = resume(hash(payload))
        }
}
