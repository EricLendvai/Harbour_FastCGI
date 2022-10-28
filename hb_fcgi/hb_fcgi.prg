//Copyright (c) 2021 Eric Lendvai MIT License

#include "hb_fcgi.ch"

#include "fileio.ch"

// #define DEVELOPMENTMODE
// #ifdef DEVELOPMENTMODE
// #endif

class hb_Fcgi
    hidden:
        data   DefaultContentType         init "text/html; charset=UTF-8"
        data   ContentType                init ""

        data   LoadedRequestEnvironment   init .f.
        data   RequestEnvironment         init {=>}

        data   LoadedQueryString          init .f.
        data   QueryString                init {=>}   // Will be set to case insensitive keys

        data   LoadedRequestCookies       init .f.
        data   RequestCookies             init {=>}   // Will be set to case insensitive keys

        data   LoadedInput                init .f.
        data   Input                      init {=>}   //TODO  Hash with FieldName as Key, and an array as value. Array as follows: {nType(1=Field,2=File),cInputValue,cFileName,cContentType,Content}
        data   InputLength                init -1     // -1 Means not loaded
        data   InputRaw                   init ""
        method LoadInput()

        data   ReloadConfigAtEveryRequest init .f.
        data   AppConfig                  init {=>}   // Will be set to case insensitive keys
        method LoadAppConfig()

        data   RequestMethod              init ""
        data   ProcessingRequest          init .f.    // To determine if the :Finish() method should be called.

        data   ResponseHeader             init {=>}   //Using a hash in case the same header value is being set more than once
        data   OutputBuffer               init ""     //Needed since response header is before the actual response content
        method WriteOutput()                          //Write out the ResponseHeader and OutputBuffer

        data   OnErrorDetailLevel init 0              //See SetOnErrorDetailLevel() method
        data   OnErrorProgramInfo init ""             //See SetOnErrorProgramInfo() method

        data   aTrace                     init {}     //Used by methods TraceAdd and TraceList to assist development by displaying routines used to build response 
    exported:
        data   RequestCount               init 0    READONLY
        data   MaxRequestToProcess        init 0    READONLY
        data   FastCGIExeFullPath         init ""   READONLY
        method New() constructor
        method Wait()
        method Finish()                                // To mark page build. Happens automatically on next Wait() or OnError
        method ShutDownFastCGIEXEAfterResponse()       // To gracefully end the FastCGI Exe. Needed to release all classes for example
        method Print(...)
        method GetContentType()
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
        method GetHeaderValue(par_cName)
        method SetHeaderValue(par_cName,par_cValue)
        method GetCookieValue(par_cName)   // _M_ Not certain how can make a different regarding Paths
        method SetCookieValue(par_cName,par_cValue,par_nExpireDays,par_cPath)    // By default par_iExpireDays is 365. par_nExpireDays should be between 1 and 365
        method SetSessionCookieValue(par_cName,par_cValue,par_cPath)             // A session cookie, also called a transient cookie, is a cookie that is erased when you end the browser session.
        method DeleteCookie(par_cName,par_cPath)                            // Will delete regular and transient cookies by blanking their values and making cookies transient (will be removed when browser closes).
        method Redirect(par_cURL)                                           // Page Redirect via HTTP
        method GenerateRandomString(par_nLength,par_cPossibleChars)
        method SetOnErrorDetailLevel(par_Level)                                      //0 = "Error Occurred", 1 = "Minimum Debug Info", 2 = "Full Debug Info (not done yet)"
        method SetOnErrorProgramInfo(par_cInfo)                             // Used to include program name and build info for example
        method OnError(par_oError)
        method OnFirstRequest() inline nil
        method OnRequest()      inline nil
        method OnShutdown()     inline nil
        method ClearOutputBuffer() 
        method TraceAdd(par_cInfo)                //Add to the current request any text that can be listed later. Can be user to help developer find out where code should be updated.
        method TraceList(par_nListMethod)             //List the info added during multiple calls of TraceAdd. par_nListMethod: 1 = comma delimited, 2 = CR, 3 = <br>, 4 = ordered list

        data   OSPathSeparator            init hb_ps() READONLY
        data   PathBackend                init ""      READONLY   //Folder of FastCGI exe and any other run support files
        data   PathData                   init ""      READONLY   //Folder with Tables *Under Development*
        data   PathWebsite                init ""      READONLY   //website Folder
        data   PathSession                init ""      READONLY   //Folder of Session files
        data   RequestSettings            init {=>}    READONLY   //Used to assist parsing the Request URL aka Full URI (not the way apache defines URI, see https://en.wikipedia.org/wiki/Uniform_Resource_Identifier)
