//Copyright (c) 2023 Eric Lendvai MIT License

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
        data   xJsonInput                 init {=>}   //The Json input for APIs when "Content-Type" is set to "application/json". Could be an Array of Hash Array
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
        data   p_hb_fcgi_version          init HB_FCGI_BUILDVERSION READONLY
        data   RequestCount               init 0                    READONLY
        data   MaxRequestToProcess        init 0                    READONLY
        data   FastCGIExeFullPath         init ""                   READONLY

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
        method GetRawInput()                           // To be only available during development or for creating logs
        method GetJsonInput()
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
        data   SkipRequest                init .f.     READONLY   //Set in the wait() method to skip resource files
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
local l_cRootPath
local l_cAppValue

ErrorBlock({|o|oFcgi:OnError(o)})

hb_HCaseMatch(::QueryString,.f.)
hb_HCaseMatch(::RequestCookies,.f.)
hb_HCaseMatch(::AppConfig,.f.)

// hb_hSetOrder(::RequestEnvironment,.f.)  Does not seem to work
::FastCGIExeFullPath := hb_argV(0)
l_cRootPath := left(::FastCGIExeFullPath,rat(::OSPathSeparator,::FastCGIExeFullPath)-1)
l_cRootPath := left(l_cRootPath,rat(::OSPathSeparator,l_cRootPath))

::PathBackend := l_cRootPath+"backend"+::OSPathSeparator
::PathWebsite := l_cRootPath+"website"+::OSPathSeparator

::LoadAppConfig()

l_cAppValue := ::GetAppConfig("PathData")
if empty(l_cAppValue)
    ::PathData    := l_cRootPath+"data"+::OSPathSeparator     //Default Location
else
    ::PathData    := hb_DirSepAdd(l_cAppValue)
endif

l_cAppValue := ::GetAppConfig("PathSession")
if empty(l_cAppValue)
    ::PathSession := l_cRootPath+"session"+::OSPathSeparator  //Default Location
else
    ::PathSession := hb_DirSepAdd(l_cAppValue)
endif

hb_Fcgx_Init()

set exact on

return Self
//-----------------------------------------------------------------------------------------------------------------
method Wait() class hb_Fcgi
//Used to wait for the next page request 
local l_lProcessRequest      //If web page should be built
// local cREQUEST_URI
local l_iWaitResult
local l_cDownFileName
local l_cSitePath
local l_cPath
local l_cPage
local l_nPos

static tRequestStartTime := NIL
local tRequestEndTime

::SkipRequest := .f.

if ::ProcessingRequest  //We send the output when we come back into the main loop, and before we go in hb_Fcgx_Wait() mode
    ::Finish()
endif

if ::MaxRequestToProcess > 0 .and. ::RequestCount >= ::MaxRequestToProcess
    //Reached Max Number of Requests to Process. This will happen after a page finished to build, and we are back in waiting request mode.
    l_lProcessRequest := .f.
else
    if ::RequestCount > 0
        FcgiLogger(1)
        hb_gcAll()         //Since web apps have no inkey() or user input idle time, trigger the garbage collector.
    endif

    if !hb_IsNil(tRequestStartTime)
        tRequestEndTime := hb_DateTime()
        SendToDebugView("Response Build Time: "+trans((tRequestEndTime-tRequestStartTime)*(24*3600*1000))+" (ms)")
    endif

    if (l_iWaitResult := hb_Fcgx_Wait()) >= 0
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

        do case
        case ValType(::xJsonInput) == "A"
            ASize(::xJsonInput,0)
            ::xJsonInput := {=>}
        case ValType(::xJsonInput) == "H"
            hb_HClear(::xJsonInput)
        otherwise
            ::xJsonInput := {=>}
        endcase

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
            l_cDownFileName = ::PathWebsite+"down.html"
            if file(l_cDownFileName)
                ::Print(hb_MemoRead(l_cDownFileName))
            else
                ::Print([Site is down. Add a "down.html" file.])
            endif
            l_lProcessRequest := .f.
            ::ProcessingRequest := .t. //Since issued ::Print()
            ::Finish()
        else
            ::RequestCount++
            l_lProcessRequest := .t.
        endif

    else
        // Add code to log why the wait failed. Use the variable l_iWaitResult
        if l_iWaitResult == 0 //To full the compiler. It will be used later.
        endif

        l_lProcessRequest := .f.
    endif
endif

::ProcessingRequest = l_lProcessRequest

// Initialize ::URIInfo To provide easy access to 
l_cSitePath := ::GetEnvironment("CONTEXT_PREFIX")
if len(l_cSitePath) == 0
    l_cSitePath := "/"
endif

