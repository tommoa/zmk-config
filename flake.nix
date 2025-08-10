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

        zephyrDepsHash = "";

        installPhase = ''
          runHook preInstall

          mkdir $out
          
          # List what we actually have
          echo "Available files in zephyr directory:"
          ls -la zephyr/ || true
          
          # Copy .bin file if it exists
          if [ -f zephyr/zmk.bin ]; then
            echo "Copying zmk.bin"
            cp --no-preserve=all zephyr/zmk.bin $out/
          fi
          
          # Copy .hex file if it exists
          if [ -f zephyr/zmk.hex ]; then
            echo "Copying zmk.hex"
            cp zephyr/zmk.hex $out/
          fi
          
          # Copy .uf2 files if they exist
          for uf2_file in zephyr/*.uf2; do
            if [ -f "$uf2_file" ]; then
              echo "Copying $uf2_file"
              cp "$uf2_file" $out/
            fi
          done

          cp zephyr/zephyr.dts $out/
          grep -v -e "^#" -e "^$" "zephyr/.config" | sort | tee $out/Kconfig

          runHook postInstall
        '';

        fixupPhase = '''';

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
          
          dfu-util -a 0 -s 0x08000000:leave -D ${firmware}/zmk.bin -w
          
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