endclass

//-----------------------------------------------------------------------------------------------------------------
method SetOnErrorDetailLevel(par_Level) class hb_Fcgi
    ::OnErrorDetailLevel := min(2,max(0,par_Level))
return ::OnErrorDetailLevel
//-----------------------------------------------------------------------------------------------------------------
method SetOnErrorProgramInfo(par_cInfo) class hb_fcgi
    ::OnErrorProgramInfo := par_cInfo
return nil
//-----------------------------------------------------------------------------------------------------------------
method OnError(par_oError) class hb_Fcgi
    SendToDebugView("In hb_Fcgi:OnError")
    try
        ::OutputBuffer := ""  // To wipe out any built page content
        ::Print("<h1>Error Occurred</h1>")
        if ::OnErrorDetailLevel > 0
            if !empty(::OnErrorProgramInfo)
                ::Print("<h2>"+::OnErrorProgramInfo+"</h2>")
            endif
            ::Print("<h3>Error Date and Time: "+hb_TToC(hb_DateTime())+"</h3>")
            if ::OnErrorDetailLevel > 1
                ::Print("<div>"+FcgiGetErrorInfo(par_oError)+"</div>")
            endif
        endif
        ::Finish()
    catch
    endtry
    
    BREAK
return nil
//-----------------------------------------------------------------------------------------------------------------
method New() class hb_Fcgi
    local cRootPath
    local cAppValue

    ErrorBlock({|o|oFcgi:OnError(o)})

    hb_HCaseMatch(::QueryString,.f.)
    hb_HCaseMatch(::RequestCookies,.f.)
    hb_HCaseMatch(::AppConfig,.f.)

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

    static tRequestStartTime := NIL
    local tRequestEndTime
    
    if ::ProcessingRequest
        ::Finish()
    endif

    if ::MaxRequestToProcess > 0 .and. ::RequestCount >= ::MaxRequestToProcess
        //Reached Max Number of Requests to Process. This will happen after a page finished to build, and we are back in waiting request mode.
        lProcessRequest := .f.
    else
        if ::RequestCount > 0
            FcgiLogger(1)
            hb_gcAll()         //Since web apps have no inkey() or user input idle time, trigger the garbage collector.
        endif

        if !hb_IsNil(tRequestStartTime)
            tRequestEndTime := hb_DateTime()
            SendToDebugView("Response Build Time: "+trans((tRequestEndTime-tRequestStartTime)*(24*3600*1000))+" (ms)")
        endif

        if (iWaitResult := hb_Fcgx_Wait()) >= 0
            tRequestStartTime := hb_DateTime()
            ::ContentType              := ""
            ::LoadedRequestEnvironment := .f.
            ::LoadedQueryString        := .f.
            ::LoadedRequestCookies     := .f.
            ::LoadedInput              := .f.
    
            hb_HClear(::RequestEnvironment)
            hb_HClear(::QueryString)
            hb_HClear(::RequestCookies)
            hb_HClear(::Input)
            hb_HClear(::ResponseHeader)
            ::aTrace := {}

            ::OutputBuffer             := ""

            ::InputLength              := -1
            ::InputRaw                 := ""
    
            ::RequestMethod            := ""
    
            if ::ReloadConfigAtEveryRequest
                hb_HClear(::AppConfig)
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
    ::RequestSettings["ClientIP"]    := ::GetEnvironment("REMOTE_ADDR")

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
        ::WriteOutput()
        ::ProcessingRequest := .f.
        hb_Fcgx_Finish()
    endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method ShutDownFastCGIEXEAfterResponse() class hb_Fcgi
