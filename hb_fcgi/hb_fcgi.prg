//Copyright (c) 2019 Eric Lendvai MIT License

#include "hb_fcgi.ch"

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

        data   LoadedAppConfig            init .f.
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
        method Print()
        method SetContentType()
        method GetEnvironment(cName)
        method ListEnvironment()                       // Just to assist development
        method GetAppConfig(cName)
        method GetQueryString(cName)
        method GetInputLength()
        method GetRawInput()                           // To be only available during development
        method GetInputValue(cName)
        method GetInputFileName(cName)
        method GetInputFileContentType(par_Name)
        method GetInputFileContent(par_Name)
        method SaveInputFileContent(par_Name,par_FileFullPath)
        method IsGet()                              SETGET   //Used to query if the page was sent as a GET request
        method IsPost()                             SETGET   //Used to query if the page was sent as a POST request
        //_M_ method GetHeader(cName)  // TODO

        method OnFirstRequest() inline nil
        method OnShutdown()     inline nil

endclass


//-----------------------------------------------------------------------------------------------------------------
method New() class hb_Fcgi
    hb_hSetCaseMatch( ::QueryString, .f. )
    hb_hSetCaseMatch( ::AppConfig, .f. )

    // hb_hSetOrder(::RequestEnvironment,.f.)  Does not seem to work
    ::FastCGIExeFullPath := hb_argV(0)

    hb_Fcgx_Init()
return Self
//-----------------------------------------------------------------------------------------------------------------
method Wait() class hb_Fcgi
    //Used to wait for the next page request
    local lProcessRequest      //If web page should be built
    local cREQUEST_URI
    local iWaitResult
    local cDownFileName
    local nPos

    if ::ProcessingRequest
        ::Finish()
    endif

    if ::MaxRequestToProcess > 0 .and. ::RequestCount >= ::MaxRequestToProcess
        //Reached Max Number of Requests to Process. This will happen after a page finished to build, and we are back in waiting request mode.
        lProcessRequest := .f.
    else
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
    
            if ::ReloadConfigAtEveryRequest .or. !::LoadedAppConfig
                ::LoadAppConfig()
            endif
    
            cREQUEST_URI := ::GetEnvironment("REQUEST_URI")
            // SendToDebugView("cREQUEST_URI",cREQUEST_URI)

            if file(left(::FastCGIExeFullPath,len(::FastCGIExeFullPath)-3)+"kill")
                // altd()
                nPos := hb_RAt("\backend\",lower(::FastCGIExeFullPath))   // _M_ Make this non Windows ready
                if empty(nPos)
                    ::Print([Site is down. Could not locate "down.html".])
                else
                    cDownFileName = left(::FastCGIExeFullPath,nPos)+"website\down.html"
                    if file(cDownFileName)
                        ::Print(hb_MemoRead(cDownFileName))
                    else
                        ::Print([Site is down. Add a "down.html" file.])
                    endif
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
            lProcessRequest := .f.
        endif
    endif

    ::ProcessingRequest = lProcessRequest

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
method GetEnvironment(par_Name) class hb_Fcgi
    if !::LoadedRequestEnvironment
        ::RequestEnvironment := hb_Fcgi_Get_Request_Variables()
    endif
return hb_HGetDef(::RequestEnvironment, par_Name, "")
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
method GetAppConfig(par_Name) class hb_Fcgi
return hb_HGetDef(::AppConfig, par_Name, "")
//-----------------------------------------------------------------------------------------------------------------
method GetQueryString(par_Name) class hb_Fcgi
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
return hb_HGetDef(::QueryString, par_Name, "")
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
    local cInputValue
    local cToken
    local lFoundFormData

    local lDebug
    // local lcrash
    // lcrash++

    if !::LoadedInput
        ::LoadedInput := .t.
        ::InputRaw := hb_Fcgx_GetInput(::GetInputLength())  //Will return a buffer that could have chr(0) in it

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
                        cContentType   := ""

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
method GetInputValue(par_Name) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_Name, {1,""})
return aResult[2]
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileName(par_Name) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_Name, {1,""})
return iif(aResult[1]=2,aResult[3],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileContentType(par_Name) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_Name, {1,""})
return iif(aResult[1]=2,aResult[4],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method GetInputFileContent(par_Name) class hb_Fcgi
    local aResult
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_Name, {1,""})
return iif(aResult[1]=2,aResult[5],"") //Verify it input was a file
//-----------------------------------------------------------------------------------------------------------------
method SaveInputFileContent(par_Name,par_FileFullPath) class hb_Fcgi
    local aResult
    local lResult := .f.
    if !::LoadedInput
        ::LoadInput()
    endif
    aResult := hb_HGetDef(::Input, par_Name, {1,""})
    try 
        hb_MemoWrit(par_FileFullPath,iif(aResult[1]=2,aResult[5],""))
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
    cConfigText := hb_MemoRead(hb_DirBase()+"config.txt")
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
    ::LoadedAppConfig            := .t.
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
FUNCTION hb_StrTranI( cSource, cRepl, cTrans )  // from https://groups.google.com/forum/#!topic/harbour-users/NMKwSSX7TtU
    LOCAL cTarget := ""
    LOCAL nPos
     
    do while len( cSource ) > 0
        IF ( nPos := hb_AtI( cRepl, cSource ) ) == 0  // nor more fun
          cTarget += cSource
          EXIT
        ENDIF
        cTarget += LEFT( cSource, nPos - 1 ) + cTrans
        cSource := SUBSTR( cSource, nPos + LEN( cRepl ) )
      ENDDO
     
    RETURN cTarget
//=================================================================================================================
