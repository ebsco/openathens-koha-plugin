openathens-koha-plugin
==================

openathens-koha-plugin

Tested on Koha v 16.11+

Quick Installation steps
==================

Download the package file oa_Plugin_xx.kpz

Login to Koha Admin and go to Tools-> Plugin ( Make sure Koha plugin is enabled)

Upload Plugin

Click on Run Tool and follow instructions.

Click on Configure and enter required details from OA admin.

Go to Koha Administration -> System preference -> Opac -> OPACUserJS and add the following section of code:

```
/\*oa{\*/var oas=document.createElement( 'script' );oas.type = 'text/javascript';oas.src='/plugin/Koha/Plugin/OAKoha/OAKoha.js';document.body.appendChild(oas);/\*}oa\*/
```