::MaxRequestToProcess := 1
::RequestCount++
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Print(...) class hb_Fcgi
    local nPCount
    for nPCount := 1 to pcount()
        if nPCount > 1
            ::OutputBuffer += " "
        endif
        ::OutputBuffer += hb_ValToStr(hb_PValue(nPCount)) //par_html
    endfor
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetContentType() class hb_Fcgi
return ::GetEnvironment("CONTENT_TYPE")
//-----------------------------------------------------------------------------------------------------------------
method SetContentType(par_type) class hb_Fcgi
    ::ContentType = par_type
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
    local cValue
    
    if !::LoadedRequestEnvironment
        ::RequestEnvironment := hb_Fcgi_Get_Request_Variables()
    endif
    for each cEnvironment in ::RequestEnvironment
        cValue := strtran(cEnvironment:__enumValue(),"%","&#37;")   // Not Certain why had to convert the % character
        cHtml += "<div>"+cEnvironment:__enumKey()+" - "+cValue+"</div>"
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
        ::LoadedQueryString := .t.
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
        
        // Used during development and debugging
        // SendToClipboard(::InputRaw)
        // hb_MemoWrit("R:\Harbour_websites\fcgi_mod_harbour\RequestHistory\request.txt",::InputRaw)   // To assist in debugging. 

        cContentType := ::GetContentType()

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
                cInput         := left(cInputBuffer,nPos-1)   //Will hold the entire content of the element
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
                                if len(cInput) > 2  //TEXTAREA (multi line entry). cInput would have whatever is after line3
                                    ::Input[cInputName] := {1,cLine3+CRLF+left(cInput,len(cInput)-2)}   // use cLine3 and Re-add the CRLF and add whatever is next. {Type = 1, cInputValue}
                                else
                                    ::Input[cInputName] := {1,cLine3}   // Removed the trailing CRLF. {Type = 1, cInputValue}
                                endif
                            endif
                        else
                            //Uploaded File
                            //Line 3 is empty. The file content start after line 3
                            if (left(cLine2,14) == "Content-Type: ")
                                cContentType := substr(cLine2,15)
                                //{nType = 2,"",cFileName,cContentType,Content}
                                //Had to remove the last to characters, since extra CRLF
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
// altd()
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
method GetHeaderValue(par_cName) class hb_Fcgi
return allt(::GetEnvironment("HTTP_"+upper(par_cName)))
//-----------------------------------------------------------------------------------------------------------------
method SetHeaderValue(par_cName,par_cValue) class hb_Fcgi
    ::ResponseHeader[par_cName] := par_cValue
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetCookieValue(par_cName)
    local cCookie
    local nPos
    if !::LoadedRequestCookies
        ::LoadedRequestCookies := .t.
        for each cCookie in hb_ATokens(::GetEnvironment("HTTP_COOKIE"),";",.f.,.f.)
            nPos := at("=",cCookie)
            if nPos > 1  // Name may not be empty
                ::RequestCookies[allt(left(cCookie,nPos-1))] := allt(substr(cCookie,nPos+1))
            endif
        endfor
    endif
