{ config, options, lib, pkgs, wsName }:

with lib; 

{
  options = {
    funkyExtra = mkOption {
      example = "foobar";
      default = "";
      type = types.str;
      description = "Extra stuff you can put into the WS!";
    };
  };

  config = cfg: rec {
    enablePHP = true;
    extraConfig = ''
      root ${cfg.stateDir};
    '';
    startupScript = pkgs.writeText "startupScript-${cfg.uniqueName}.sh" '' 
      mkdir -p ${cfg.stateDir}/${cfg.proxyOptions.path}
      echo "hello world: ${cfg.funkyExtra} from ${cfg.uniqueName}" > ${cfg.stateDir}/index.html
      echo "hello world: ${cfg.funkyExtra} from ${cfg.uniqueName} in subdirectory" > ${cfg.stateDir}/${cfg.proxyOptions.path}/index.html
    '';

    ff="aaa"; # BUG: should result in an error as there is no mkOption called ff
  };
}


