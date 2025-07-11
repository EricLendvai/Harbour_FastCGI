//static const char rcsid[] = "$Id: hb_fcgi.c,v 1.5 2019/11/16 08:08:00 Eric Lendvai Exp $";

//Copyright (c) 2022 Eric Lendvai MIT License

// Following define needed as of MSVC 2022
// #define _CRT_SECURE_NO_DEPRECATE

#include "fcgi_config.h"

#include <stdlib.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef _WIN32
#include <process.h>
#else
extern char **environ;
#endif

#ifdef _WIN32
#define GETPID _getpid
#else
#define GETPID getpid
#endif

#include "fcgiapp.h"

#ifdef _WIN32
#include <windows.h>
#endif

#ifdef unix
#include <syslog.h>
#endif


#include "hbapi.h"
#include "hbapiitm.h"
#include "hbapicdp.h"
#include "hbapierr.h"

// #include <signal.h>

#define AP_FILENAMEMAXLENGTH 512
// static char cAP_FileName[AP_FILENAMEMAXLENGTH] = "Not Set";          // Used hold last value of SET_AP_FILENAME
static char cAP_FileName[AP_FILENAMEMAXLENGTH] = "01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789";          // Used hold last value of SET_AP_FILENAME

#ifdef _WIN32
static char cDebugStringBuffer[20000];
#endif

static FCGX_Stream *g_in, *g_out, *g_err;
static FCGX_ParamArray g_envp;

static void PrintEnv(FCGX_Stream *par_out, char *par_label, char **par_envp)
{
    FCGX_FPrintF(par_out,"<p>%s:<p>\n<pre>\n", par_label);
    for( ; *par_envp != NULL; par_envp++) {
        FCGX_FPrintF(par_out, "%s\n", *par_envp);
    }
    FCGX_FPrintF(par_out, "</pre><p>\n");
}

// The following code was never used.
// #ifdef _WIN32
// void handle_sigint(int sig) 
// { 
//     sprintf_s(cDebugStringBuffer, "[Harbour] Signal %d\n",(int)sig);
//     OutputDebugString(cDebugStringBuffer);
// } 
// #endif

HB_FUNC( HB_FCGX_WAIT )
{
    int iReturn;
    iReturn = FCGX_Accept(&g_in, &g_out, &g_err, &g_envp);
    hb_retni(iReturn);
}

HB_FUNC( HB_FCGX_GETCONTENTLENGTH )
{
    int iInputLength = 0;
    char *contentLength = FCGX_GetParam("CONTENT_LENGTH", g_envp);
    if (contentLength != NULL)
            iInputLength = strtol(contentLength, NULL, 10);
    hb_retni( iInputLength );
}

HB_FUNC( HB_FCGX_GETINPUT )
{
    int iInputLength = hb_parni( 1 );
    char * szBuffer = ( char * ) hb_xalloc( iInputLength + 1 );

    if (FCGX_GetStr( szBuffer, iInputLength, g_in ) != iInputLength)
    {
        hb_retc_null();
    } else {
        hb_retclen( szBuffer, iInputLength );
    }
}

HB_FUNC( HB_FCGX_GETENVIRONMENT )  // Not used anymore. Preloaded an entire hash instead.
{
    PHB_ITEM pParameterName = hb_param( 1, HB_IT_ANY );

    if ( pParameterName && HB_IS_STRING( pParameterName ))
    {
        char *cParameterValue = FCGX_GetParam(hb_itemGetCPtr(pParameterName), g_envp);

        if(cParameterValue != NULL) {
            hb_retc(cParameterValue);
        } else {
            hb_retc_null();
        }
    } else {
        hb_retc_null();
    }
}

HB_FUNC( HB_FCGX_PRINT )   // Used internally by hb_fcgi function
{
    int iResult ;

    if ( HB_ISCHAR( 1 ) )
    {
    	FCGX_FPrintF(g_out, hb_parc( 1 ) );
        iResult = 1;
    } else {
        iResult = -1;
    }
	
    hb_retni( iResult );
}

HB_FUNC( HB_FCGX_BPRINT )   // Used internally by hb_fcgi function   Binary Print
{
    int iResult ;

    if ( HB_ISCHAR( 1 ) )
    {
    	FCGX_PutStr(hb_parc( 1 ),hb_parclen( 1 ),g_out );
        iResult = 1;
    } else {
        iResult = -1;
    }
	
    hb_retni( iResult );
}