return hb_HGetDef(::RequestCookies, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method SetCookieValue(par_cName,par_cValue,par_nExpireDays,par_cPath)
    //See  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
    //Will mark the cookie to expire 364 days from now and site root path
    local nExpireDays := hb_defaultValue(par_nExpireDays,365)
    local cPath       := hb_defaultValue(@par_cPath,"/")
    
    //Added the cookie name to the Header Name since using a Hash array
    ::SetHeaderValue("Set-Cookie~"+par_cName,par_cName+"="+par_cValue+;
                     iif(empty(nExpireDays),"","; Expires="+FcgiCookieTimeToExpires(hb_DateTime()+nExpireDays))+;
                     iif(empty(cPath),"","; Path="+cPath) )
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetSessionCookieValue(par_cName,par_cValue,par_cPath)
    //See  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
    //Will mark the cookie to expire 364 days from now and site root path
    local cPath       := hb_defaultValue(@par_cPath,"/")
    
    //Added the cookie name to the Header Name since using a Hash array
    ::SetHeaderValue("Set-Cookie~"+par_cName,par_cName+"="+par_cValue+;
                     iif(empty(cPath),"","; Path="+cPath) )
return NIL
//-----------------------------------------------------------------------------------------------------------------
method DeleteCookie(par_cName,par_cPath)
    //See  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
    //Will mark the cookie to expire 364 days from now and site root path
    local cPath       := hb_defaultValue(@par_cPath,"/")
    
    //Added the cookie name to the Header Name since using a Hash array
    ::SetHeaderValue("Set-Cookie~"+par_cName,par_cName+"="+;
                     "; Expires=0"+;
                     iif(empty(cPath),"","; Path="+cPath) )
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Redirect(par_cURL)
    ::SetHeaderValue("Status","303 OK")
    ::SetHeaderValue("Location",par_cURL)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method WriteOutput() class hb_Fcgi
    local cHeader
    local cHeaderName,cHeaderValue
    local nPos
    local nRedirected := 0

    hb_Fcgx_Print("Content-type: "+iif(empty(::ContentType),::DefaultContentType,::ContentType)+CRLF)
    for each cHeader in ::ResponseHeader
        cHeaderName  := cHeader:__enumKey()
        cHeaderValue := cHeader:__enumValue()
        do case
        case cHeaderName == "Location"
            nRedirected++
        case cHeaderName == "Status" .and. left(cHeaderValue,1) == "3"
            nRedirected++
        endcase
        nPos := at("~",cHeaderName)  // To handle multiple Set-Cookies header entries
        if nPos > 0
            cHeaderName := left(cHeaderName,nPos-1)
        endif
        hb_Fcgx_Print(cHeaderName+":"+cHeaderValue+CRLF)
    endfor
    hb_Fcgx_Print(CRLF)   //Extra CRLF to notify end of header
    if nRedirected < 2
        hb_Fcgx_Print(::OutputBuffer)
    // else
    //     SendToDebugView("WriteOutput - Dropped Output due to redirect")
    endif
    ::OutputBuffer = ""
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GenerateRandomString(par_nLength,par_cPossibleChars) class hb_Fcgi
    local cString := ""
    local nPossibleCharsLen := len(par_cPossibleChars)
    local nCounter
    for nCounter := 1 to par_nLength
        cString += chr(hb_BPeek(par_cPossibleChars,hb_RandomInt(1,nPossibleCharsLen)))
    endfor
return cString
//-----------------------------------------------------------------------------------------------------------------
method ClearOutputBuffer() class hb_Fcgi
    ::OutputBuffer := ""
return nil
//-----------------------------------------------------------------------------------------------------------------
method TraceAdd(par_cInfo) class hb_Fcgi
    Aadd(::aTrace,par_cInfo)
return nil
//-----------------------------------------------------------------------------------------------------------------
method TraceList(par_nListMethod) class hb_Fcgi
    local nLoop
    local cResult := []
    if len(::aTrace) > 0
        do case
        case par_nListMethod == 1   // Comma Delimited
            for nLoop := 1 to Len(::aTrace)
                if !empty(cResult)
                    cResult += ","
                endif
                cResult += ::aTrace[nLoop]
            endfor
        case par_nListMethod == 2   // CRLF
            for nLoop := 1 to Len(::aTrace)
                if !empty(cResult)
                    cResult += CRLF
                endif
                cResult += ::aTrace[nLoop]
            endfor
        case par_nListMethod == 3   // <br>
            for nLoop := 1 to Len(::aTrace)
                if !empty(cResult)
                    cResult += [<br>]
                endif
                cResult += ::aTrace[nLoop]
            endfor
        case par_nListMethod == 4   // <ol>
            cResult += [<ol>]
            for nLoop := 1 to Len(::aTrace)
                cResult += [<li>]+::aTrace[nLoop]+[</li>]
            endfor
            cResult += [</ol>]
        endcase
    endif
return cResult
//=================================================================================================================
function SendToDebugView(cStep,xValue)

#ifdef DEBUGVIEW

    local cTypeOfxValue
    local cValue := "Unknown Value"

// altd()

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

#endif

return .T.
//=================================================================================================================
function SendToClipboard(cText)
//#if defined(_WIN32) || defined(_WIN64)   // Will not work since this is a PRG So will use the DEBUGVIEW setting.

#ifdef CLIPBOARDSUPPORT
    wvt_SetClipboard(cText)
#endif

return .T.
//=================================================================================================================
function FcgiGetErrorInfo( oError,cCode ,nProgramStackStart)  //From mod_harbour <-> apache.prg

    local n
    local cInfo := "Error: " + oError:description + "<br>"
    local cProcname
    local aLines
    local nLine
    local lPrintedSourceHeader := .f.

    hb_default(@nProgramStackStart ,1)
    
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
        
    n = nProgramStackStart
    while .t.
        cProcname := upper(ProcName( n ))
        do case
        case empty(cProcname) .or. cProcname == "HB_HRBDO" 
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

    if ! Empty( cCode )
        aLines = hb_ATokens( cCode, Chr( 10 ) )
        n = 1
        nLine := 0
        while( nLine := ProcLine( ++n ) ) == 0   //The the line number in the last on the stack of programs
        end   
        if nLine > 0
            for n = Max( nLine - 2, 1 ) to Min( nLine + 2, Len( aLines ) )
                if !lPrintedSourceHeader
                    cInfo += "<br><b>Source:</b><br>"
                    lPrintedSourceHeader := .t.
                endif
                cInfo += "<nobr>"+StrZero( n, 5 ) + If( n == nLine, " =>", ": " ) + FcgiGetErrorInfo_HtmlEncode( aLines[ n ] ) + "</nobr><br>" //+ CRLF
            next
        endif
    endif      

 return cInfo

function FcgiGetErrorInfo_HtmlEncode( cString )
   
   local cChar, cResult := "" 

   for each cChar in cString
      do case
      case cChar == "<"
            cChar = "&lt;"

      case cChar == '>'
            cChar = "&gt;"     
            
      case cChar == "&"
            cChar = "&amp;"     

      case cChar == '"'
            cChar = "&quot;"    
            
      case cChar == " "
            cChar = "&nbsp;"               
      endcase
      cResult += cChar 
   next
    
return cResult   

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
//If the web application is also using the Harbour_VFP contrib define the compiler variable USING_HB_VFP to avoid object redefinition.
#ifndef USING_HB_VFP

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
function VFP_StrToFile(par_cExpression,par_cFileName,par_lAdditive)   //Partial implementation of VFP9's strtran(). The 3rd parameter only supports a logical

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

#endif //USING_HB_VFP
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
function FcgiLogger(par_nAction,par_cString,...)
//par_nAction, 1=Reset,2=Add Line,3=Append To Line,4=Save to File,5=Save to File and Reset
//par_cString, if par_nAction = 2 or 3 the text to send out, if par_nAction = 4 the full file name to write out.

static cBuffer := ""
local nPCount
local cCallBuffer
local nPos
// local nByte
local nChar

switch par_nAction
case 1  // Reset
    cBuffer := ""
    exit
case 2  // Add Line, same as ? <expr>
    if len(cBuffer) > 0
        cBuffer += chr(13)+chr(10)
    endif
case 3  // Append to Line, same as ?? <expr>
    for nPCount := 2 to pcount()
        if nPCount > 2
            cBuffer += " "
        endif
        cCallBuffer := hb_ValToStr(hb_PValue(nPCount))
        // for nPos := 1 to len(cCallBuffer)
        //     nByte := hb_BPeek(cCallBuffer,nPos)
        //     if nByte < 32 //.or. nByte > 126
        //         hb_BPoke(@cCallBuffer,nPos,63)   // to replace invalid html char with "?"
        //     endif
        // endfor

        for nPos := 1 to hb_utf8Len(cCallBuffer)
            nChar := hb_utf8Peek(cCallBuffer,nPos)
            if nChar < 32
                hb_utf8Poke(@cCallBuffer,nPos,hb_utf8Asc("?"))   // to replace invalid html char with "?"
            endif
        endfor

        cBuffer += cCallBuffer
    endfor
    exit
case 4
case 5
    vfp_StrToFile(cBuffer,par_cString)
    if par_nAction == 5
        cBuffer := ""
    endif
endswitch

return nil
//=================================================================================================================
function FcgiCookieTimeToExpires(tDateTime)
local cUTCGMT
local cDow
local dDate
local cMonth
local cTime := ""
// See https://stackoverflow.com/questions/11136372/which-date-formats-can-i-use-when-specifying-the-expiry-date-when-setting-a-cook
dDate = hb_TtoD(hb_TSToUTC(tDateTime),@cTime,"hh:mm:ss")
cDow   := {"Sun","Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}[dow(dDate)]
cMonth := {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}[Month(dDate)]

cUTCGMT := cDow + ", " + Trans(Day(dDate)) + " " + cMonth + " " + Trans(Year(dDate)) + " " + cTime + " GMT"

//  UTC/GMT format is required by cookies e.g. Sun, 15 Jul 2012 00:00:01 GMT

return cUTCGMT
//=================================================================================================================
