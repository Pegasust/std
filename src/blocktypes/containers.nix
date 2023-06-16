{
  nixpkgs,
  n2c, # nix2container
  mkCommand,
  sharedActions,
}: let
  l = nixpkgs.lib // builtins;
  /*
  Use the Containers Blocktype for OCI-images built with nix2container.

  Available actions:
    - print-image
    - publish
    - load
  */
  containers = name: {
    __functor = import ./__functor.nix;
    inherit name;
    type = "containers";
    actions = {
      currentSystem,
      fragment,
      fragmentRelPath,
      target,
    }: let
      inherit (n2c.packages.${currentSystem}) skopeo-nix2container;
      tags' =
        builtins.toFile "${target.name}-tags.json" (builtins.concatStringsSep "\n" target.image.tags);
      copyFn = let
        skopeo = "skopeo --insecure-policy";
      in ''
        export PATH=${skopeo-nix2container}/bin:$PATH

        copy() {
          local uri prev_tag
          uri=$1
          shift

          for tag in $(<${tags'}); do
            if ! [[ -v prev_tag ]]; then
              ${skopeo} copy nix:${target} "$uri:$tag" "$@"
            else
              # speedup: copy from the previous tag to avoid superflous network bandwidth
              ${skopeo} copy "$uri:$prev_tag" "$uri:$tag" "$@"
            fi
            echo "Done: $uri:$tag"

            prev_tag="$tag"
          done
        }
      '';
    in [
      (sharedActions.build currentSystem target)
      (mkCommand currentSystem {
        name = "print-image";
        description = "print out the image.repo with all tags";
        command = ''
          echo
          for tag in $(<${tags'}); do
            echo "${target.image.repo}:$tag"
          done
        '';
      })
      (mkCommand currentSystem {
        name = "publish";
        description = "copy the image to its remote registry";
        command = ''
          ${copyFn}
          copy docker://${target.image.repo}
        '';
        meta.image = target.image.name;
        proviso = pkgs.substituteAll {
          src = ./container-proviso.sh;
          filter = ./container-publish-filter.jq;
        };
      })
      (mkCommand currentSystem {
        name = "load";
        description = "load image to the local docker daemon";
        command = ''
          ${copyFn}
          if command -v podman &> /dev/null; then
             echo "Podman detected: copy to local podman"
             copy containers-storage:${target.image.repo} "$@"
          fi
          if command -v docker &> /dev/null; then
             echo "Docker detected: copy to local docker"
             copy docker-daemon:${target.image.repo} "$@"
          fi
        '';
      })
      (mkCommand currentSystem {
        name = "copy-to-registry";
        description = "deprecated: use 'publish' instead";
        command = "echo 'copy-to-registry' is deprecated; use 'publish' action instead && exit 1";
      })
      (mkCommand currentSystem {
        name = "copy-to-docker";
        description = "deprecated: use 'load' instead";
        command = "echo 'copy-to-docker' is deprecated; use 'load' action instead && exit 1";
      })
      (mkCommand currentSystem {
        name = "copy-to-podman";
        description = "deprecated: use 'load' instead";
        command = "echo 'copy-to-podman' is deprecated; use 'load' action instead && exit 1";
      })
    ];
  };
in
  containers