l_cPath := substr(::GetEnvironment("REDIRECT_URL"),len(l_cSitePath)+1)
l_nPos  := hb_RAt("/",l_cPath)
l_cPage := substr(l_cPath,l_nPos+1)
if l_cPage == "default.html"
    l_cPage := ""  //Work Around the behaviour of Apache's work around to deal with root file access
endif
l_cPath := left(l_cPath,l_nPos)

::RequestSettings["Protocol"]    := ::GetEnvironment("REQUEST_SCHEME")
::RequestSettings["Port"]        := val(::GetEnvironment("SERVER_PORT"))
::RequestSettings["Host"]        := ::GetEnvironment("SERVER_NAME")
::RequestSettings["SitePath"]    := l_cSitePath
::RequestSettings["Path"]        := l_cPath
::RequestSettings["Page"]        := l_cPage
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

// SendToDebugView("v 002  page = ",l_cPage)

if l_lProcessRequest
    //If a resource file is requested, like for example favicon.ico, and the file is not present, under Apache the Harbour app will be called (bug imho). So a web page should not have an extension, and therefore skip the request.
    l_nPos := hb_RAt(".",l_cPage)
    if !empty(l_nPos)
        ::SkipRequest := .t.
        ::SetHeaderValue("Status","404 Not found by Harbour FastCGI")
        ::RequestCount--  // To undo the request counter increment.
        // SendToDebugView("Status 404 Not found")
    endif
endif

return l_lProcessRequest
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
local l_nPCount
for l_nPCount := 1 to pcount()
    if l_nPCount > 1
        ::OutputBuffer += " "
    endif
    ::OutputBuffer += hb_ValToStr(hb_PValue(l_nPCount)) //par_html
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
local l_cEnvironment
local l_cHtml := ""
local l_cValue

if !::LoadedRequestEnvironment
    ::RequestEnvironment := hb_Fcgi_Get_Request_Variables()
endif
for each l_cEnvironment in ::RequestEnvironment
    l_cValue := strtran(l_cEnvironment:__enumValue(),"%","&#37;")   // Not Certain why had to convert the % character
    l_cHtml += "<div>"+l_cEnvironment:__enumKey()+" - "+l_cValue+"</div>"
