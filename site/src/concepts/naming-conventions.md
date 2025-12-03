# Naming Conventions

Imp uses file and directory names to determine attribute names in the resulting module tree.

## Basic Rules

| Path | Attribute | Notes |
|------|-----------|-------|
| `foo.nix` | `foo` | File becomes attribute |
| `foo/default.nix` | `foo` | Directory with default.nix |
| `foo_.nix` | `foo` | Trailing `_` escapes reserved names |
| `_foo.nix` | *(ignored)* | Leading `_` = hidden |

## File Extension Stripping

The `.nix` extension is automatically stripped:

```
packages/
  hello.nix     # -> packages.hello
  world.nix     # -> packages.world
```

## Directory Modules

A directory with `default.nix` is treated as a single module:

```
services/
  nginx/
    default.nix   # -> services.nginx
    vhosts.nix    # Imported by default.nix, not visible in tree
```

## Hidden Files

Files and directories starting with `_` are ignored:

```
modules/
  _helpers.nix    # Ignored - can be imported manually
  _lib/           # Ignored directory
    utils.nix     # Also ignored
  visible.nix     # -> modules.visible
```

This is useful for:
- Helper functions imported by other modules
- Work-in-progress files
- Templates

## Reserved Name Escaping

Some names conflict with Nix keywords or common attributes. Use trailing `_` to escape:

```
outputs/
  default_.nix    # -> outputs.default (not treated as directory module)
  import_.nix     # -> outputs.import (Nix keyword)
  let_.nix        # -> outputs.let (Nix keyword)
```

Common cases:
- `default_.nix` - Prevent treating as directory module
- `import_.nix` - Nix keyword
- `let_.nix` - Nix keyword
- `with_.nix` - Nix keyword

## Directory Paths in Registry

When building a registry, directories without `default.nix` include a special `__path` attribute:

```
registry/
  modules/
    nixos/          # No default.nix
      base.nix      # -> registry.modules.nixos.base
      server.nix    # -> registry.modules.nixos.server
```

```nix
registry.modules.nixos          # Attrset with base, server, __path
registry.modules.nixos.__path   # Path to the nixos/ directory
registry.modules.nixos.base     # Path to base.nix
```

This lets you:
- Import specific files: `import registry.modules.nixos.base`
- Import entire directory: `inputs.imp registry.modules.nixos.__path`

## Case Sensitivity

Names are case-sensitive on case-sensitive filesystems:

```
Users/
  Alice.nix   # -> Users.Alice
  alice.nix   # -> Users.alice (different!)
```

## Non-.nix Files

Only `.nix` files are collected. Other files are ignored:

```
config/
  settings.nix    # -> config.settings
  settings.json   # Ignored
  README.md       # Ignored
```

## See Also

- [Directory Imports](./directory-imports.md) - How imports work
- [The Registry](./registry.md) - Named module access
