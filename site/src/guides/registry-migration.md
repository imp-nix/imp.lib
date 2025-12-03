# Registry Migration

When you rename directories, registry paths change. The migration tool detects broken references and generates fix commands.

## The Problem

After renaming `registry/home/` to `registry/users/`:

```nix
# outputs/nixosConfigurations/server.nix
modules = imp.imports [
  registry.home.alice  # Broken!
];
```

## Running Migration

```sh
# See what needs fixing
nix run .#imp-registry

# Apply fixes automatically
nix run .#imp-registry -- --apply
```

## Example Output

```
Registry Migration
==================

Detected renames:
  home.alice -> users.alice
  home.bob -> users.bob

Affected files:
  nix/outputs/nixosConfigurations/server.nix
  nix/outputs/homeConfigurations/alice.nix

Commands to apply:
  ast-grep --lang nix --pattern 'registry.home.alice' --rewrite 'registry.users.alice' nix/outputs/...
  ast-grep --lang nix --pattern 'registry.home.bob' --rewrite 'registry.users.bob' nix/outputs/...

Run with --apply to execute these commands.
```

## How It Works

1. **Scans files** for `registry.X.Y` patterns
2. **Compares** against current registry to find broken references
3. **Matches** old paths to new paths by leaf name (e.g., `home.alice` → `users.alice`)
4. **Uses ast-grep** for AST-aware replacements (handles multi-line expressions)

## Configuration

Set directories to scan for renames:

```nix
imp.registry.migratePaths = [
  ./outputs
  ./registry  # Can include registry itself
];
```

## AST-Aware Replacements

The tool uses [ast-grep](https://ast-grep.github.io/) instead of simple text replacement:

```nix
# Multi-line expressions are handled correctly
modules = imp.imports [
  registry.home.alice  # <- Replaced correctly
];

# Comments and strings are not affected
# registry.home.alice <- Not replaced (comment)
description = "registry.home.alice";  # <- Not replaced (string)
```

## Ambiguous Renames

When a leaf name exists in multiple new locations:

```
# Before rename
modules/common.nix -> registry.modules.common

# After rename
modules/nixos/common.nix -> registry.modules.nixos.common
modules/home/common.nix  -> registry.modules.home.common
```

The tool shows ambiguity:

```
Warning: Ambiguous rename for 'common':
  Could be: modules.nixos.common
  Could be: modules.home.common
  Skipping - please fix manually.
```

## Manual Fixes

For complex renames, fix manually:

```sh
# Find all occurrences
rg 'registry\.old\.path' ./outputs

# Replace with your editor or sed
```

## Best Practices

1. **Commit before renaming** - Easy rollback if needed
2. **Run migration immediately** after rename
3. **Review changes** before committing
4. **Use --apply carefully** - Review output first

## See Also

- [The Registry](../concepts/registry.md) - Registry overview
- [Registry Visualization](./registry-visualization.md) - View dependency graph
