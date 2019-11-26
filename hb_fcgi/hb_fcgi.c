
static const char rcsid[] = "$Id: echo.c,v 1.5 2019/11/16 08:08:00 Eric Lendvai Exp $";

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

#define GETPID _getpid

#include <windows.h>

#include "hbapi.h"
#include "hbapiitm.h"
#include "hbapicdp.h"
#include "hbapierr.h"

#include <signal.h>

static char cDebugStringBuffer[255];

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

HB_FUNC( HB_FCGI_WAIT )
{
    int iReturn;
    iReturn = FCGX_Accept(&g_in, &g_out, &g_err, &g_envp);
    hb_retni(iReturn);
}

HB_FUNC( HB_FCGI_GETCONTENTLENGTH )
{
    int iInputLength = 0;
    char *contentLength = FCGX_GetParam("CONTENT_LENGTH", g_envp);
    if (contentLength != NULL)
            iInputLength = strtol(contentLength, NULL, 10);
    hb_retni( iInputLength );
}

HB_FUNC( HB_FCGI_GETINPUT )
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

HB_FUNC( HB_FCGI_GETPARAMETER )
{
    PHB_ITEM pParameterName = hb_param( 1, HB_IT_ANY );

    if( pParameterName && HB_IS_STRING( pParameterName ))
    {
        char *cParameterValue = FCGX_GetParam(hb_itemGetCPtr(pParameterName), g_envp);

        if (cParameterValue != NULL) {
            hb_retc(cParameterValue);
        } else {
            hb_retc_null();
        }
    } else {
        hb_retc_null();
    }
}

HB_FUNC( HB_FCGI_CONTENTTYPE )
{
    FCGX_FPrintF(g_out, hb_parc( 1 ) );
    FCGX_FPrintF(g_out, "\r\n\r\n");
}

HB_FUNC( HB_FCGI_PRINT )
{
    int iResult ;

    if( HB_ISCHAR( 1 ) )
    {
    	FCGX_FPrintF(g_out, hb_parc( 1 ) );
        iResult = 1;
    } else {
        iResult = -1;
    }
	
    hb_retni( iResult );
}

HB_FUNC( HB_FCGI_PRINTENVIRONMENT )
{
    PrintEnv(g_out, "Request environment", g_envp);
    PrintEnv(g_out, "Initial environment", environ);

    hb_retni(0);
}

HB_FUNC( HB_FCGI_FINISH )
{
    FCGX_Finish();
}

HB_FUNC( OUTPUTDEBUGSTRING )
{
	OutputDebugString( hb_parc(1) );
}
//=================================================================================================================
