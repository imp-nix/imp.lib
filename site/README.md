# Site

Documentation source for imp, built with mdbook.

## Development

```sh
nix run .#docs        # serve with live reload
nix run .#build-docs  # build to ./result
```

Both commands regenerate `src/reference/methods.md` from doc-comments in `src/api.nix` before building.

## API Reference

`src/reference/methods.md` is auto-generated from `src/api.nix` using nixdoc. To update it:

```sh
nix build .#api-reference
cp result/methods.md src/reference/methods.md
```

The file is checked into git so docs are browsable on GitHub. Regenerate before committing changes to `src/api.nix`.
