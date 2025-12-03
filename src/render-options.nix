/*
  Render flake-parts module options to markdown.

  Evaluates the flakeModule and extracts option metadata to generate
  documentation in a format similar to the NixOS manual.
*/
{ lib }:
let
  inherit (lib)
    mapAttrsToList
    concatStringsSep
    optionalString
    hasPrefix
    isAttrs
    ;

  # Format a type for display
  formatType =
    type:
    if type ? description then
      type.description
    else if type ? name then
      type.name
    else
      "unspecified";

  # Format a default value safely
  # Note: we use defaultText when available since default may require evaluation context
  # For complex defaults that can't be safely evaluated, we show `...`
  formatDefault =
    opt:
    if opt ? defaultText then
      let
        dt = opt.defaultText;
      in
      if dt ? text then "`${dt.text}`" else "`...`"
    else if !(opt ? default) then
      "*required*"
    else
      # Just show placeholder - evaluating defaults is unsafe without proper context
      "`...`";

  # Render a single option to markdown
  renderOption =
    path: opt:
    let
      typeStr = formatType (opt.type or { });
      defaultStr = formatDefault opt;
      description = opt.description or "";
      example = opt.example or null;
    in
    ''
      ## `${path}` {#${builtins.replaceStrings [ "." ] [ "-" ] path}}

      `${typeStr}` (default: ${defaultStr})

      ${description}
    ''
    + optionalString (example != null) ''

      **Example:**

      ```nix
      ${
        if example ? text then
          example.text
        else if builtins.isString example then
          example
        else
          builtins.toJSON example
      }
      ```
    '';

  # Recursively collect options from an option set
  collectOptions =
    prefix: opts:
    let
      isOption = v: isAttrs v && v ? _type && v._type == "option";
      processAttr =
        name: value:
        let
          path = if prefix == "" then name else "${prefix}.${name}";
        in
        if isOption value then
          [
            {
              inherit path;
              opt = value;
            }
          ]
        else if isAttrs value && !(value ? _type) then
          collectOptions path value
        else
          [ ];
    in
    builtins.concatLists (mapAttrsToList processAttr opts);

  # Main render function
  render =
    options:
    let
      collected = collectOptions "" options;
      # Filter to only imp.* options
      impOptions = builtins.filter (x: hasPrefix "imp." x.path) collected;
      rendered = map (x: renderOption x.path x.opt) impOptions;
    in
    ''
      # Module Options

      <!-- Auto-generated from src/flakeModule.nix - do not edit -->

      ${concatStringsSep "\n" rendered}
    '';

in
{
  inherit render collectOptions renderOption;
}
