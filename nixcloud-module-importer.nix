{ config, options, lib, pkgs, wsName, wsImplementation, wsBackendImplementation }:
with lib;

let
  backendImport = import wsBackendImplementation {
    inherit lib pkgs wsName;
  };
  serviceImport = import wsImplementation {
    inherit lib pkgs config options;
    inherit wsName;
  };
  # each webservice has individual configs as 'enablePHP' and here we 
  # merge them with config also accessible in the backend 
  # BUG: there must be a different function to inject option values because
  #      here we don't even check if there is a mkOption present
  #      result -> one can inject various options which don't even exist
  #      effect -> if a user writes a option name wrong in 'minimal.nix' it will fail silently
  #
  extendedConfig = recursiveUpdate config {
    services.nixcloud.${wsName} = 
      (mapAttrs (name: cfg: 
        let
          cfg_ = cfg // rec { 
            uniqueName = "${wsName}-${name}";
            stateDir = "/var/lib/${uniqueName}";
            user = if cfg.user == "" then "${uniqueName}" else cfg.user;
            group = if cfg.group == "" then "${uniqueName}" else cfg.group; 
          };
        in
         { 
          webserver = serviceImport.config cfg_;
          inherit (cfg_) uniqueName stateDir user group;
        })
        config.services.nixcloud.${wsName});
  };
in

{
  options = backendImport.options serviceImport.options;
  config = backendImport.config extendedConfig;
}
