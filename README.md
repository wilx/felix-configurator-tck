# Felix Configurator TCK harness

This repository reproduces the OSGi Compendium Release 8.1 Configurator TCK
run for the Apache Felix [`cm-conformance` pull request][felix-pr]. It pins both
inputs as Git submodules:

- `felix-dev` at the pull request head
- `osgi-tck` at the OSGi Compendium 8.1 release tag

The harness builds and tests only the two changed Felix projects, `cm.json` and
`configurator`, installs their bundles into the local Maven repository, and
runs both `org.osgi.test.cases.configurator` and
`org.osgi.test.cases.configurator.secure` with those bundles substituted for
the released implementations. The TCK's released Felix Config Admin
implementation is retained because it is supporting infrastructure, not part
of the change under test.

## Run locally

Requirements: Git, Bash, Maven 3, and JDK 8.

```sh
git clone --recurse-submodules https://github.com/wilx/felix-configurator-tck.git
cd felix-configurator-tck
JAVA_HOME=/path/to/jdk8 ./run-tck.sh
```

Set `MAVEN_BIN` if Maven is not available as `mvn`. Test reports are copied to
`build/tck-reports`. The TCK source is modified only in a temporary Git
worktree; both submodules remain clean.

The workflow under `.github/workflows/tck.yml` provides the same run on GitHub
Actions and can be started manually.

[felix-pr]: https://github.com/apache/felix-dev/pull/548
