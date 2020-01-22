//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_fcgi.ch"

#include "fileio.ch"

// #define DEVELOPMENTMODE
// #ifdef DEVELOPMENTMODE
// #endif

class hb_Fcgi
    hidden:
        data   DefaultContentType         init "Content-type: text/html; charset=UTF-8"
        data   TransmittedContentType     init ""

        data   LoadedRequestEnvironment   init .f.
        data   RequestEnvironment         init {=>}

        data   LoadedQueryString          init .f.
        data   QueryString                init {=>}   // Will be set to case insensitive keys

        data   LoadedInput                init .f.
        data   Input                      init {=>}   //TODO  Hash with FieldName as Key, and an array as value. Array as follows: {nType(1=Field,2=File),cInputValue,cFileName,cContentType,Content}
        data   InputLength                init -1     // -1 Means not loaded
        data   InputRaw                   init ""
        method LoadInput()

        data   LoadedHeader               init .f.    // TODO
        data   Header                     init {=>}

        data   ReloadConfigAtEveryRequest init .f.
        data   AppConfig                  init {=>}   // Will be set to case insensitive keys
        method LoadAppConfig()

        data   RequestMethod              init ""
        data   ProcessingRequest          init .f.    // To determine if the :Finish() method should be called.

    exported:
        data   RequestCount               init 0    READONLY
        data   MaxRequestToProcess        init 0    READONLY
        data   FastCGIExeFullPath         init ""   READONLY
        method New() constructor
        method Wait()
        method Finish()                                // To mark page build. Happens automatically on next Wait() or OnError
        method Print(par_html)
        method SetContentType(par_type)
        method GetEnvironment(par_cName)               // Web Server (Type) Specific Environment
        method ListEnvironment()                       // Just to assist development
        method GetAppConfig(par_cName)
        method GetQueryString(par_cName)
        method GetInputLength()
        method GetRawInput()                           // To be only available during development
        method GetInputValue(par_cName)
        method GetInputFileName(par_cName)
        method GetInputFileContentType(par_cName)
        method GetInputFileContent(par_cName)
        method SaveInputFileContent(par_cName,par_cFileFullPath)
        method IsGet()                              SETGET   //Used to query if the page was sent as a GET request
        method IsPost()                             SETGET   //Used to query if the page was sent as a POST request
        //_M_ method GetHeader(cName)  // TODO

        method OnError(par_oError)
        method OnFirstRequest() inline nil
        method OnShutdown()     inline nil

        data   OSPathSeparator            init hb_ps() READONLY
        data   PathBackend                init ""      READONLY   //Folder of FastCGI exe and any other run support files
        data   PathData                   init ""      READONLY   //Folder with Tables *Under Development*
        data   PathWebsite                init ""      READONLY   //website Folder
        data   PathSession                init ""      READONLY   //Folder of Session files
        data   RequestSettings            init {=>}    READONLY   //Used to assist parsing the Request URL aka Full URI (not the way apache defines URI, see https://en.wikipedia.org/wiki/Uniform_Resource_Identifier)
endclass

//-----------------------------------------------------------------------------------------------------------------

method OnError(par_oError) class hb_Fcgi
    SendToDebugView("In hb_Fcgi:OnError")
    try
        oFcgi:Print(FcgiGetErrorInfo(par_oError))
        oFcgi:Finish()
    catch
    endtry
    
    BREAK
