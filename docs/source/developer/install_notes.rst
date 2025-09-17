Installation Notes and Fixups (Clean Install)
=============================================

This note summarizes the issues observed when running a clean install via
``install.sh`` and the fixes applied, in chronological order. It aims to help
others reproduce a working environment swiftly.

1. Docker Compose v1/v2 Compatibility
-------------------------------------

Symptom:
  On hosts with Docker Compose v2 (``docker compose``) or v1 (``docker-compose``),
  hardcoding the command name breaks.

Fix:
  ``install.sh`` now autodetects the compose entrypoint and uses a ``$COMPOSE``
  wrapper. It also enables ``set -euo pipefail`` and makes teardown resilient.

User impact:
  No change in usage; the script works on both v1/v2 hosts.

1b. Docker build cache toggle (install.sh)
-----------------------------------------

Symptom:
  Frequent rebuilds during development can be slow when cache is always disabled,
  but reproducibility sometimes requires ``--no-cache``.

Fix/Behavior:
  ``install.sh`` exposes an environment switch for Docker build cache:

  - Default: no-cache (historical behavior) — images built with ``--no-cache``.
  - Enable cache explicitly: ``WEKO_USE_CACHE=1 bash install.sh``.

This allows fast rebuilds when desired, while keeping the default strict.

2. Elasticsearch Bootstrapping (Developer Hosts)
-----------------------------------------------

Symptom:
  Elasticsearch 6.8 restarts with bootstrap checks and seccomp errors on
  developer kernels (e.g., Docker Desktop).

Fix:
  In ``docker-compose2.yml`` under the ``elasticsearch`` service:

  - ``discovery.type=single-node``
  - ``bootstrap.system_call_filter=false``

These relax checks for development. For production, configure the host kernel
properly instead.

3. Debian Buster EOL Mirrors Inside Build Containers
----------------------------------------------------

Symptom:
  ``apt-get update`` errors (404) because Debian 10 (buster) moved to
  ``archive.debian.org``.

Fix:
  ``scripts/provision-web.sh`` detects buster and rewrites ``sources.list`` to
  archived mirrors, also disabling ``Valid-Until`` checks.

4. Python 3.6 Dependency Resolution Pitfalls
--------------------------------------------

Symptom:
  Transitive dependencies (e.g., ``rocrate -> galaxy2cwl -> gxformat2 -> schema-salad``)
  resolve to versions incompatible with Python 3.6 during image build.

Fix:
  A constraints file ``scripts/pip-constraints.txt`` pins a known-good set,
  and ``scripts/create-instance.sh`` installs with ``-c scripts/pip-constraints.txt``.

5. Inbox Build Dependencies on Slim Images
------------------------------------------

Symptom:
  Building certain Python packages (e.g., JPype1) fails in the ``inbox`` image
  due to missing toolchain.

Fix:
  ``inbox/Dockerfile`` installs minimal build essentials (``build-essential``)
  and cleans APT lists.

6. SWORD/RO‑Crate (See dedicated guide)
---------------------------------------

Mapping/prerequisites are covered in :doc:`sword_rocrate`.

Changelog of Adjustments
------------------------

- ``install.sh``: v1/v2 compose detection; safer shell options; robust teardown.
- ``docker-compose2.yml``: ES single-node + relaxed syscall filter (dev only).
- ``scripts/provision-web.sh``: switch apt mirrors to ``archive.debian.org`` on buster.
- ``scripts/create-instance.sh``: install with pip constraints for Py3.6.
- ``inbox/Dockerfile``: add build essentials for native builds.

Notes
-----
- These changes target a smooth developer experience. Production deployments
  should use hardened kernel settings and revisit relaxed configurations.
