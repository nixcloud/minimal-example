{ pkgs, ... }:
{
   services.nixcloud.minimal.music1 = {
     enable = true;
     funkyExtra = "''yay''";

     proxyOptions = {
       port   = 40003;
       path   = "/example";
       domain = "example.com";
     };
   };
   services.nixcloud.minimal.music2 = {
     enable = true;
     funkyExtra = "''yay''";

     proxyOptions = {
       port   = 40004;
       path   = "/example2";
       domain = "example.com";
     };
   };
}