return nil
//-----------------------------------------------------------------------------------------------------------------
method New() class hb_Fcgi
    local cRootPath
    local cAppValue

    ErrorBlock({|o|oFcgi:OnError(o)})

    hb_hSetCaseMatch(::QueryString,.f.)
    hb_hSetCaseMatch(::AppConfig,.f.)

    // hb_hSetOrder(::RequestEnvironment,.f.)  Does not seem to work
    ::FastCGIExeFullPath := hb_argV(0)
    cRootPath := left(::FastCGIExeFullPath,rat(::OSPathSeparator,::FastCGIExeFullPath)-1)
    cRootPath := left(cRootPath,rat(::OSPathSeparator,cRootPath))

    ::PathBackend := cRootPath+"backend"+::OSPathSeparator
    ::PathWebsite := cRootPath+"website"+::OSPathSeparator
    
    ::LoadAppConfig()

    cAppValue := ::GetAppConfig("PathData")
    if empty(cAppValue)
        ::PathData    := cRootPath+"data"+::OSPathSeparator     //Default Location
    else
        ::PathData    := hb_DirSepAdd(cAppValue)
    endif

    cAppValue := ::GetAppConfig("PathSession")
    if empty(cAppValue)
        ::PathSession := cRootPath+"session"+::OSPathSeparator  //Default Location
    else
        ::PathSession := hb_DirSepAdd(cAppValue)
    endif

    hb_Fcgx_Init()

    set exact on
    
return Self
//-----------------------------------------------------------------------------------------------------------------
method Wait() class hb_Fcgi
    //Used to wait for the next page request
    local lProcessRequest      //If web page should be built
    // local cREQUEST_URI
    local iWaitResult
    local cDownFileName
    local cSitePath
    local cPath
    local cPage
    local nPos
    
    if ::ProcessingRequest
        ::Finish()
    endif

    if ::MaxRequestToProcess > 0 .and. ::RequestCount >= ::MaxRequestToProcess
        //Reached Max Number of Requests to Process. This will happen after a page finished to build, and we are back in waiting request mode.
        lProcessRequest := .f.
    else
        if ::RequestCount > 0
            hb_gcAll()         //Since web apps have no inkey() or user input idle time, trigger the garbage collector.
        endif

        if (iWaitResult := hb_Fcgx_Wait()) >= 0
            ::TransmittedContentType   := ""
            ::LoadedRequestEnvironment := .f.
            ::LoadedQueryString        := .f.
            ::LoadedInput              := .f.
            ::LoadedHeader             := .f.
    
            hb_HClear(::RequestEnvironment)
            hb_HClear(::QueryString)
            hb_HClear(::Input)
            hb_HClear(::Header)
            
            ::InputLength              := -1
            ::InputRaw                 := ""
    
            ::RequestMethod           := ""
    
            if ::ReloadConfigAtEveryRequest
                ::LoadAppConfig()
            endif
    
            // cREQUEST_URI := ::GetEnvironment("REQUEST_URI")
            // SendToDebugView("cREQUEST_URI",cREQUEST_URI)

            if file(left(::FastCGIExeFullPath,len(::FastCGIExeFullPath)-3)+"kill")
                // altd()
                cDownFileName = ::PathWebsite+"down.html"
                if file(cDownFileName)
                    ::Print(hb_MemoRead(cDownFileName))
                else
                    ::Print([Site is down. Add a "down.html" file.])
                endif
                lProcessRequest := .f.
                ::ProcessingRequest := .t. //Since issued ::Print()
                ::Finish()
            else
                ::RequestCount++
                lProcessRequest := .t.
            endif
    
        else
            // Add code to log why the wait failed. Use the variable iWaitResult
            if iWaitResult == 0 //To full the compiler. It will be used later.
            endif

            lProcessRequest := .f.
        endif
    endif

    ::ProcessingRequest = lProcessRequest

    // Initialize ::URIInfo To provide easy access to 
    cSitePath := ::GetEnvironment("CONTEXT_PREFIX")
    if len(cSitePath) == 0
        cSitePath := "/"
    endif

    cPath := substr(::GetEnvironment("REDIRECT_URL"),len(cSitePath)+1)
    nPos  := hb_RAt("/",cPath)
    cPage := substr(cPath,nPos+1)
    if cPage == "default.html"
        cPage := ""  //Work Around the behaviour of Apache's work around to deal with root file access
    endif
    cPath := left(cPath,nPos)

    ::RequestSettings["Protocol"]    := ::GetEnvironment("REQUEST_SCHEME")
    ::RequestSettings["Port"]        := val(::GetEnvironment("SERVER_PORT"))
    ::RequestSettings["Host"]        := ::GetEnvironment("SERVER_NAME")
    ::RequestSettings["SitePath"]    := cSitePath
    ::RequestSettings["Path"]        := cPath
    ::RequestSettings["Page"]        := cPage
    ::RequestSettings["QueryString"] := ::GetEnvironment("REDIRECT_QUERY_STRING")
    ::RequestSettings["WebServerIP"] := ::GetEnvironment("SERVER_ADDR")
    ::RequestSettings["ClienIP"]     := ::GetEnvironment("REMOTE_ADDR")

    if ::ProcessingRequest
        if ::RequestCount == 1
            ::OnFirstRequest()
        endif
    else
        if ::RequestCount > 0
            ::OnShutdown()
        endif
    endif

