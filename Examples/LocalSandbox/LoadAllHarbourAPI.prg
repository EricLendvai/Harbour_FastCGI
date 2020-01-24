//The following will force the hbx files listed in this prg to be processed and force all those libraries object files to be linked.
#define __HBEXTREQ__

//The following will load all the harbour internal functions.
#include "harbour.hbx"


//List contrib libraries and all of their objects to be linked. You must also update the LocalSandbox.hbp to add the related .hbc files
#include "C:\Harbour\contrib\hbfoxpro\hbfoxpro.hbx"

