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


#xcommand SCAN [NEXT <next>] [RECORD <rec>] [<rest:REST>] [ALL] [NOOPTIMIZE] => ;
            VFP_ScanStack("push") ;;
            do while iif(VFP_ScanStack(),hb_isnil(__dbLocate({||.T.},{||.T.}, <next>, <rec>, <.rest.> )) .and. !eof(),hb_isnil(__dbContinue()) .and. !eof())

#xcommand SCAN WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [ALL] [NOOPTIMIZE] => ;
            VFP_ScanStack("push") ;;
            do while iif(VFP_ScanStack(),hb_isnil(__dbLocate({||.T.} , <{while}>, <next>, <rec>, <.rest.> )) .and. !eof(),hb_isnil(__dbContinue()) .and. !eof())

#xcommand SCAN FOR <for> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [ALL] [NOOPTIMIZE] => ;
            VFP_ScanStack("push") ;;
            do while iif(VFP_ScanStack(),hb_isnil(__dbLocate( <{for}>, {||.T.}, <next>, <rec>, <.rest.> )) .and. !eof(),hb_isnil(__dbContinue()) .and. !eof())

#xcommand SCAN FOR <for> WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [ALL] [NOOPTIMIZE] => ;
            VFP_ScanStack("push") ;;
            do while iif(VFP_ScanStack(),hb_isnil(__dbLocate( <{for}>, <{while}>, <next>, <rec>, <.rest.> )) .and. !eof(),hb_isnil(__dbContinue()) .and. !eof())
                    
#command ENDSCAN => ENDDO;VFP_ScanStack("pop")

#xcommand TEXT TO VAR <var> => #pragma __stream|<var>:=%s
#xcommand ENDTEXT => #pragma __endtext

#endif /* HB_FCGI_CH_ */

memvar oFcgi
