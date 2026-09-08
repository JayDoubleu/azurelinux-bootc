#!/usr/bin/env bash
# Split the built image into package-aligned layers.
# Input:  IMAGE_NAME:build, from 10-build-image.sh
# Output: IMAGE_NAME:IMAGE_TAG in the image store, and the OCI directory out/chunked
#
# podman build puts every package into one layer, so an update of one package downloads the
# whole layer. `rpm-ostree compose build-chunked-oci` reads the rpm database in the image and
# groups the files by package into up to MAX_LAYERS layers. The OCI directory stays between
# builds: rpm-ostree reads the previous manifest from it and keeps the layer boundaries stable,
# so a package that did not change keeps its layer digest and is not downloaded again.
#
# The step runs inside the built image itself, which carries rpm-ostree. The image root is
# mounted read-only at /rootfs with a podman image mount, so the copy has no container
# run-time files such as /etc/hosts or /run/.containerenv.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

build_ref="${IMAGE_NAME}:${BUILD_TAG}"
final_ref="localhost/${IMAGE_NAME}:${IMAGE_TAG}"
mkdir -p "$CHUNKED_DIR/blobs/sha256" "$CHUNK_TMP_DIR"
# rpm-ostree opens the output directory to read the previous manifest. It needs a valid OCI
# layout even on the first run, so seed an empty one.
if [ ! -f "$CHUNKED_DIR/index.json" ]; then
  echo '{"imageLayoutVersion": "1.0.0"}' > "$CHUNKED_DIR/oci-layout"
  echo '{"schemaVersion": 2, "manifests": []}' > "$CHUNKED_DIR/index.json"
fi

# build-chunked-oci --rootfs starts from an empty image config, so carry the labels over.
label_args=()
# shellcheck disable=SC2016  # the template is expanded by podman
while IFS= read -r kv; do
  [ -n "$kv" ] && label_args+=(-l "$kv")
done < <(host podman inspect --format '{{range $k, $v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' "$build_ref")

# The image policy rejects every source except the registry, so rpm-ostree would refuse its own
# output directory. The chunk container gets a permissive policy instead.
printf '{"default": [{"type": "insecureAcceptAnything"}]}\n' > "$OUT_DIR/chunk-policy.json"

log "chunking ${build_ref} into ${CHUNKED_DIR} (max ${MAX_LAYERS} layers)"
# --privileged keeps rpm-ostree from re-running itself in a nested user namespace.
host podman run --rm --privileged \
  --mount "type=image,src=${build_ref},dst=/rootfs" \
  -v "${CHUNKED_DIR}:/output" \
  -v "${CHUNK_TMP_DIR}:/var/tmp" \
  -v "${OUT_DIR}/chunk-policy.json:/etc/containers/policy.json:ro" \
  "$build_ref" \
  rpm-ostree compose build-chunked-oci --bootc --format-version=1 \
    --max-layers "$MAX_LAYERS" "${label_args[@]}" \
    --rootfs /rootfs --output "oci:/output:${IMAGE_TAG}" 2>&1 | tee "$LOG_DIR/chunk.log"

log "importing the chunked image as ${final_ref}"
host skopeo copy -q "oci:${CHUNKED_DIR}:${IMAGE_TAG}" "containers-storage:${final_ref}"
layers="$(host podman inspect --format '{{len .RootFS.Layers}}' "$final_ref")"
log "lint of the chunked image"
host podman run --rm "$final_ref" bootc container lint 2>&1 | tail -n 3
log "chunked image ${final_ref} has ${layers} layers"
