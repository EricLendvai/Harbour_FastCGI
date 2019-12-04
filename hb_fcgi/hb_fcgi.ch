#ifndef HB_FCGI_CH_
#define HB_FCGI_CH_

#include "hbclass.ch"

#xcommand TRY => BEGIN SEQUENCE WITH __BreakBlock()
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS
#xcommand ENDTRY => END
#xcommand ENDDO => END
#xcommand ENDFOR => END

#xtranslate Allt( <x> )    => alltrim( <x> )
#xtranslate Trans( <x> )    => alltrim( str(<x>,10) )

#command ? [<cText,...>] => oFcgi:Print( <cText> )

#define CRLF chr(13)+chr(10)

#endif /* HB_FCGI_CH_ */

memvar oFcgi