return lProcessRequest
//-----------------------------------------------------------------------------------------------------------------
method Finish() class hb_Fcgi
    if ::ProcessingRequest
        ::ProcessingRequest := .f.
        hb_Fcgx_Finish()
    endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Print(par_html) class hb_Fcgi
    if empty(::TransmittedContentType)
        ::SetContentType(::DefaultContentType)
    endif
    hb_Fcgx_Print(par_html)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetContentType(par_type) class hb_Fcgi
    if empty(::TransmittedContentType) //Technique used to ensure the type is not resent
        hb_Fcgx_ContentType(par_type)
        ::TransmittedContentType := par_type
    endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetEnvironment(par_cName) class hb_Fcgi
    if !::LoadedRequestEnvironment
        ::RequestEnvironment := hb_Fcgi_Get_Request_Variables()
    endif
return hb_HGetDef(::RequestEnvironment, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method ListEnvironment() class hb_Fcgi
    local cEnvironment
    local cHtml := ""
    
    if !::LoadedRequestEnvironment
        ::RequestEnvironment := hb_Fcgi_Get_Request_Variables()
    endif
    for each cEnvironment in ::RequestEnvironment
        cHtml += "<div>"+cEnvironment:__enumKey()+" - "+cEnvironment:__enumValue()+"</div>"
    endfor
return cHtml
//-----------------------------------------------------------------------------------------------------------------
method GetAppConfig(par_cName) class hb_Fcgi
return hb_HGetDef(::AppConfig, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method GetQueryString(par_cName) class hb_Fcgi
    local cParameter
    local nPos
    if !::LoadedQueryString
        // Important: It seems that under IIS if have parameters like   "name1=val1&name2=val2"  it get converted name not repeating "name" and just having the number. More research needed here.
        for each cParameter in hb_ATokens(::GetEnvironment("QUERY_STRING"),"&",.f.,.f.)
            nPos := at("=",cParameter)
            if nPos > 1  // Name may not be empty
                ::QueryString[left(cParameter,nPos-1)] := substr(cParameter,nPos+1)
            endif
        endfor
    endif
return hb_HGetDef(::QueryString, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method LoadInput() class hb_Fcgi
    local cInput
    local nPos
    local cContentType
    local cMultiFormBoundary
    local nMultiFormBoundaryLen
    local cInputBuffer
    local cLine1,cLine2,cLine3
    local lFoundAllLines
    local cInputName
    local cFileName
    local cToken
    local lFoundFormData

    if !::LoadedInput
        ::LoadedInput := .t.
        ::InputRaw := hb_Fcgx_GetInput(::GetInputLength())  //Will return a buffer that could have chr(0) in it
        // SendToClipboard(::InputRaw)  // Used during testing
        // hb_MemoWrit("R:\Harbour_websites\fcgi_mod_harbour\RequestHistory\request.txt",::InputRaw)   // To assist in debugging. 

        cContentType := ::GetEnvironment("CONTENT_TYPE")

        do case
        case cContentType == "application/x-www-form-urlencoded"
            for each cInput in hb_ATokens(::InputRaw,"&",.f.,.f.)
                nPos := at("=",cInput)
                if nPos > 1  // Name may not be empty
                    ::Input[left(cInput,nPos-1)] := {1,substr(cInput,nPos+1)}
                endif
            endfor
        
        case left(cContentType,19) == "multipart/form-data"
            cInputBuffer          := ::InputRaw
            nPos                  := at(CRLF,cInputBuffer)
            cMultiFormBoundary    := left(cInputBuffer,nPos-1)
            nMultiFormBoundaryLen := len(cMultiFormBoundary)
            cInputBuffer          := substr(cInputBuffer,nPos+2)

            do while ((nPos := at(cMultiFormBoundary,cInputBuffer)) > 0)
                cInput         := left(cInputBuffer,nPos-1)
                cInputBuffer   := substr(cInputBuffer,nPos+nMultiFormBoundaryLen)
                cLine1         := ""
                cLine2         := ""
                cLine3         := ""
                
                lFoundAllLines := .f.
                if !empty(cInput)
                    // Pop First 3 Lines   Should always have 3 lines
                    nPos := at(CRLF,cInput)
                    if nPos > 0
                        cLine1 := left(cInput,nPos-1)
                        cInput := substr(cInput,nPos+2)
                        nPos := at(CRLF,cInput)
                        if nPos > 0
                            cLine2 := left(cInput,nPos-1)
                            cInput := substr(cInput,nPos+2)
                            nPos := at(CRLF,cInput)
                            if nPos > 0
                                cLine3 := left(cInput,nPos-1)
                                cInput := substr(cInput,nPos+2)
                                lFoundAllLines := .t.
                            endif
                        endif
                    endif
                    if lFoundAllLines
                        lFoundFormData := .f.
                        cInputName     := ""
                        cFileName      := ""
                        // cContentType   := ""

                        //Process Line 1
                        for each cToken in hb_ATokens(cLine1,";",.f.,.f.)
                            if cToken == "Content-Disposition: form-data"
                                lFoundFormData := .t.
                                loop
                            else
                                if (nPos := at("=",cToken)) > 0
                                    if left(cToken,nPos-1) == " name"
                                        cInputName = strtran(substr(cToken,nPos+1),["],[])
                                    elseif left(cToken,nPos-1) == " filename"
                                        cFileName = strtran(substr(cToken,nPos+1),["],[])
                                    endif
                                endif
                            endif
                        endfor

                        if lFoundFormData .and. empty(cFileName)
                            //Regular Input Field
                            if !empty(cInputName)
                                ::Input[cInputName] := {1,cLine3}   // Have to remove the trailing CRTL. {Type = 1, cInputValue}
                            endif
                        else
                            //Uploaded File
                            if (left(cLine2,14) == "Content-Type: ")
                                cContentType := substr(cLine2,15)
                                //{nType = 2,"",cFileName,cContentType,Content}
                                ::Input[iif(!empty(cInputName),cInputName,cFileName)] := {2,"",cFileName,cContentType,left(cInput,len(cInput)-2)}
                            else
                                SendToDebugView("Bad Request multipart format - error 3")
                                loop
                            endif
                        endif

                    else
                        SendToDebugView("Bad Request multipart format - error 2")
                        loop
                    endif

                endif

                if left(cInputBuffer,2) == "--"
                    exit
                elseif left(cInputBuffer,2) == CRLF
                    cInputBuffer = substr(cInputBuffer,3)
                else
                    //This should not Happen!!!
                    SendToDebugView("Bad Request multipart format - error 1")
                    exit
                endif
            enddo

        otherwise
            
        endcase

    endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetRawInput() class hb_Fcgi
    if !::LoadedInput
        ::LoadInput()
    endif
return ::InputRaw
//-----------------------------------------------------------------------------------------------------------------
method GetInputValue(par_cName) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_cName, {1,""})
return aResult[2]
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileName(par_cName) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_cName, {1,""})
return iif(aResult[1]=2,aResult[3],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileContentType(par_cName) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_cName, {1,""})
return iif(aResult[1]=2,aResult[4],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileContent(par_cName) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_cName, {1,""})
return iif(aResult[1]=2,aResult[5],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method SaveInputFileContent(par_cName,par_cFileFullPath) class hb_Fcgi
    local aResult
    local lResult := .f.
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_cName, {1,""})
    try 
        hb_MemoWrit(par_cFileFullPath,iif(aResult[1]=2,aResult[5],""))
        lResult := .t.
    catch
    endtry
return lResult  // .t. if content was saved to file
//-----------------------------------------------------------------------------------------------------------------
method LoadAppConfig() class hb_Fcgi
    local cConfigText
    local cLine
    local nPos
    local cName
    local cValue
    local iNumberOfConfigs := 0
    //The configuration file is purposely not with a .txt extension to block users from accessing it.
    cConfigText := hb_MemoRead(::PathBackend+"config.txt")
    cConfigText := StrTran(StrTran(cConfigText,chr(13)+chr(10),chr(10)),chr(13),chr(10))
    for each cLine in hb_ATokens(cConfigText,chr(10),.f.,.f.)
        nPos := at("=",cLine)
        if nPos > 1  //Name may not be empty
            cName := left(cLine,nPos-1)
            cLine := substr(cLine,nPos+1)
            nPos := rat("//",cLine)
            if empty(nPos)
                cValue := allt(cLine)
            else
                cValue := allt(left(cLine,nPos-1))
            endif
            ::AppConfig[cName] := cValue
            iNumberOfConfigs++
        endif
    endfor
    ::MaxRequestToProcess        := val(hb_HGetDef(::AppConfig,"MaxRequestPerFCGIProcess","0"))
    ::ReloadConfigAtEveryRequest := (hb_HGetDef(::AppConfig,"ReloadConfigAtEveryRequest","false") == "true")
    // Altd()
return iNumberOfConfigs
//-----------------------------------------------------------------------------------------------------------------
method GetInputLength() class hb_Fcgi
    if ::InputLength < 0
        ::InputLength := val(::GetEnvironment("CONTENT_LENGTH"))
    endif
return ::InputLength
//-----------------------------------------------------------------------------------------------------------------
method IsGet() class hb_Fcgi
    if empty(::RequestMethod)
        ::RequestMethod := ::GetEnvironment("REQUEST_METHOD")
    endif
return (::RequestMethod == "GET")
//-----------------------------------------------------------------------------------------------------------------
method IsPost() class hb_Fcgi
    if empty(::RequestMethod)
        ::RequestMethod := ::GetEnvironment("REQUEST_METHOD")
    endif
return (::RequestMethod == "POST")
//-----------------------------------------------------------------------------------------------------------------
//=================================================================================================================
function SendToDebugView(cStep,xValue)
    local cTypeOfxValue
    local cValue := "Unknown Value"
    
    cTypeOfxValue = ValType(xValue)
    
    do case
    case pcount() < 2
        cValue := ""
    case cTypeOfxValue $ "AH" // Array or Hash
        cValue := hb_ValToExp(xValue)
    case cTypeOfxValue == "B" // Block
        //Not coded yet
    case cTypeOfxValue == "C" // Character (string)
        cValue := xValue
        //Not coded yet
    case cTypeOfxValue == "D" // Date
        cValue := DTOC(xValue)
    case cTypeOfxValue == "L" // Logical
        cValue := IIF(xValue,"True","False")
    case cTypeOfxValue == "M" // Memo
        //Not coded yet
    case cTypeOfxValue == "N" // Numeric
        cValue := alltrim(str(xValue))
    case cTypeOfxValue == "O" // Object
        //Not coded yet
    case cTypeOfxValue == "P" // Pointer
        //Not coded yet
    case cTypeOfxValue == "S" // Symbol
        //Not coded yet
    case cTypeOfxValue == "U" // NIL
        cValue := "Null"
    endcase
    
    if empty(cValue)
        hb_Fcgx_OutputDebugString("[Harbour] "+cStep)
    else
        hb_Fcgx_OutputDebugString("[Harbour] "+cStep+" - "+cValue)
    endif
    
return .T.
//=================================================================================================================
function SendToClipboard(cText)
    wvt_SetClipboard(cText)
return .T.
//=================================================================================================================
function FcgiGetErrorInfo( oError )  //From mod_harbour <-> apache.prg

    local n, cInfo := "Error: " + oError:description + "<br>"
    local cProcname
    if ! Empty( oError:operation )
        cInfo += "operation: " + oError:operation + "<br>"
    endif   

    if ! Empty( oError:filename )
        cInfo += "filename: " + oError:filename + "<br>"
    endif   

    if ValType( oError:Args ) == "A"
        for n = 1 to Len( oError:Args )
            cInfo += "[" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                    "   " + FcgiValToChar( oError:Args[ n ] ) + "<br>"
        next
    endif	
        
    n = 1
    while .t.
        cProcname := upper(ProcName( n ))
        do case
        case empty(cProcname)
            exit
        case right(cProcname,8) == ":ONERROR"
        case cProcname == "ERRORBLOCKCODE"  
        case right(cProcname,10) == "__DBGENTRY"
        case right(cProcname,11) == "HB_FCGI_NEW"
        otherwise
            cInfo += "Called From: " + If( ! Empty( ProcFile( n ) ), ProcFile( n ) + ", ", "" ) + cProcname + ", line: " + AllTrim( Str( ProcLine( n ) ) ) + "<br>"
        endcase
        n++
    end

 return cInfo
//=================================================================================================================
function FcgiValToChar( u )  //Adapted From mod_harbour <-> apache.prg
    local cResult
 
    switch ValType( u )
        case "C"
            cResult = u
            exit
        case "D"
            cResult = DToC( u )
            exit
        case "L"
            cResult = If( u, ".T.", ".F." )
            exit
        case "N"
            cResult = AllTrim( Str( u ) )
            exit
        case "A"
            cResult = hb_ValToExp( u )
            exit
        case "P"
            cResult = "(P)" 
            exit
        case "H"
            cResult = hb_ValToExp( u )
            exit
        case "U"
            cResult = "nil"
            exit
        otherwise
            cResult = "type not supported yet in function ValToChar()"
    endswitch
 
 return cResult   
//=================================================================================================================
function FcgiPrepFieldForValue( par_FieldValue ) 
// for now calling vfp_StrReplace, which is case insensitive ready version of hb_StrReplace
return vfp_StrReplace(par_FieldValue,{;
                                        [&lt;] => [&amp;lt;] ,;
                                        [&gt;] => [&amp;gt;] ,;
                                        ["]    => [&quot;]   ,;
                                        [<]    => [&lt;]     ,;
                                        [>]    => [&gt;]     ,;
                                        chr(9) => [&#9;]      ;
                                     },,1)
//=================================================================================================================
//The VFP_ScanStack is to be used in conjuntion with the "#command SCAN" and "#command ENDSCAN"
function VFP_ScanStack(par_action)    //action = "push" "pop" "scan" , "clear" (empty the entire stack)
local xResult := nil
static iTop   := 0
static aStack := {}

hb_default( @par_action, "scan" )

switch par_action
    case "push"
        iTop++
        if len(aStack) < iTop
            ASize( aStack, iTop )
        endif
        aStack[iTop] := {select(),.t.} // Record the current work area and flag to know during "scan" calls if they are going to be the initial "locate" or should be "continue"
        xResult := nil
        exit
    case "pop"
        iTop--
        //No need to reduce the size of aStack since will most likely be increased again
        exit
    case "clear"
        iTop   := 0
        ASize( aStack, 0 )
        exit
    otherwise
        select (aStack[iTop,1])
        xResult := aStack[iTop,2]
        aStack[iTop,2] := .f.
        exit
endswitch

return xResult
//=================================================================================================================
function vfp_StrToFile(par_cExpression,par_cFileName,par_lAdditive)   //Partial implementation of VFP9's strtran(). The 3rd parameter only supports a logical

local lAdditive
local nBytesWritten := 0
local nFileHandle

lAdditive := hb_defaultValue(par_lAdditive,.f.)

if hb_FileExists(par_cFileName)
    if lAdditive
        nFileHandle := FOpen(par_cFileName,FO_WRITE)
        FSeek(nFileHandle,0,FS_END)  // go to the end of file
    else
        if ferase(par_cFileName) == 0
            nFileHandle := FCreate(par_cFileName)
        else
            nFileHandle := -1
        endif
    endif
else
    nFileHandle := FCreate(par_cFileName)
endif

if nFileHandle >= 0
    nBytesWritten := fwrite(nFileHandle,par_cExpression)
    fclose(nFileHandle)
endif

return nBytesWritten
//=================================================================================================================
//The following a modified version of the "uhttpd_URLDecode" function from extras\httpsrv\_cgifunc.prg   Copyright 2009 Francesco Saverio Giudice <info / at / fsgiudice.com>
//under the terms of the GNU General Public License as published by * the Free Software Foundation; either version 2, or (at your option) * any later version.

function DecodeURIComponent(par_cString)

#ifdef HB_USE_HBTIP
	RETURN TIPENCODERURL_DECODE( par_cString )
#else
    local cRet := ""
    local i
    local cChar

	FOR i := 1 TO Len( par_cString )
		cChar := SubStr( par_cString, i, 1 )
		DO CASE
		CASE cChar == "+"
			cRet += " "

		CASE cChar == "%"
			i++
			cRet += Chr( hb_HexToNum( SubStr( par_cString, i, 2 ) ) )
			i++

		OTHERWISE
			cRet += cChar

		ENDCASE

	NEXT

	return cRet
#endif

//=================================================================================================================
//The following a modified version of the "uhttpd_URLEncode" function from extras\httpsrv\_cgifunc.prg   Copyright 2009 Francesco Saverio Giudice <info / at / fsgiudice.com>
//under the terms of the GNU General Public License as published by * the Free Software Foundation; either version 2, or (at your option) * any later version.

function EncodeURIComponent(par_cString,par_lComplete)

#ifdef HB_USE_HBTIP

	__defaultNIL( @par_lComplete, .T. )

	RETURN TIPENCODERURL_ENCODE( cpar_cStringString, par_lComplete )
#else
	local cRet := "", i, nVal, cChar

	__defaultNIL( @par_lComplete, .T. )

	for i := 1 to Len( par_cString )
		cChar := SubStr( par_cString, i, 1 )
		DO CASE
		CASE cChar == " "
			cRet += "+"

		CASE ( cChar >= "A" .AND. cChar <= "Z" ) .OR. ;
				( cChar >= "a" .AND. cChar <= "z" ) .OR. ;
				( cChar >= "0" .AND. cChar <= "9" ) .OR. ;
				cChar == "." .OR. cChar == "," .OR. cChar == "&" .OR. ;
				cChar == "/" .OR. cChar == ";" .OR. cChar == "_"
			cRet += cChar

		CASE iif( ! par_lComplete, cChar == ":" .OR. cChar == "?" .OR. cChar == "=", .F. )
			cRet += cChar

		OTHERWISE
			nVal := Asc( cChar )
			cRet += "%" + hb_NumToHex( nVal )
		ENDCASE
	NEXT

	RETURN cRet
//=================================================================================================================
