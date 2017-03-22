{ config, options, lib, pkgs }:
let
  loadWS = { wsName, wsImplementation, wsBackendImplementation } : 
    (import ./nixcloud-module-importer.nix {
      inherit lib config options pkgs; 
      inherit wsName wsImplementation wsBackendImplementation;
    });
  mkAttrSet = a: b: { wsImplementation = a; wsBackendImplementation = b; };

in rec {

    webservices = {
      # a minimal example on how to use nginx
      minimal = mkAttrSet ./webservices/minimal.nix ./backends/nginx.nix;
  };
  
  webservice-modules = (lib.fold (el: c: c ++ [(loadWS ({ wsName=el; } // webservices.${el}) )]) [] (lib.attrNames webservices));
}
  

