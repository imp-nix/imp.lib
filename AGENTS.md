# imp.lib

Core Nix library and flake-parts module for automatic imports.

## Tree Builder Behavior

`imp.tree` and `imp.treeWith` map directory structure to nested attrsets:

```
outputs/
  packages.nix      -> { packages = <imported> }
  packages/
    foo.nix         -> { packages.foo = <imported> }
    default.nix     -> { packages = <imported> }  # takes precedence
```

**Naming rules:**

- `foo.nix` or `foo/default.nix` -> `{ foo = ... }`
- `foo_.nix` -> `{ foo = ... }` (trailing underscore escapes reserved names)
- `_foo.nix` or `_foo/` -> ignored (underscore prefix)
- `foo.d/` -> ignored (fragment directories, use `imp.fragments` instead)

**Conflict behavior:** When both `foo.nix` and `foo/` exist, the last one processed wins (non-deterministic). If `foo/` has a `default.nix`, it's treated as a single value and siblings like `foo/bar.nix` are ignored. Avoid this pattern; keep related outputs in a single `.nix` file or use directories without `default.nix`.

## Fragment Directories

Directories ending in `.d` are for `imp.fragments`, not tree building:

```nix
shellHookFragments = imp.fragments ./shellHook.d;
packageFragments = imp.fragmentsWith { inherit pkgs self'; } ./packages.d;
```

Fragments are sorted by filename and composed (concatenated for strings, merged for attrsets/lists).
