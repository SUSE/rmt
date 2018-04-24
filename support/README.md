Supportconfig plugin development notes
======================================

Library of useful functions is installed by supportutils at: /usr/lib/supportconfig/resources/scplugin.rc

plugin functions begin with 'p'.

To test, install rmt-server and supportutils on a supported distribution.

supportconfig -F lists all features, including plugins.

Plugins are prefixed in this output with 'p'.

To run only a given plugin (as well as basic checks), call supportconfig with -i and the plugin's feature name:

```supportconfig -i prmt```
