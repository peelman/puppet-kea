# Releasing

This document describes the release process for the `peelman-kea` Puppet module.

## Overview

Releases are automated via GitHub Actions. When a version tag (e.g., `v0.1.0`) is pushed,
the CI pipeline runs all tests and, if successful, publishes the module to the
[Puppet Forge](https://forge.puppet.com/modules/peelman/kea).

## Prerequisites

### GitHub Secrets

The following secrets must be configured in the repository settings
(Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `FORGE_API_KEY` | Puppet Forge API key (generate at https://forge.puppet.com → Profile → API Keys) |

## Release Process

### 1. Bump the Version

Use the provided rake tasks to bump the version in `metadata.json`:

```bash
# Patch release (0.0.4 → 0.0.5)
bundle exec rake module:bump:patch

# Minor release (0.0.4 → 0.1.0)
bundle exec rake module:bump:minor

# Major release (0.0.4 → 1.0.0)
bundle exec rake module:bump:major
```

### 2. Update CHANGELOG.md

Add a new section for the release version:

```markdown
## [0.1.0] - YYYY-MM-DD

### Added
- New feature description

### Changed
- Changed behavior description

### Fixed
- Bug fix description
```

### 3. Commit and Tag

```bash
git add metadata.json CHANGELOG.md
git commit -m "Release v0.1.0"
git push

git tag v0.1.0
git push origin v0.1.0
```

### 4. Monitor CI

The tag push triggers the CI pipeline:

1. **Lint** - Puppet-lint and metadata validation
2. **Syntax** - Puppet syntax validation
3. **Unit Tests** - RSpec tests with Puppet 8
4. **Acceptance Tests** - Beaker tests on Debian 11/12, Ubuntu 22.04/24.04
5. **Release** - Build and publish to Puppet Forge (only on tags)

Monitor progress at: https://github.com/peelman/puppet-kea/actions

### 5. Verify Release

After CI completes successfully, verify the release at:
https://forge.puppet.com/modules/peelman/kea

## CI Pipeline

### Workflow File

The CI configuration is in `.github/workflows/ci.yml`.

### Triggers

| Event | Behavior |
|-------|----------|
| Push to `main` | Runs lint, syntax, unit, and acceptance tests |
| Pull request to `main` | Runs lint, syntax, unit, and acceptance tests |
| Push tag `v*` | Runs all tests, then publishes to Forge |

### Test Matrix

| Job | Environment |
|-----|-------------|
| Lint | Ubuntu latest, Ruby 3.2 |
| Syntax | Ubuntu latest, Ruby 3.2, Puppet 8 |
| Unit | Ubuntu latest, Ruby 3.2, Puppet 8 |
| Acceptance | Docker containers: Debian 11/12, Ubuntu 22.04/24.04 |

### Acceptance Test Containers

Acceptance tests use [litmusimage](https://hub.docker.com/u/litmusimage) containers
which have SSH and systemd pre-configured for faster test execution.

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** - Incompatible API changes
- **MINOR** - New functionality (backwards compatible)
- **PATCH** - Bug fixes (backwards compatible)

## Troubleshooting

### Release job fails with 401 Unauthorized

- Verify `FORGE_API_KEY` secret is set correctly
- Ensure the API key hasn't expired (regenerate at Forge profile page)
- The environment variable must be `BLACKSMITH_FORGE_API_KEY` in the workflow

### Release job fails with 409 Conflict

- The version already exists on the Forge
- Deleted versions cannot be re-uploaded
- Bump to a new version number and try again

### Acceptance tests timeout

- Check Docker is available in the CI runner
- Verify the litmusimage containers are accessible
- Review Beaker logs in the CI output

## Local Testing

Before pushing a release, run the full test suite locally:

```bash
# Install dependencies
bundle install

# Run linting
bundle exec rake lint

# Run unit tests
bundle exec rake spec

# Run acceptance tests (requires Docker)
bundle exec rake beaker:debian12
```

## Tools

This module uses [puppet-blacksmith](https://github.com/voxpupuli/puppet-blacksmith)
for version management and Forge publishing.

Available rake tasks:

```bash
bundle exec rake -T | grep module
```

Key tasks:
- `module:bump:patch` - Bump patch version
- `module:bump:minor` - Bump minor version  
- `module:bump:major` - Bump major version
- `module:build` - Build the module tarball
- `module:push` - Push to Puppet Forge
- `module:release` - Full release (bump, tag, push)
