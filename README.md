# what is this?

this is a minimal example showing how create nixos services which can be instantiated multiple times:

    services.nixcloud.minimal.<name?>

benefits are:

 - multiple instantiation 
 - each serivce has a unique ${storeDir}
 - (in this example) service holds persistent state in a single directory 
 - as shown in minimal.nix with funkyExtra one can create options per webservice and they get appended into the nginx configuration from nixcloud-module-importer.nix
 - `minimal.nix` is easy to implement, `nginx.nix` is rather complicated in comparison, for instance:

      config = config:
        let
          cfgCollection=config.services.nixcloud.${wsName};
        in {

        systemd.services = flip mapAttrs' cfgCollection (name: cfg:  #'
        let
          apacheConfigFile = pkgs.writeText "${cfg.uniqueName}.conf" ''
            ServerRoot ${httpd}

    on has to `mapAttrs'` the cfgCollection into individual cfg(s) which hold each individual configuration of a service.

problems are:

 - nix-repl can only see the default value for `${stateDir}` for each configured webservice

      nix-repl> config.services.nixcloud.minimal
      { music1 = { ... }; music2 = { ... }; }

      :p config.services.nixcloud.minimal.music1.stateDir
      ""

   this is caused by the fact that nixcloud-module-importer.nix changes the `stateDir` from the default to a 'different' value!
   however, since only the later configuration knows about `music1` and `music2` it can't be assigned in `nginx.nix` which is sad since
   it breaks the options system as we know it.

# how to deploy

1. to see how this works, do this:

in `configuration.nix` add this:

      imports =
        [ # Include the results of the hardware scan.
          ./hardware-configuration.nix
        ] ++ (import /tmp/minimal-example/all-nixcloud-services.nix { inherit config; inherit options; inherit lib; inherit pkgs;}).webservice-modules;
  
       services.nixcloud.minimal.music1 = {
         enable = true;
         funkyExtra = "''yay1''";

  
         proxyOptions = {
           port   = 40003;
           path   = "/example";
           domain = "example.com";
         };
       };
       services.nixcloud.minimal.music2 = {
         enable = true;
         funkyExtra = "''yay2''";
  
         proxyOptions = {
           port   = 40004;
           path   = "/example2";
           domain = "example.com";
         };
       };

2. then build the new system

       nixos-rebuild switch

3. finally open your browser

       chromium localhost:40003/example/

    or

       chromium localhost:40004/example/

    each page respectivly shows this:

        hello world: ''yay'' from minimal-music1 in subdirectory

4. visit the stateful directory

        cd /var/lib/minimal-music1
        ls -lathr
