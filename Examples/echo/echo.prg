
#xcommand TRY => BEGIN SEQUENCE WITH __BreakBlock()
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS
#xcommand ENDTRY => END
#xcommand ENDDO => END
#xcommand ENDFOR => END

#xtranslate Allt( <x> )    => alltrim( <x> )
#xtranslate Trans( <x> )    => alltrim( str(<x>,10) )


Function Main()

local iRequestID
local iRequestCount := 0
local iInputLength := 0
local cInput := ""
local cQUERY_STRING := ""
local cVar

OutputDebugString("[Harbour] Starting echox")

altd()

do while .t. 
    iRequestID = hb_Fcgi_Wait()

    OutputDebugString("[Harbour] iRequestID = "+Trans(iRequestID))

    if iRequestID < 0
        exit
    endif

    iRequestCount++

    altd()

    hb_Fcgi_ContentType("Content-type: text/html")

    hb_Fcgi_Print("<h1>FastCGI echox prg MSVC 2019 - 11/26/20191 001 </h1>")
    
    hb_Fcgi_Print("<p>Request Count = "+Trans( iRequestCount )+"</p>")

    iInputLength := hb_Fcgi_GetContentLength()
    hb_Fcgi_Print("<p>Input Length = "+Trans( iInputLength )+"</p>")

    cQUERY_STRING := hb_Fcgi_GetParameter("QUERY_STRING")
    hb_Fcgi_Print("<p>QUERY_STRING = "+cQUERY_STRING+"</p>")

    cInput := HB_FCGI_GETINPUT(iInputLength)
    hb_Fcgi_Print("<p>INPUT = "+cInput+"</p>")

    hb_Fcgi_PrintEnvironment()

    HB_FCGI_FINISH()
end

OutputDebugString("[Harbour] Done\n")

return nil

//=================================================================================================================
//=================================================================================================================
