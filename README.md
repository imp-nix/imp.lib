# importme

Recursively imports Nix modules from a directory tree.

## Quick Start

```nix
{
  inputs.importme.url = "github:Alb-O/importme";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
   (inputs.importme ./nix);
}
```

By default, paths containing `/_` are ignored.

## API

### `importme <path>`

Takes a path (or nested list of paths) and returns a module importing all `.nix` files found recursively.

```nix
{ imports = [ (importme ./nix) ]; }
```

### `.filter` / `.filterNot`

Filter paths by predicate. Multiple filters compose with AND.

```nix
importme.filter (lib.hasInfix ".mod.") ./nix
```

### `.match` / `.matchNot`

Filter paths by regex (uses `builtins.match`).

```nix
importme.match ".*/[a-z]+@(foo|bar)\.nix" ./nix
```

### `.map`

Transform each matched path.

```nix
importme.map (path: { imports = [ path ]; }) ./nix
```

### `.addPath`

Prepend additional paths to search.

```nix
(importme.addPath ./vendor) ./nix
```

### `.addAPI`

Extend the importme object with custom methods.

```nix
importme.addAPI {
  maximal = self: self.addPath ./nix;
  minimal = self: self.maximal.filter (lib.hasInfix "minimal");
}
```

### `.withLib`

Required before using `.leafs`, `.tree`, or `.pipeTo` outside module evaluation.

```nix
(importme.withLib pkgs.lib).leafs ./nix
```

### `.leafs` / `.files`

Get the list of matched files (requires `.withLib` first).

```nix
(importme.withLib lib).files
```

### `.tree`

Build a nested attrset from a directory structure (requires `.withLib` first).

```nix
# Given directory:
#   ./nix/
#     packages/
#       foo.nix  # { name = "foo"; }
#       bar.nix  # { name = "bar"; }
#     default_.nix  # { isDefault = true; }

(importme.withLib lib).tree ./nix
# Returns:
# {
#   default = { isDefault = true; };
#   packages = {
#     foo = { name = "foo"; };
#     bar = { name = "bar"; };
#   };
# }
```

File/directory naming:

- `foo.nix` becomes `foo` attribute
- `foo/default.nix` becomes `foo` attribute (imports the directory)
- `foo_.nix` becomes `foo` attribute (escape suffix for reserved names)
- `_foo.nix` and `_foo/` are ignored (hidden, consistent with flat importer)

### `.mapTree`

Transform imported values in `.tree`. Multiple calls compose.

```nix
(importme.withLib lib)
  .mapTree (x: x // { extra = true; })
  .tree ./nix/packages
# Each imported value gets { extra = true; } merged in
```

### `.initFilter`

Replace the default filter (`.nix` files, excluding `/_` paths).

```nix
importme.initFilter (lib.hasSuffix ".md")
```

### `.new`

Returns a fresh `importme` with empty state.

## Testing

```sh
nix run .#tests
nix flake check
```

## Attribution

Project originally written by @vic under the name `import-tree`: https://github.com/vic/import-tree

## License

Apache-2.0 License, see [LICENSE](LICENSE) file for details.
