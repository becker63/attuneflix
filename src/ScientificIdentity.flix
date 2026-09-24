/// Stable scientific identities. Payload construction and versioning stay in
/// Flix; the JDK seam supplies only the SHA-256 primitive.
pub mod ScientificIdentity {
    import attune.identity.AttuneIdentity

    pub def sha256(payload: String): String \ IO =
        AttuneIdentity.sha256(payload)

    pub def versioned(protocol: String, payload: String): String \ IO =
        "${protocol}:${sha256(payload)}"
}