endfor
return l_cHtml
//-----------------------------------------------------------------------------------------------------------------
method GetAppConfig(par_cName) class hb_Fcgi
return hb_HGetDef(::AppConfig, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method GetQueryString(par_cName) class hb_Fcgi
local l_cParameter
local l_nPos
if !::LoadedQueryString
    ::LoadedQueryString := .t.
    // Important: It seems that under IIS if have parameters like   "name1=val1&name2=val2"  it get converted name not repeating "name" and just having the number. More research needed here.
    for each l_cParameter in hb_ATokens(::GetEnvironment("QUERY_STRING"),"&",.f.,.f.)
        l_nPos := at("=",l_cParameter)
        if l_nPos > 1  // Name may not be empty
            ::QueryString[left(l_cParameter,l_nPos-1)] := substr(l_cParameter,l_nPos+1)
        endif
    endfor
endif
return hb_HGetDef(::QueryString, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method LoadInput() class hb_Fcgi
local l_cInput
local l_nPos
local l_cContentType
local l_cMultiFormBoundary
local l_nMultiFormBoundaryLen
local l_cInputBuffer
local l_cLine1
local l_cLine2
local l_cLine3
local l_lFoundAllLines
local l_cInputName
local l_cFileName
local l_cToken
local l_lFoundFormData
local l_xJsonInput

if !::LoadedInput
    ::LoadedInput := .t.
    ::InputRaw := hb_Fcgx_GetInput(::GetInputLength())  //Will return a buffer that could have chr(0) in it
    
    // Used during development and debugging
    // SendToClipboard(::InputRaw)
    // hb_MemoWrit("D:\request.txt",::InputRaw)   // To assist in debugging. 

    l_cContentType := ::GetContentType()
//  SendToDebugView("Content Type: "+l_cContentType)
//[30432] [Harbour] Other Content Type: application/json

    do case
    case l_cContentType == "application/x-www-form-urlencoded"
        for each l_cInput in hb_ATokens(::InputRaw,"&",.f.,.f.)
            l_nPos := at("=",l_cInput)
            if l_nPos > 1  // Name may not be empty
                ::Input[left(l_cInput,l_nPos-1)] := {1,substr(l_cInput,l_nPos+1)}
            endif
        endfor
    
    case left(l_cContentType,19) == "multipart/form-data"
        l_cInputBuffer          := ::InputRaw
        l_nPos                  := at(CRLF,l_cInputBuffer)
        l_cMultiFormBoundary    := left(l_cInputBuffer,l_nPos-1)
        l_nMultiFormBoundaryLen := len(l_cMultiFormBoundary)
        l_cInputBuffer          := substr(l_cInputBuffer,l_nPos+2)

        do while ((l_nPos := at(l_cMultiFormBoundary,l_cInputBuffer)) > 0)
            l_cInput         := left(l_cInputBuffer,l_nPos-1)   //Will hold the entire content of the element
            l_cInputBuffer   := substr(l_cInputBuffer,l_nPos+l_nMultiFormBoundaryLen)
            l_cLine1         := ""
            l_cLine2         := ""
            l_cLine3         := ""
            
            l_lFoundAllLines := .f.
            if !empty(l_cInput)
                // Pop First 3 Lines   Should always have 3 lines
                l_nPos := at(CRLF,l_cInput)
                if l_nPos > 0
                    l_cLine1 := left(l_cInput,l_nPos-1)
                    l_cInput := substr(l_cInput,l_nPos+2)
                    l_nPos := at(CRLF,l_cInput)
                    if l_nPos > 0
                        l_cLine2 := left(l_cInput,l_nPos-1)
                        l_cInput := substr(l_cInput,l_nPos+2)
                        l_nPos := at(CRLF,l_cInput)
                        if l_nPos > 0
                            l_cLine3 := left(l_cInput,l_nPos-1)
                            l_cInput := substr(l_cInput,l_nPos+2)
                            l_lFoundAllLines := .t.
                        endif
                    endif
                endif
                if l_lFoundAllLines
                    l_lFoundFormData := .f.
                    l_cInputName     := ""
                    l_cFileName      := ""
                    // l_cContentType   := ""

                    //Process Line 1
                    for each l_cToken in hb_ATokens(l_cLine1,";",.f.,.f.)
                        if l_cToken == "Content-Disposition: form-data"
                            l_lFoundFormData := .t.
                            loop
                        else
                            if (l_nPos := at("=",l_cToken)) > 0
                                if left(l_cToken,l_nPos-1) == " name"
                                    l_cInputName = strtran(substr(l_cToken,l_nPos+1),["],[])
                                elseif left(l_cToken,l_nPos-1) == " filename"
                                    l_cFileName = strtran(substr(l_cToken,l_nPos+1),["],[])
                                endif
                            endif
                        endif
                    endfor

                    if l_lFoundFormData .and. empty(l_cFileName)
                        //Regular Input Field
                        if !empty(l_cInputName)
                            if len(l_cInput) > 2  //TEXTAREA (multi line entry). l_cInput would have whatever is after line3
                                ::Input[l_cInputName] := {1,l_cLine3+CRLF+left(l_cInput,len(l_cInput)-2)}   // use l_cLine3 and Re-add the CRLF and add whatever is next. {Type = 1, l_cInputValue}
                            else
                                ::Input[l_cInputName] := {1,l_cLine3}   // Removed the trailing CRLF. {Type = 1, l_cInputValue}
                            endif
                        endif
                    else
                        //Uploaded File
                        //Line 3 is empty. The file content start after line 3
                        if (left(l_cLine2,14) == "Content-Type: ")
                            l_cContentType := substr(l_cLine2,15)
                            //{nType = 2,"",l_cFileName,l_cContentType,Content}
                            //Had to remove the last to characters, since extra CRLF
                            ::Input[iif(!empty(l_cInputName),l_cInputName,l_cFileName)] := {2,"",l_cFileName,l_cContentType,left(l_cInput,len(l_cInput)-2)}
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

            if left(l_cInputBuffer,2) == "--"
                exit
            elseif left(l_cInputBuffer,2) == CRLF
                l_cInputBuffer = substr(l_cInputBuffer,3)
            else
                //This should not Happen!!!
                SendToDebugView("Bad Request multipart format - error 1")
                exit
            endif
        enddo

    case l_cContentType == "application/json"
        l_cInputBuffer := ::InputRaw
        l_xJsonInput := {=>}

        if !empty(l_cInputBuffer)
            // hb_jsonDecode(l_cInputBuffer,<@xValue>,[<cdpID>]) ➔ <nLengthDecoded>
            hb_jsonDecode(l_cInputBuffer,@l_xJsonInput)
            do case
            case ValType(l_xJsonInput) == "A"
                ::xJsonInput := AClone(l_xJsonInput) 
            case ValType(l_xJsonInput) == "H"
                ::xJsonInput := hb_HClone(l_xJsonInput) 
            otherwise
                ::xJsonInput := {"Message"=>"Invalid JSON Input"}
            endcase
        endif

    otherwise
        SendToDebugView("Other Content Type: "+l_cContentType)
        
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
method GetJsonInput() class hb_Fcgi
if !::LoadedInput
    ::LoadInput()
endif
return ::xJsonInput
//-----------------------------------------------------------------------------------------------------------------
method GetInputValue(par_cName) class hb_Fcgi
local l_aResult
if !::LoadedInput
    ::LoadInput()
endif
l_aResult := hb_HGetDef(::Input, par_cName, {1,""})
return l_aResult[2]
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileName(par_cName) class hb_Fcgi
local l_aResult
if !::LoadedInput
    ::LoadInput()
endif
l_aResult := hb_HGetDef(::Input, par_cName, {1,""})
return iif(l_aResult[1]=2,l_aResult[3],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileContentType(par_cName) class hb_Fcgi
local l_aResult
if !::LoadedInput
    ::LoadInput()
endif
l_aResult := hb_HGetDef(::Input, par_cName, {1,""})
return iif(l_aResult[1]=2,l_aResult[4],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileContent(par_cName) class hb_Fcgi
local l_aResult
if !::LoadedInput
    ::LoadInput()
endif
l_aResult := hb_HGetDef(::Input, par_cName, {1,""})
return iif(l_aResult[1]=2,l_aResult[5],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method SaveInputFileContent(par_cName,par_cFileFullPath) class hb_Fcgi
local l_aResult
local lResult := .f.
if !::LoadedInput
    ::LoadInput()
endif
l_aResult := hb_HGetDef(::Input, par_cName, {1,""})
try 
    hb_MemoWrit(par_cFileFullPath,iif(l_aResult[1]=2,l_aResult[5],""))
    lResult := .t.
catch
endtry
return lResult  // .t. if content was saved to file
//-----------------------------------------------------------------------------------------------------------------
method LoadAppConfig() class hb_Fcgi
local l_cConfigText
local l_cLine
local l_nPos
local l_cName
local l_cValue
local l_iNumberOfConfigs := 0
//The configuration file is purposely not with a .txt extension to block users from accessing it.
if file(::PathBackend+"config_deployment.txt")
    l_cConfigText := hb_MemoRead(::PathBackend+"config_deployment.txt")
else
    l_cConfigText := hb_MemoRead(::PathBackend+"config.txt")
endif
l_cConfigText := StrTran(StrTran(l_cConfigText,chr(13)+chr(10),chr(10)),chr(13),chr(10))
for each l_cLine in hb_ATokens(l_cConfigText,chr(10),.f.,.f.)
    l_nPos := at("=",l_cLine)
    if l_nPos > 1  //Name may not be empty
        l_cName := left(l_cLine,l_nPos-1)
        l_cLine := substr(l_cLine,l_nPos+1)
        l_nPos := rat(" //",l_cLine)    // To ensure the "//" comment marker is not part of a config value, it must be preceded with at least one blank.
        if empty(l_nPos)
            l_cValue := allt(l_cLine)
        else
            l_cValue := allt(left(l_cLine,l_nPos-1))
        endif
        if left(l_cValue,2) == "${" .and. right(l_cValue,1) == "}" // The value is making a reference to an environment variable
            l_cValue := hb_GetEnv(substr(l_cValue,3,len(l_cValue)-3),"")
        endif
        ::AppConfig[l_cName] := l_cValue
        l_iNumberOfConfigs++
    endif
endfor
::MaxRequestToProcess        := val(hb_HGetDef(::AppConfig,"MaxRequestPerFCGIProcess","0"))
::ReloadConfigAtEveryRequest := (hb_HGetDef(::AppConfig,"ReloadConfigAtEveryRequest","false") == "true")
return l_iNumberOfConfigs
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
local l_cCookie
local l_nPos
if !::LoadedRequestCookies
    ::LoadedRequestCookies := .t.
    for each l_cCookie in hb_ATokens(::GetEnvironment("HTTP_COOKIE"),";",.f.,.f.)
        l_nPos := at("=",l_cCookie)
        if l_nPos > 1  // Name may not be empty
            ::RequestCookies[allt(left(l_cCookie,l_nPos-1))] := allt(substr(l_cCookie,l_nPos+1))
        endif
    endfor
endif
return hb_HGetDef(::RequestCookies, par_cName, "")
//-----------------------------------------------------------------------------------------------------------------
method SetCookieValue(par_cName,par_cValue,par_nExpireDays,par_cPath)
//See  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
//Will mark the cookie to expire 364 days from now and site root path
local l_nExpireDays := hb_defaultValue(par_nExpireDays,365)
local l_cPath       := hb_defaultValue(@par_cPath,"/")

//Added the cookie name to the Header Name since using a Hash array
::SetHeaderValue("Set-Cookie~"+par_cName,par_cName+"="+par_cValue+";SameSite=Strict"+;
                    iif(empty(l_nExpireDays),"","; Expires="+FcgiCookieTimeToExpires(hb_DateTime()+l_nExpireDays))+;
                    iif(empty(l_cPath),"","; Path="+l_cPath) )
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetSessionCookieValue(par_cName,par_cValue,par_cPath)
//See  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
//Will mark the cookie to expire 364 days from now and site root path
local l_cPath       := hb_defaultValue(@par_cPath,"/")

//Added the cookie name to the Header Name since using a Hash array
::SetHeaderValue("Set-Cookie~"+par_cName,par_cName+"="+par_cValue+";SameSite=Strict"+;
                    iif(empty(l_cPath),"","; Path="+l_cPath) )
return NIL
//-----------------------------------------------------------------------------------------------------------------
method DeleteCookie(par_cName,par_cPath)
//See  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
//Will mark the cookie to expire 364 days from now and site root path
local l_cPath       := hb_defaultValue(@par_cPath,"/")

//Added the cookie name to the Header Name since using a Hash array
::SetHeaderValue("Set-Cookie~"+par_cName,par_cName+"="+";SameSite=Strict"+;
                    "; Expires=0"+;
                    iif(empty(l_cPath),"","; Path="+l_cPath) )
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Redirect(par_cURL)
::SetContentType("text/html")
// ::SetHeaderValue("Status","303 OK")
::SetHeaderValue("Status","303 See Other")
::SetHeaderValue("Location",par_cURL)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method WriteOutput() class hb_Fcgi
local l_cHeader
local l_cHeaderName
local l_cHeaderValue
local l_nPos
local l_nRedirected := 0

hb_Fcgx_Print("Content-type: "+iif(empty(::ContentType),::DefaultContentType,::ContentType)+CRLF)
for each l_cHeader in ::ResponseHeader
    l_cHeaderName  := l_cHeader:__enumKey()
    l_cHeaderValue := l_cHeader:__enumValue()
    do case
    case l_cHeaderName == "Location"
        l_nRedirected++
    case l_cHeaderName == "Status" .and. left(l_cHeaderValue,1) == "3"
        l_nRedirected++
    endcase
    l_nPos := at("~",l_cHeaderName)  // To handle multiple Set-Cookies header entries
    if l_nPos > 0
        l_cHeaderName := left(l_cHeaderName,l_nPos-1)
    endif
    hb_Fcgx_Print(l_cHeaderName+":"+l_cHeaderValue+CRLF)
endfor
hb_Fcgx_Print(CRLF)   //Extra CRLF to notify end of header
if l_nRedirected < 2
    // hb_Fcgx_Print(::OutputBuffer)
    hb_Fcgx_BPrint(::OutputBuffer)
// else
//     SendToDebugView("WriteOutput - Dropped Output due to redirect")
endif
::OutputBuffer = ""
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GenerateRandomString(par_nLength,par_cPossibleChars) class hb_Fcgi
local l_cString := ""
local l_nPossibleCharsLen := len(par_cPossibleChars)
local l_nCounter
for l_nCounter := 1 to par_nLength
    l_cString += chr(hb_BPeek(par_cPossibleChars,hb_RandomInt(1,l_nPossibleCharsLen)))
endfor
return l_cString
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
local l_nLoop
local l_cResult := []
if len(::aTrace) > 0
    do case
    case par_nListMethod == 1   // Comma Delimited
        for l_nLoop := 1 to Len(::aTrace)
            if !empty(l_cResult)
                l_cResult += ","
            endif
            l_cResult += ::aTrace[l_nLoop]
        endfor
    case par_nListMethod == 2   // CRLF
        for l_nLoop := 1 to Len(::aTrace)
            if !empty(l_cResult)
                l_cResult += CRLF
            endif
            l_cResult += ::aTrace[l_nLoop]
        endfor
    case par_nListMethod == 3   // <br>
        for l_nLoop := 1 to Len(::aTrace)
            if !empty(l_cResult)
                l_cResult += [<br>]
            endif
            l_cResult += ::aTrace[l_nLoop]
        endfor
    case par_nListMethod == 4   // <ol>
        l_cResult += [<ol>]
        for l_nLoop := 1 to Len(::aTrace)
            l_cResult += [<li>]+::aTrace[l_nLoop]+[</li>]
        endfor
        l_cResult += [</ol>]
    endcase
endif
return l_cResult
//=================================================================================================================
function SendToDebugView(par_cStep,par_xValue)

#ifdef DEBUGVIEW

    local l_cTypeOfxValue
    local l_cValue := "Unknown Value"

    l_cTypeOfxValue = ValType(par_xValue)
    
    do case
    case pcount() < 2
        l_cValue := ""
    case l_cTypeOfxValue $ "AH" // Array or Hash
        l_cValue := hb_ValToExp(par_xValue)
    case l_cTypeOfxValue == "B" // Block
        //Not coded yet
    case l_cTypeOfxValue == "C" // Character (string)
        l_cValue := par_xValue
        //Not coded yet
    case l_cTypeOfxValue == "D" // Date
        l_cValue := DTOC(par_xValue)
    case l_cTypeOfxValue == "L" // Logical
        l_cValue := IIF(par_xValue,"True","False")
    case l_cTypeOfxValue == "M" // Memo
        //Not coded yet
    case l_cTypeOfxValue == "N" // Numeric
        l_cValue := alltrim(str(par_xValue))
    case l_cTypeOfxValue == "O" // Object
        //Not coded yet
    case l_cTypeOfxValue == "P" // Pointer
        //Not coded yet
    case l_cTypeOfxValue == "S" // Symbol
        //Not coded yet
    case l_cTypeOfxValue == "U" // NIL
        l_cValue := "Null"
    endcase
    
    l_cValue := strtran(l_cValue,chr(13)+chr(10),[<br>])
    l_cValue := strtran(l_cValue,chr(10),[<br>])
    l_cValue := strtran(l_cValue,chr(13),[<br>])

    if empty(l_cValue)
        hb_Fcgx_OutputDebugString("[Harbour] "+par_cStep)
    else
        hb_Fcgx_OutputDebugString("[Harbour] "+par_cStep+" - "+l_cValue)
    endif

#endif

return .T.
//=================================================================================================================
function SendToClipboard(par_cText)
//#if defined(_WIN32) || defined(_WIN64)   // Will not work since this is a PRG So will use the DEBUGVIEW setting.

#ifdef CLIPBOARDSUPPORT
    wvt_SetClipboard(par_cText)
#endif

return .T.
//=================================================================================================================
function FcgiGetErrorInfo( par_oError,par_cCode ,par_nProgramStackStart)  //From mod_harbour <-> apache.prg
local l_n
local l_cInfo := "Error: " + par_oError:description + "<br>"
local l_cProcname
local l_aLines
local l_nLine
local l_lPrintedSourceHeader := .f.

hb_default(@par_nProgramStackStart ,1)

if ! Empty( par_oError:operation )
    l_cInfo += "operation: " + par_oError:operation + "<br>"
endif   

if ! Empty( par_oError:filename )
    l_cInfo += "filename: " + par_oError:filename + "<br>"
endif   

if ValType( par_oError:Args ) == "A"
    for l_n = 1 to Len( par_oError:Args )
        l_cInfo += "[" + Str( l_n, 4 ) + "] = " + ValType( par_oError:Args[ l_n ] ) + ;
                "   " + FcgiValToChar( par_oError:Args[ l_n ] ) + "<br>"
    next
endif	
    
l_n = par_nProgramStackStart
while .t.
    l_cProcname := upper(ProcName( l_n ))
    do case
    case empty(l_cProcname) .or. l_cProcname == "HB_HRBDO" 
        exit
    case right(l_cProcname,8) == ":ONERROR"
    case l_cProcname == "ERRORBLOCKCODE"  
    case right(l_cProcname,10) == "__DBGENTRY"
    case right(l_cProcname,11) == "HB_FCGI_NEW"
    otherwise
        l_cInfo += "Called From: " + If( ! Empty( ProcFile( l_n ) ), ProcFile( l_n ) + ", ", "" ) + l_cProcname + ", line: " + AllTrim( Str( ProcLine( l_n ) ) ) + "<br>"
    endcase
    l_n++
end

if ! Empty( par_cCode )
    l_aLines = hb_ATokens( par_cCode, Chr( 10 ) )
    l_n = 1
    l_nLine := 0
    while( l_nLine := ProcLine( ++l_n ) ) == 0   //The the line number in the last on the stack of programs
    end   
    if l_nLine > 0
        for l_n = Max( l_nLine - 2, 1 ) to Min( l_nLine + 2, Len( l_aLines ) )
            if !l_lPrintedSourceHeader
                l_cInfo += "<br><b>Source:</b><br>"
                l_lPrintedSourceHeader := .t.
            endif
            l_cInfo += "<nobr>"+StrZero( l_n, 5 ) + If( l_n == l_nLine, " =>", ": " ) + FcgiGetErrorInfo_HtmlEncode( l_aLines[ l_n ] ) + "</nobr><br>" //+ CRLF
        next
    endif
endif

return l_cInfo
//=================================================================================================================
function FcgiGetErrorInfo_HtmlEncode( par_cString )
local l_cChar
local l_cResult := "" 

for each l_cChar in par_cString
    do case
    case l_cChar == "<"
        l_cChar = "&lt;"

    case l_cChar == '>'
        l_cChar = "&gt;"     
        
    case l_cChar == "&"
        l_cChar = "&amp;"     

    case l_cChar == '"'
        l_cChar = "&quot;"    
        
    case l_cChar == " "
        l_cChar = "&nbsp;"               
    endcase
    l_cResult += l_cChar 
endfor

return l_cResult   

//=================================================================================================================
function FcgiValToChar( par_u )  //Adapted From mod_harbour <-> apache.prg
local l_cResult

switch ValType( par_u )
case "C"
    l_cResult = par_u
    exit
case "D"
    l_cResult = DToC( par_u )
    exit
case "L"
    l_cResult = If( par_u, ".T.", ".F." )
    exit
case "N"
    l_cResult = AllTrim( Str( par_u ) )
    exit
case "A"
    l_cResult = hb_ValToExp( par_u )
    exit
case "P"
    l_cResult = "(P)" 
    exit
case "H"
    l_cResult = hb_ValToExp( par_u )
    exit
case "U"
    l_cResult = "nil"
    exit
otherwise
    l_cResult = "type not supported yet in function ValToChar()"
endswitch
 
 return l_cResult   
//=================================================================================================================
function FcgiPrepFieldForValue( par_FieldValue ) 
// for now calling el_StrReplace, which is case insensitive ready version of hb_StrReplace
return el_StrReplace(par_FieldValue,{;
                                      [&lt;] => [&amp;lt;] ,;
                                      [&gt;] => [&amp;gt;] ,;
                                      ["]    => [&quot;]   ,;
                                      [<]    => [&lt;]     ,;
                                      [>]    => [&gt;]     ,;
                                      chr(9) => [&#9;]      ;
                                     },,1)
//=================================================================================================================
//If the web application is also using the Harbour_EL contrib define the compiler variable USING_HB_EL to avoid object redefinition.
#ifndef USING_HB_EL

//The EL_ScanStack is to be used in conjuntion with the "#command SCAN" and "#command ENDSCAN"
function EL_ScanStack(par_action)    //action = "push" "pop" "scan" , "clear" (empty the entire stack)
local l_xResult := nil
static s_iTop   := 0
static s_aStack := {}

hb_default( @par_action, "scan" )

switch par_action
case "push"
    s_iTop++
    if len(s_aStack) < s_iTop
        ASize( s_aStack, s_iTop )
    endif
    s_aStack[s_iTop] := {select(),.t.} // Record the current work area and flag to know during "scan" calls if they are going to be the initial "locate" or should be "continue"
    l_xResult := nil
    exit
case "pop"
    s_iTop--
    //No need to reduce the size of s_aStack since will most likely be increased again
    exit
case "clear"
    s_iTop   := 0
    ASize( s_aStack, 0 )
    exit
otherwise
    select (s_aStack[s_iTop,1])
    l_xResult := s_aStack[s_iTop,2]
    s_aStack[s_iTop,2] := .f.
    exit
endswitch

return l_xResult
//=================================================================================================================
function el_StrToFile(par_cExpression,par_cFileName,par_lAdditive)   //Partial implementation of VFP9's strtran(). The 3rd parameter only supports a logical
local l_lAdditive
local l_nBytesWritten := 0
local l_nFileHandle

l_lAdditive := hb_defaultValue(par_lAdditive,.f.)

if hb_FileExists(par_cFileName)
    if l_lAdditive
        l_nFileHandle := FOpen(par_cFileName,FO_WRITE)
        FSeek(l_nFileHandle,0,FS_END)  // go to the end of file
    else
        if ferase(par_cFileName) == 0
            l_nFileHandle := FCreate(par_cFileName)
        else
            l_nFileHandle := -1
        endif
    endif
else
    l_nFileHandle := FCreate(par_cFileName)
endif

if l_nFileHandle >= 0
    l_nBytesWritten := fwrite(l_nFileHandle,par_cExpression)
    fclose(l_nFileHandle)
endif

return l_nBytesWritten

#endif //USING_HB_EL
//=================================================================================================================
//The following a modified version of the "uhttpd_URLDecode" function from extras\httpsrv\_cgifunc.prg   Copyright 2009 Francesco Saverio Giudice <info / at / fsgiudice.com>
//under the terms of the GNU General Public License as published by * the Free Software Foundation; either version 2, or (at your option) * any later version.

function DecodeURIComponent(par_cString)

#ifdef HB_USE_HBTIP
	RETURN TIPENCODERURL_DECODE( par_cString )
#else
    local cRet := ""
    local i
    local l_cChar

	FOR i := 1 TO Len( par_cString )
		l_cChar := SubStr( par_cString, i, 1 )
		DO CASE
		CASE l_cChar == "+"
			cRet += " "

		CASE l_cChar == "%"
			i++
			cRet += Chr( hb_HexToNum( SubStr( par_cString, i, 2 ) ) )
			i++

		OTHERWISE
			cRet += l_cChar

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
	local cRet := "", i, nVal, l_cChar

	__defaultNIL( @par_lComplete, .T. )

	for i := 1 to Len( par_cString )
		l_cChar := SubStr( par_cString, i, 1 )
		DO CASE
		CASE l_cChar == " "
			cRet += "+"

		CASE ( l_cChar >= "A" .AND. l_cChar <= "Z" ) .OR. ;
				( l_cChar >= "a" .AND. l_cChar <= "z" ) .OR. ;
				( l_cChar >= "0" .AND. l_cChar <= "9" ) .OR. ;
				l_cChar == "." .OR. l_cChar == "," .OR. l_cChar == "&" .OR. ;
				l_cChar == "/" .OR. l_cChar == ";" .OR. l_cChar == "_"
			cRet += l_cChar

		CASE iif( ! par_lComplete, l_cChar == ":" .OR. l_cChar == "?" .OR. l_cChar == "=", .F. )
			cRet += l_cChar

		OTHERWISE
			nVal := Asc( l_cChar )
			cRet += "%" + hb_NumToHex( nVal )
            
		ENDCASE
	NEXT

	RETURN cRet
//=================================================================================================================
function FcgiLogger(par_nAction,par_cString,...)
//par_nAction, 1=Reset,2=Add Line,3=Append To Line,4=Save to File,5=Save to File and Reset
//par_cString, if par_nAction = 2 or 3 the text to send out, if par_nAction = 4 the full file name to write out.

static s_cBuffer := ""
local l_nPCount
local l_cCallBuffer
local l_nPos
// local nByte
local l_nChar

switch par_nAction
case 1  // Reset
    s_cBuffer := ""
    exit
case 2  // Add Line, same as ? <expr>
    if len(s_cBuffer) > 0
        s_cBuffer += chr(13)+chr(10)
    endif
case 3  // Append to Line, same as ?? <expr>
    for l_nPCount := 2 to pcount()
        if l_nPCount > 2
            s_cBuffer += " "
        endif
        l_cCallBuffer := hb_ValToStr(hb_PValue(l_nPCount))
        // for l_nPos := 1 to len(l_cCallBuffer)
        //     nByte := hb_BPeek(l_cCallBuffer,l_nPos)
        //     if nByte < 32 //.or. nByte > 126
        //         hb_BPoke(@l_cCallBuffer,l_nPos,63)   // to replace invalid html char with "?"
        //     endif
        // endfor

        for l_nPos := 1 to hb_utf8Len(l_cCallBuffer)
            l_nChar := hb_utf8Peek(l_cCallBuffer,l_nPos)
            if l_nChar < 32
                hb_utf8Poke(@l_cCallBuffer,l_nPos,hb_utf8Asc("?"))   // to replace invalid html char with "?"
            endif
        endfor

        s_cBuffer += l_cCallBuffer
    endfor
    exit
case 4
case 5
    el_StrToFile(s_cBuffer,par_cString)
    if par_nAction == 5
        s_cBuffer := ""
    endif
endswitch

return nil
//=================================================================================================================
function FcgiCookieTimeToExpires(par_tDateTime)
local l_cUTCGMT
local l_cDow
local l_dDate
local l_cMonth
local l_cTime := ""
// See https://stackoverflow.com/questions/11136372/which-date-formats-can-i-use-when-specifying-the-expiry-date-when-setting-a-cook
l_dDate = hb_TtoD(hb_TSToUTC(par_tDateTime),@l_cTime,"hh:mm:ss")
l_cDow   := {"Sun","Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}[dow(l_dDate)]
l_cMonth := {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}[Month(l_dDate)]

l_cUTCGMT := l_cDow + ", " + Trans(Day(l_dDate)) + " " + l_cMonth + " " + Trans(Year(l_dDate)) + " " + l_cTime + " GMT"

//  UTC/GMT format is required by cookies e.g. Sun, 15 Jul 2012 00:00:01 GMT

return l_cUTCGMT
//=================================================================================================================
