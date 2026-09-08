# 0003: Sign images with a sigstore key and ship the policy in the image

Date: 2026-09-08
Status: accepted

## Context

`bootc upgrade` pulls from a registry through the containers-image library. That library reads `/etc/containers/policy.json` and can require a signature per registry scope. Two signature formats exist: simple signing with GPG keys, which needs a separate lookaside server, and sigstore signatures, which the registry stores next to the image as an attachment. The local registry and ghcr.io both take attachments.

The host pushes to `localhost:5000`. The VM pulls the same registry as `10.0.2.2:5000`. A sigstore signature names the image it signs, and the default policy check compares that name with the name being pulled.

## Decision

- Sign with a sigstore key pair. `scripts/22-keys.sh` creates it with `skopeo generate-sigstore-key`. The private key and passphrase live in `out/keys/`. The public key lives in `config/etc/pki/containers/` and goes into the image. Both are out of git; each developer builds with their own key. CI can inject a fixed key from secrets.
- `scripts/25-push.sh` signs with `skopeo copy --sign-by-sigstore-private-key`.
- The image carries `config/etc/containers/policy.json`: `default: reject`, the registry scope requires a signature from the public key, and `containers-storage` is accepted because `bootc install` reads the image from there.
- The policy maps the VM's name for the registry to the signed name with `signedIdentity: exactRepository`.
- `scripts/30-install-disk.sh` passes `--enforce-container-sigpolicy`, so bootc refuses a policy that accepts unsigned images.
- `scripts/55-signature-test.sh` checks both directions on a running VM.

## Consequences

- An unsigned image, or one signed with another key, is refused with "A signature was required, but no signature exists" or a key mismatch.
- The chunk step runs inside the image, and the strict policy would reject its own output directory. `scripts/15-chunk-image.sh` bind-mounts a permissive policy into that container.
- A move to a public registry needs a new scope in the policy and a new `dockerRepository` value, then a `bootc switch` on the VM.
- Losing `out/keys/` means new keys and a fresh install: the installed VM trusts only the old public key.

## Alternatives

- Simple signing with GPG. Needs a lookaside web server that the VM can reach. More parts, no benefit for this loop.
- Signing the ostree commit inside the image (`rpm-ostree compose build-chunked-oci --sign-commit`). Verifies the commit, not the OCI image. bootc verifies OCI images through the containers policy, so the policy route matches the tool.
- `default: insecureAcceptAnything` with one strict scope. Simpler, but `--enforce-container-sigpolicy` refuses it, and any other registry would be trusted.
