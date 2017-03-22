{pkgs, lib, wsName}:

with lib;

{
  options = wsOptions: {
    services.nixcloud.${wsName} = mkOption {
      default = {};
      description = "";
      type = types.attrsOf (types.submodule ({ ... }: {
        options = wsOptions // {
          enable = mkOption {
            type = types.bool;
            default = false;
          };
          uniqueName = mkOption {
            description = "Can't be changed and will be set to ''${wsName}-'${name}' as for example: 'owncloud-instance1'.";
            default = "";
            type = types.str;
          };
          stateDir = mkOption {
            default = "";
            description = "Can't be changed and will be set to '/var/lib/'${uniqueName}' as for example: '/var/lib/owncloud-instance1'.";
            type = types.str;
          };
          user = mkOption {
            default = "";
            type = types.str;
          };
          group = mkOption {
            default = "";
            type = types.str;
          };
          proxyOptions = {
            port = mkOption {
              type = types.int;
              description = "";
            };
            path = mkOption {
              type = types.str;
              description = "";
            };
            domain = mkOption {
              type = types.str;
              description = "";
            };
          };
          webserver = {
            # FIXME: add package as in apache
            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = ''
                Cnfiguration lines appended to the generated Apache
                configuration file. Note that this mechanism may not work
                when <option>configFile</option> is overridden.
              '';
            };
            enablePHP = mkOption {
              type = types.bool;
              default = false;
            };
            privateTmp = mkOption {
              default = "yes";
              example = "no";
              description = "Weather to force the webservice to use a private /tmp instance. Warning: If postgresql stores the socket context in /tmp you have to say \"no\" here or it can't be used at all.";
            };
            extraServiceDependencies = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "postgresql.service" ];
              description = "Makes it easy to replace postgresql by mysql and depend on the service before we start the webservice.";
            };            
            startupScript = mkOption {
              default = "";
              type = types.str; # FIXME
            };
            extraPath = mkOption {
              type = types.listOf types.path;
              description = "Used to add useful scripts for webservice management into the system profile.";
              default = [];
            };
          };
        };
      }));
    };
  };
  
  config = config: 
      let 
        cfgCollection=config.services.nixcloud.${wsName}; 
        fastcgi_params = pkgs.writeText "fastcgi_params.conf" '' 
          fastcgi_param   QUERY_STRING            $query_string;
          fastcgi_param   REQUEST_METHOD          $request_method;
          fastcgi_param   CONTENT_TYPE            $content_type;
          fastcgi_param   CONTENT_LENGTH          $content_length;

          fastcgi_param   SCRIPT_FILENAME         $document_root$fastcgi_script_name;
          fastcgi_param   SCRIPT_NAME             $fastcgi_script_name;
          fastcgi_param   PATH_INFO               $fastcgi_path_info;
          fastcgi_param   PATH_TRANSLATED         $document_root$fastcgi_path_info;
          fastcgi_param   REQUEST_URI             $request_uri;
          fastcgi_param   DOCUMENT_URI            $document_uri;
          fastcgi_param   DOCUMENT_ROOT           $document_root;
          fastcgi_param   SERVER_PROTOCOL         $server_protocol;

          fastcgi_param   GATEWAY_INTERFACE       CGI/1.1;
          fastcgi_param   SERVER_SOFTWARE         nginx/$nginx_version;

          fastcgi_param   REMOTE_ADDR             $remote_addr;
          fastcgi_param   REMOTE_PORT             $remote_port;
          fastcgi_param   SERVER_ADDR             $server_addr;
          fastcgi_param   SERVER_PORT             $server_port;
          fastcgi_param   SERVER_NAME             $server_name;

          #fastcgi_param   HTTPS                   $https;

          # PHP only, required if PHP was built with --enable-force-cgi-redirect
          fastcgi_param   REDIRECT_STATUS         200;
        '';
        in {
      systemd.services = flip mapAttrs' cfgCollection (name: cfg:  #'
          assert cfg.proxyOptions.path != "" || abort "proxyOptions.path must not be an empty string";  
          assert cfg.proxyOptions.domain != "" || abort "proxyOptions.domain must not be an empty string";  
        nameValuePair
        ("${cfg.uniqueName}")
        ( mkIf (cfg.enable) {
          description = "Nginx HTTPD";
          wantedBy      = [ "multi-user.target" ];
          after = [ "network.target" "fs.target" "keys.target" ] ++ cfg.webserver.extraServiceDependencies;
          preStart = ''
            mkdir -p ${cfg.stateDir}/nginx/logs

            # fix permissions
            chmod 750 ${cfg.stateDir} -R
            chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
            
            # Run the startup hook
            ${pkgs.su}/bin/su -s "${pkgs.bash}/bin/bash" -c "${pkgs.bash}/bin/bash ${cfg.webserver.startupScript}" ${cfg.user}
          ''; 
          serviceConfig = let
            nginxConfigFile = pkgs.writeText "${cfg.uniqueName}.conf" '' 
              user "${cfg.user}" "${cfg.group}"; 
              error_log stderr; 
              daemon off; 
          
              events {}
          
              http {
                server {
                  listen ${toString cfg.proxyOptions.port};
                  access_log ${cfg.stateDir}/nginx/logs/access.log;
                  error_log ${cfg.stateDir}/nginx/logs/error.log;
                  server_name "${cfg.proxyOptions.domain}";

                  
                  ${cfg.webserver.extraConfig}
                }
              }
            '';
          in
            {
              ExecStart = "${pkgs.nginx}/bin/nginx -c ${nginxConfigFile} -p ${cfg.stateDir}/nginx";
              ExecReload  = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
              PIDFile = "${cfg.stateDir}/nginx.pid";

              Restart = "always";
              RestartSec = "10s";
              StartLimitInterval = "1min";
              # FIXME: enable this when testing done
              User = "${cfg.user}";
              Group = "${cfg.group}";
              PermissionsStartOnly=true;
              PrivateTmp=cfg.webserver.privateTmp;
            };
        })
      );

      environment.systemPackages = let
        makeList = a: lib.fold (el: c: c ++ (a.${el}) ) [] (lib.attrNames a);
        getExtraPath = c: flip mapAttrs c (name: cfg: if cfg.enable then cfg.webserver.extraPath else []);
      in makeList (getExtraPath cfgCollection);

      users.users = flip mapAttrs' cfgCollection (name: cfg: 
      nameValuePair
        (cfg.user)
        ( mkIf (cfg.enable) {
          name = "${cfg.user}";
          group = "${cfg.group}";
        }));
        
      users.groups = flip mapAttrs' cfgCollection (name: cfg: 
      nameValuePair
        (cfg.group)
        ( mkIf (cfg.enable) {
          name = "${cfg.group}";
        }));
        
        
  };
}