HB_FUNC( HB_FCGI_PRINTENVIRONMENT )  //Only usefull to test FastCGI development - Will be removed
{
    PrintEnv(g_out, "Request environment", g_envp);
    PrintEnv(g_out, "Initial environment", environ);

    hb_retni(0);
}

HB_FUNC( HB_FCGX_INIT )
{
#ifdef _WIN32
    // sprintf_s(cDebugStringBuffer, "[Harbour] Fcgi Init \n");
    strcpy_s(cDebugStringBuffer,sizeof cDebugStringBuffer , "[Harbour] Fcgi Init \n");  // https://en.cppreference.com/w/c/string/byte/strcpy  had to add the middle parameter
    OutputDebugString(cDebugStringBuffer);
    // signal(SIGTERM, handle_sigint);    // Signals not working in Apache and IIS
#endif
}

HB_FUNC( HB_FCGX_FINISH )
{
    FCGX_Finish();
}

HB_FUNC( HB_FCGI_GET_REQUEST_VARIABLES )   // Returns a Hash of all the Environment Variables set for the request. Is not the same as the EXE's environment variable.
{
    PHB_ITEM hbName;
    PHB_ITEM hbValue;
    PHB_ITEM attributes;
    
    char **RequestEnvironmentPointer = g_envp;

    char * PointerToSubstring;

    hbName     = hb_itemNew( NULL );
    hbValue    = hb_itemNew( NULL );
    attributes = hb_hashNew( NULL );

    hb_itemPutC( hbName, "Name1" );
    hb_itemPutC( hbValue, "Value1" );

    // OutputDebugString( "[Harbour] Envr Start\n");

    for ( ; *RequestEnvironmentPointer != NULL; RequestEnvironmentPointer++) {
        HB_SIZE nLen = strlen( *RequestEnvironmentPointer );
        HB_SIZE nPos = hb_strAt( "=", 1,*RequestEnvironmentPointer, nLen );
        if (nPos > 0) {
            // sprintf_s(cDebugStringBuffer, "[Harbour] %lld %lld %s\n", nLen, nPos, *RequestEnvironmentPointer);
            // OutputDebugString(cDebugStringBuffer);

            PointerToSubstring = *RequestEnvironmentPointer;
            hb_itemPutCL(hbName,PointerToSubstring,nPos-1);
            PointerToSubstring += nPos;
            hb_itemPutCL(hbValue,PointerToSubstring,nLen-nPos);
            hb_hashAdd( attributes, hbName, hbValue );
        }
    }
    hb_itemRelease( hbName );
    hb_itemRelease( hbValue );
    hb_itemReturnRelease( attributes ); 
}

HB_FUNC( HB_FCGX_OUTPUTDEBUGSTRING )   // For Windows Only
{

#ifdef _WIN32
	OutputDebugString( hb_parc(1) );
#endif

#ifdef unix

// setlogmask (LOG_UPTO (LOG_NOTICE));
// openlog ("harbour_fastcgi", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_LOCAL1);
// //syslog (LOG_NOTICE, "Program started by User %d", getuid ());
// syslog (LOG_INFO, "A tree falls in a forest");
// //syslog (LOG_NOTICE, "%s\n",hb_parc(1) );
// closelog ();

    openlog("Logs", LOG_NDELAY, LOG_DAEMON);
    // syslog(LOG_DEBUG, "Eric Eric Eric ...");
    syslog(LOG_DEBUG,"%s\n",hb_parc(1));
    closelog();

#endif

}

HB_FUNC( SET_AP_FILENAME )  // Used to assist the debugging of mod_harbour.exe
{
    // char * cParameterName;
    PHB_ITEM pPRGFullPath = hb_param( 1, HB_IT_ANY );
    if ( HB_IS_STRING( pPRGFullPath ))
    {
        HB_SIZE nLen = hb_itemGetCLen( pPRGFullPath );
        if (nLen < AP_FILENAMEMAXLENGTH)  //Ensure no overflow. Testing on less than to allow space for trailing chr(0)
        {
            hb_xmemcpy( cAP_FileName, hb_itemGetCPtr(pPRGFullPath), nLen+1 );   // +1 to also copy over the trailing chr(0)
        }
    }
}

HB_FUNC( AP_FILENAME )   // Used to assist the debugging of mod_harbour.exe
{
    hb_retc( cAP_FileName );
}
//=================================================================================================================
