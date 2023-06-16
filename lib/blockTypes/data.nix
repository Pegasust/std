{
  nixpkgs,
  root,
}:
/*
Use the Data Blocktype for json serializable data.

Available actions:
  - write
  - explore

For all actions is true:
  Nix-proper 'stringContext'-carried dependency will be realized
  to the store, if present.
*/
let
  inherit (root) mkCommand;
  inherit (builtins) toJSON concatStringsSep;
in
  name: {
    inherit name;
    type = "data";
    actions = {
      currentSystem,
      fragment,
      fragmentRelPath,
      target,
    }: let
      inherit (nixpkgs.legacyPackages.${currentSystem}) pkgs;

      # if target ? __std_data_wrapper, then we need to unpack from `.data`
      json = pkgs.writeTextFile {
        name = "data.json";
        text = toJSON (
          if target ? __std_data_wrapper
          then target.data
          else target
        );
      };
      jq = ["${pkgs.jq}/bin/jq" "-r" "'.'" "${json}"];
      fx = ["|" "${pkgs.fx}/bin/fx"];
    in [
      (mkCommand currentSystem "write" "write to file" "echo ${json}" {})
      (mkCommand currentSystem "explore" "interactively explore" (concatStringsSep "\t" (jq ++ fx)) {})
    ];
  }
