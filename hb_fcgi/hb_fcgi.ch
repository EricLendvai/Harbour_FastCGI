#ifndef HB_FCGI_BUILDVERSION
#define HB_FCGI_BUILDVERSION "1.12"

#include "hbclass.ch"

#xcommand TRY => BEGIN SEQUENCE WITH __BreakBlock()
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS
#xcommand ENDTRY => END
#xcommand ENDDO => END
#xcommand ENDFOR => END

#xtranslate Allt( <x> )    => alltrim( <x> )
#xtranslate Trans( <x> )    => alltrim( str(<x>,10) )

#command ? [<cText,...>] => oFcgi:Print( [<cText>] )

#define CRLF chr(13)+chr(10)

//Following SCAN definitions come from the Harbour_EL repo.
//--------------------------------------------------------------------------------------------

#xcommand SCAN ALL [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            dbGoTop(); EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate({||.T.}, {||.T.}, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(__dbContinue()) .and. Found() .and. !eof())

#xcommand SCAN [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate({||.T.}, {||.T.}, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(__dbContinue()) .and. Found() .and. !eof())

//--------------------------------------------------------------------------------------------
// #xcommand SCAN ALL WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
//             dbGoTop(); EL_ScanStack("push") ;;
//             do while iif(EL_ScanStack(),hb_isnil(__dbLocate({||.T.}, <{while}>, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(dbskip()) .and. hb_isnil(__dbContinue()) .and. Found() .and. !eof())

// #xcommand SCAN WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
//             EL_ScanStack("push") ;;
//             do while iif(EL_ScanStack(),hb_isnil(__dbLocate({||.T.}, <{while}>, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(dbskip()) .and. hb_isnil(__dbContinue()) .and. Found() .and. !eof())

//Buggy WHILE, so added a using the eval({||<while>})

#xcommand SCAN ALL WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            dbGoTop(); EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate({||.T.}, {||.T.}, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof() .and. eval({||<while>}),hb_isnil(__dbContinue()) .and. Found() .and. !eof() .and. eval({||<while>}))

#xcommand SCAN WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate({||.T.}, {||.T.}, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof() .and. eval({||<while>}),hb_isnil(__dbContinue()) .and. Found() .and. !eof() .and. eval({||<while>}))

//--------------------------------------------------------------------------------------------

#xcommand SCAN ALL FOR <for> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            dbGoTop(); EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate( <{for}>, {||.T.}, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(__dbContinue()) .and. Found() .and. !eof())

#xcommand SCAN FOR <for> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate( <{for}>, {||.T.}, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(__dbContinue()) .and. Found() .and. !eof())

//--------------------------------------------------------------------------------------------
//Did not test this att all. Most likely buggy due to the WHILE
#xcommand SCAN ALL FOR <for> WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            dbGoTop(); EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate( <{for}>, <{while}>, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(__dbContinue()) .and. Found() .and. !eof())

#xcommand SCAN FOR <for> WHILE <while> [NEXT <next>] [RECORD <rec>] [<rest:REST>] [NOOPTIMIZE] => ;
            EL_ScanStack("push") ;;
            do while iif(EL_ScanStack(),hb_isnil(__dbLocate( <{for}>, <{while}>, <next>, <rec>, <.rest.> )) .and. Found() .and. !eof(),hb_isnil(__dbContinue()) .and. Found() .and. !eof())

//--------------------------------------------------------------------------------------------

#command ENDSCAN => ENDDO;EL_ScanStack("pop")



#xcommand TEXT TO VAR <var> => #pragma __stream|<var>:=%s
#xcommand ENDTEXT => #pragma __endtext

#endif /* HB_FCGI_BUILDVERSION */

memvar oFcgi
