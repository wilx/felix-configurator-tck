#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly FELIX_DIR="${ROOT_DIR}/felix-dev"
readonly TCK_DIR="${ROOT_DIR}/osgi-tck"
readonly MAVEN_BIN="${MAVEN_BIN:-mvn}"

readonly CM_JSON_MAVEN_VERSION="2.0.9-SNAPSHOT"
readonly CM_JSON_OSGI_VERSION="2.0.9.SNAPSHOT"
readonly CONFIGURATOR_MAVEN_VERSION="1.0.19-SNAPSHOT"
readonly CONFIGURATOR_OSGI_VERSION="1.0.19.SNAPSHOT"
readonly JAKARTA_JSON_VERSION="2.0.1"

if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
    echo "JAVA_HOME must point to a JDK 8 installation." >&2
    exit 2
fi

java_version="$("${JAVA_HOME}/bin/java" -version 2>&1 | sed -n '1p')"
if [[ "${java_version}" != *'version "1.8.'* ]]; then
    echo "The OSGi 8.1 TCK workspace requires JDK 8; found: ${java_version}" >&2
    exit 2
fi

if [[ ! -f "${FELIX_DIR}/cm.json/pom.xml" || ! -x "${TCK_DIR}/gradlew" ]]; then
    echo "Submodules are missing. Run: git submodule update --init --recursive" >&2
    exit 2
fi

echo "Building and installing Felix CM JSON ${CM_JSON_MAVEN_VERSION}"
(
    cd "${FELIX_DIR}"
    "${MAVEN_BIN}" -B -V -f cm.json/pom.xml clean install
)

echo "Building and installing Felix Configurator ${CONFIGURATOR_MAVEN_VERSION}"
(
    cd "${FELIX_DIR}"
    "${MAVEN_BIN}" -B -V -f configurator/pom.xml clean install
)

readonly TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/felix-configurator-tck.XXXXXX")"
readonly TCK_WORKTREE="${TEMP_DIR}/osgi-tck"
readonly CONFIGURATOR_REPORT_SOURCE="${TCK_WORKTREE}/org.osgi.test.cases.configurator/generated/test-reports/testOSGi"
readonly CONFIGURATOR_SECURE_REPORT_SOURCE="${TCK_WORKTREE}/org.osgi.test.cases.configurator.secure/generated/test-reports/testOSGi"
readonly REPORT_DESTINATION="${ROOT_DIR}/build/tck-reports"

cleanup() {
    exit_status=$?
    set +e

    if [[ -d "${CONFIGURATOR_REPORT_SOURCE}" || -d "${CONFIGURATOR_SECURE_REPORT_SOURCE}" ]]; then
        rm -rf -- "${REPORT_DESTINATION}"
        mkdir -p -- "${REPORT_DESTINATION}"

        if [[ -d "${CONFIGURATOR_REPORT_SOURCE}" ]]; then
            mkdir -p -- "${REPORT_DESTINATION}/configurator"
            cp -a -- "${CONFIGURATOR_REPORT_SOURCE}/." "${REPORT_DESTINATION}/configurator/"
        fi
        if [[ -d "${CONFIGURATOR_SECURE_REPORT_SOURCE}" ]]; then
            mkdir -p -- "${REPORT_DESTINATION}/configurator-secure"
            cp -a -- "${CONFIGURATOR_SECURE_REPORT_SOURCE}/." "${REPORT_DESTINATION}/configurator-secure/"
        fi

        echo "TCK reports copied to ${REPORT_DESTINATION}"
    fi

    git -C "${TCK_DIR}" worktree remove --force "${TCK_WORKTREE}" >/dev/null 2>&1
    rm -rf -- "${TEMP_DIR}"
    exit "${exit_status}"
}
trap cleanup EXIT

git -C "${TCK_DIR}" worktree add --quiet --detach "${TCK_WORKTREE}" HEAD

# Add the locally installed Felix snapshots and the Jakarta JSON implementation
# required by the current CM JSON bundle to the TCK workspace's Bnd repository.
printf '%s\n' \
    "org.apache.felix:org.apache.felix.cm.json:${CM_JSON_MAVEN_VERSION}" \
    "org.apache.felix:org.apache.felix.configurator:${CONFIGURATOR_MAVEN_VERSION}" \
    "org.glassfish:jakarta.json:${JAKARTA_JSON_VERSION}" \
    >> "${TCK_WORKTREE}/cnf/ext/central.mvn"

implementation_file="${TCK_WORKTREE}/cnf/repo/org.osgi.impl.service.configurator/org.osgi.impl.service.configurator-8.1.0.lib"
sed -i \
    -e "s/^org\.apache\.felix\.cm\.json;version=1\.0\.6$/org.apache.felix.cm.json;version=${CM_JSON_OSGI_VERSION}/" \
    -e "s/^org\.apache\.felix\.configurator; version=1\.0\.14$/org.apache.felix.configurator; version=${CONFIGURATOR_OSGI_VERSION}/" \
    "${implementation_file}"
printf '%s\n' "org.glassfish.jakarta.json; version=${JAKARTA_JSON_VERSION}" >> "${implementation_file}"

# This repository is defunct and none of its indexed bundles are needed here.
: > "${TCK_WORKTREE}/cnf/ext/springsource.mvn"

echo "Running the OSGi Compendium 8.1 Configurator TCK"
(
    cd "${TCK_WORKTREE}"
    ./gradlew \
        :org.osgi.service.cm:jar \
        :org.osgi.service.coordinator:jar \
        :org.osgi.util.converter:jar \
        :org.osgi.test.cases.configurator:testOSGi \
        :org.osgi.test.cases.configurator.secure:testOSGi \
        --no-daemon
)
