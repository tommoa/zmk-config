{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zmk-nix }: let
    forAllSystems = nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames zmk-nix.packages);
  in {
    packages = forAllSystems (system: rec {
      default = firmware;

      firmware = zmk-nix.legacyPackages.${system}.buildKeyboard {
        name = "firmware";

        src = nixpkgs.lib.sourceFilesBySuffices self [ ".board" ".cmake" ".conf" ".defconfig" ".dts" ".dtsi" ".json" ".keymap" ".overlay" ".shield" ".yml" "_defconfig" ];

        board = "preonic_rev3";

        zephyrDepsHash = "sha256-OGmPnAsa+5CrPonGIGNfmQZDUm/lpAuOfW/2rMmgAW8=";

        installPhase = ''
          runHook preInstall

          mkdir $out
          cp zephyr/zmk.elf $out/

          runHook postInstall
        '';

        meta = {
          description = "ZMK firmware";
          license = nixpkgs.lib.licenses.mit;
          platforms = nixpkgs.lib.platforms.all;
        };
      };

      flash = nixpkgs.legacyPackages.${system}.writeShellApplication {
        name = "zmk-dfu-flash";
        
        runtimeInputs = [
          nixpkgs.legacyPackages.${system}.dfu-util
        ];
        
        text = ''
          echo "ZMK DFU Flasher for Preonic Rev3"
          echo "================================="
          echo
          echo "Instructions:"
          echo "1. Hold the RESET button on your Preonic"
          echo "2. While holding RESET, press and hold the BOOT button"
          echo "3. Release RESET while still holding BOOT"
          echo "4. Release BOOT"
          echo "5. Your Preonic should now be in DFU mode"
          echo
          echo "Press Enter when your Preonic is in DFU mode..."
          
          echo "Checking for DFU device..."
          while ! dfu-util -l | grep -q "Found DFU"; do
            # echo "Error: No DFU device found!"
            # echo "Make sure your Preonic is in DFU mode and try again."
            # exit 1
            sleep 1
            echo -n .
          done
          
          echo "Found DFU device. Flashing firmware..."
          dfu-util -a 0 -s 0x08000000:leave -D ${firmware}/zmk.elf
          
          echo "Flashing complete! Your Preonic should restart automatically."
        '';
        
        meta = {
          description = "ZMK DFU firmware flasher for Preonic Rev3";
          license = nixpkgs.lib.licenses.mit;
          platforms = nixpkgs.lib.platforms.linux;
        };
      };
      update = zmk-nix.packages.${system}.update;
    });

    devShells = forAllSystems (system: {
      default = zmk-nix.devShells.${system}.default;
    });
  };
}
