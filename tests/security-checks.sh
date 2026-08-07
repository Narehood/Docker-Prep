#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

for script in install.sh Scripts/*.sh tests/*.sh tools/*.sh; do
    bash -n "$script"
done

if [[ ! -f Scripts/.checksums.sha256 ]]; then
    echo "Missing Scripts/.checksums.sha256" >&2
    exit 1
fi

(
    cd Scripts
    shopt -s nullglob
    for script in *.sh; do
        # Match a complete sha256sum line: <64-hex><two spaces><filename>
        escaped_script=$(printf '%s' "$script" | sed 's/[][^$.*+?(){}|\\]/\\&/g')
        if ! grep -Eq "^[a-f0-9]{64}  ${escaped_script}$" .checksums.sha256; then
            echo "Scripts/.checksums.sha256 is missing an entry for $script" >&2
            exit 1
        fi
    done
    sha256sum --check --strict .checksums.sha256
)

if rg -n 'curl[^|]*\|[[:space:]]*(ba)?sh' --glob '*.sh' .; then
    echo "Direct curl-to-shell execution is forbidden." >&2
    exit 1
fi

if ! grep -q 'DOCKER_PREP_EPHEMERAL' install.sh; then
    echo "install.sh must honor DOCKER_PREP_EPHEMERAL." >&2
    exit 1
fi

if ! grep -q 'DOCKER_PREP_REVISION' install.sh; then
    echo "install.sh must honor DOCKER_PREP_REVISION." >&2
    exit 1
fi

if ! grep -q 'is_ephemeral' install.sh; then
    echo "install.sh must define is_ephemeral for pinned launches." >&2
    exit 1
fi

if ! grep -q 'verify_script_checksum' install.sh; then
    echo "install.sh must verify Scripts checksums before execution." >&2
    exit 1
fi

if ! grep -Eq '^VERSION="2\.[0-9]+\.[0-9]+"' install.sh; then
    echo "install.sh must define a semver VERSION string." >&2
    exit 1
fi

if ! grep -q 'install_docker_alpine' install.sh; then
    echo "install.sh must provide an Alpine apk Docker install path." >&2
    exit 1
fi

if ! grep -q 'apk add docker docker-cli-compose' install.sh; then
    echo "install.sh Alpine path must install docker and docker-cli-compose via apk." >&2
    exit 1
fi

if rg -n 'git clean[[:space:]]+-[^[:space:]]*f' install.sh; then
    echo "Broad destructive git clean is forbidden." >&2
    exit 1
fi

if rg -n 'portainer/portainer-ce:latest' Scripts/*.sh; then
    echo "Portainer image must not use the bare :latest tag." >&2
    exit 1
fi

echo "Security checks passed."
