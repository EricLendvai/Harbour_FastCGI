//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_fcgi.ch"
#include "fileio.ch"
#include "dbinfo.ch"

request DBFCDX
request DBFFPT
request HB_CODEPAGE_EN
//request HB_CODEPAGE_UTF8
memvar v_hPP
//=================================================================================================================
Function Main()

public v_hPP
v_hPP := nil

SendToDebugView("Starting LocalSandbox")

//hb_cdpSelect("UTF8")
hb_cdpSelect("EN")

// oFcgi := hb_Fcgi():New()
oFcgi := MyFcgi():New()    // Used a subclass of hb_Fcgi
do while oFcgi:Wait()
    oFcgi:OnRequest()
enddo

SendToDebugView("Done")

return nil
//=================================================================================================================
class MyFcgi from hb_Fcgi
    method OnFirstRequest()
    method OnRequest()
    method OnShutdown()
    method OnError(par_oError)

endclass
//-----------------------------------------------------------------------------------------------------------------
method OnFirstRequest() class MyFcgi
    SendToDebugView("Called from method OnFirstRequest")
    set delete on
    
    UpdateSchema()

    // From Mod_harbour repo function AddPPRules()

    v_hPP = __pp_init()
    // __pp_path( v_hPP, "~/harbour/include" )
    __pp_path( v_hPP, ::GetAppConfig("HarbourPath")+"include" )

    // if ! Empty( hb_GetEnv( "HB_INCLUDE" ) )
    //     __pp_path( v_hPP, hb_GetEnv( "HB_INCLUDE" ) )
    // endif 	 

    //    __pp_addRule( v_hPP, "#xcommand ? [<explist,...>] => AP_RPuts( '<br>' [,<explist>] )" )
    //    __pp_addRule( v_hPP, "#xcommand ?? [<explist,...>] => AP_RPuts( [<explist>] )" )
    __pp_addRule( v_hPP, "#define CRLF chr(13)+chr(10)" )
    //    __pp_addRule( v_hPP, "#xcommand TEXT <into:TO,INTO> <v> => #pragma __cstream|<v>:=%s" )
    //    __pp_addRule( v_hPP, "#xcommand TEXT <into:TO,INTO> <v> ADDITIVE => #pragma __cstream|<v>+=%s" )
    //    __pp_addRule( v_hPP, "#xcommand TEMPLATE [ USING <x> ] [ PARAMS [<v1>] [,<vn>] ] => " + ;
    //                       '#pragma __cstream | AP_RPuts( InlinePrg( %s, [@<x>] [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) )' )
    //    __pp_addRule( v_hPP, "#xcommand BLOCKS [ PARAMS [<v1>] [,<vn>] ] => " + ;
    //                       '#pragma __cstream | AP_RPuts( ReplaceBlocks( %s, "{{", "}}" [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) )' )   
    //    __pp_addRule( v_hPP, "#command ENDTEMPLATE => #pragma __endtext" )
    __pp_addRule( v_hPP, "#xcommand TRY  => BEGIN SEQUENCE WITH {| oErr | Break( oErr ) }" )
    __pp_addRule( v_hPP, "#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->" )
    __pp_addRule( v_hPP, "#xcommand FINALLY => ALWAYS" )
    __pp_addRule( v_hPP, "#xcommand ENDTRY => END" )
    __pp_addRule( v_hPP, "#xcommand ENDFOR => END" )
    __pp_addRule( v_hPP, "#xcommand ENDDO => END" )
    //    __pp_addRule( v_hPP, "#xcommand DEFAULT <v1> TO <x1> [, <vn> TO <xn> ] => ;" + ;
    //                       "IF <v1> == NIL ; <v1> := <x1> ; END [; IF <vn> == NIL ; <vn> := <xn> ; END ]" )

    //__pp_addRule( v_hPP, "#xcommand ? [<explist,...>] => vfp_StrToFile( <explist> + CRLF , 'result.txt' , .T. )" )
    __pp_addRule( v_hPP, "#xcommand ? [<explist>] => FcgiLogger( 2, <explist> )" )
    __pp_addRule( v_hPP, "#xcommand ?? [<explist>] => FcgiLogger( 3, <explist> )" )

    // vfp_StrToFile(par_cExpression,par_cFileName,par_lAdditive)   //Partial implementation of VFP9's strtran(). The 3rd parameter only supports a logical

return nil 
//-----------------------------------------------------------------------------------------------------------------
method OnRequest() class MyFcgi
    local cHtml := ""
    local cPageName

    SendToDebugView("Request Counter",::RequestCount)
    
    cHtml := ""
    cHtml += [<!DOCTYPE html>]
    cHtml += [<html>]
    
    cHtml += [<head>]
    cHtml += [<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">]

    cHtml += [<meta http-equiv="X-UA-Compatible" content="IE=edge" />]
    cHtml += [<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >]
    cHtml += [<title>Local Harbour Sandbox</title>]

    // The following 4 lines was when not using jQuery UI.
    // cHtml += [<script language="javascript" type="text/javascript" src="scripts/jQuery_1_11_3/jquery.js"></script>]
    // cHtml += [<link rel="stylesheet" type="text/css" href="scripts/Bootstrap_4_3_1/css/bootstrap.min.css">]
    // cHtml += [<script language="javascript" type="text/javascript" src="scripts/Bootstrap_4_3_1/js/bootstrap.min.js"></script>]
    // cHtml += [<script language="javascript" type="text/javascript" src="scripts/jQuery_1_11_3/jquery-migrate.js"></script>]

    // Also using jQuery UI to handle resizing of the mono editor
    cHtml += [<link rel="stylesheet" type="text/css" href="scripts/jQueryUI_1_12_1_NoTooltip/Themes/smoothness/jqueryui.css">]
    cHtml += [<script language="javascript" type="text/javascript" src="scripts/jQuery_1_11_3/jquery.js"></script>]
    cHtml += [<script language="javascript" type="text/javascript" src="scripts/jQuery_1_11_3/jquery-migrate.js"></script>]
    cHtml += [<link rel="stylesheet" type="text/css" href="scripts/Bootstrap_4_3_1/css/bootstrap.min.css">]
    cHtml += [<script language="javascript" type="text/javascript" src="scripts/Bootstrap_4_3_1/js/bootstrap.min.js"></script>]
    cHtml += [<script>$.fn.bootstrapBtn = $.fn.button.noConflict();</script>]
    cHtml += [<script language="javascript" type="text/javascript" src="scripts/jQueryUI_1_12_1_NoTooltip/jquery-ui.min.js"></script>]

    cHtml += [</head>]

    cHtml += [<body>]

    cHtml += GetPageHeader()

    if empty(::GetAppConfig("HarbourPath"))
        cHtml += [<h1>MISSING HarbourPath in config.txt<br>Add "HarbourPath=C:\Harbour\" for example.<h1>]
    endif

    cHtml += [<div>]

    cPageName := ::RequestSettings["Page"]

    if empty(cPageName)
        cPageName := "home"
    endif

    switch lower(cPageName)
        case "home"
            cHtml += BuildPageHome()
            exit
        otherwise
            cHtml += [<table border="1" cellpadding="3" cellspacing="0">]
            cHtml += [<tr><td>Protocol</td>]     +[<td>]+::RequestSettings["Protocol"]+[</td></tr>]
            cHtml += [<tr><td>Port</td>]         +[<td>]+trans(::RequestSettings["Port"])+[</td></tr>]
            cHtml += [<tr><td>Host</td>]         +[<td>]+::RequestSettings["Host"]+[</td></tr>]
            cHtml += [<tr><td>Site Path</td>]    +[<td>]+::RequestSettings["SitePath"]+[</td></tr>]
            cHtml += [<tr><td>Path</td>]         +[<td>]+::RequestSettings["Path"]+[</td></tr>]
            cHtml += [<tr><td>Page</td>]         +[<td>]+::RequestSettings["Page"]+[</td></tr>]
            cHtml += [<tr><td>Query String</td>] +[<td>]+::RequestSettings["QueryString"]+[</td></tr>]
            cHtml += [<tr><td>Web Server IP</td>]+[<td>]+::RequestSettings["WebServerIP"]+[</td></tr>]
            cHtml += [<tr><td>Clien IP</td>]     +[<td>]+::RequestSettings["ClienIP"]+[</td></tr>]
            cHtml += [</table>]

            cHtml += [<p><a href="home">Manage Code Snippets </a></p>]
    endswitch
    
    cHtml += [</body>]

    cHtml += [</html>]

    ::Print(cHtml)
return nil
//-----------------------------------------------------------------------------------------------------------------
method OnShutdown() class MyFcgi
    SendToDebugView("Called from method OnShutdown")
return nil 
//-----------------------------------------------------------------------------------------------------------------
method OnError(par_oError)
     SendToDebugView("Called from MyFcgi OnError")
     ::Print("<h1>Error Occurred</h1>")
     ::hb_Fcgi:OnError(par_oError)
return nil
//=================================================================================================================
function UpdateSchema()

local aTableSchema
local cTableName
local aTableStructure := {}
local aTableTags := {}
local aTag
local aStructureOnFile := {}
local lUpdateTableStructure := .f.
local aStructure
local nPos

local aSchema := { ;
     {"SANDPROG",{;  //Sandbox Programs
          {"KEY","I:+",4,0},;
          {"SYSC","T",8,0},;
          {"SYSM","T",8,0},;
          {"NAME","C",180,0},;
          {"NOTE","M",4,0},;
          {"SRCCODE","M",4,0}},{;
          {"KEY","KEY",.f.},;
          {"TAG1","UPPER(NAME)",.f.}}};
     }


// 2015-02-08 13:19 UTC+0100 Przemyslaw Czerpak (druzus/at/poczta.onet.pl)
// * src/rdd/workarea.c
//   + added support for field flags in dbCreate()/dbStruct().
//     Flags can be passed in string with field type after ":", i.e.
//        "C:U"
//     means Unicode character field.
//     The following flags are recognized:
//        "N" - column can store null values
//        "B" - binary column
//        "+" - column is autoincrementing
//        "Z" - column is compressed
//        "E" - column is encrypted
//        "U" - column stores Unicode strings


RddSetDefault("DBFCDX")
rddInfo( RDDI_TABLETYPE, DB_DBF_VFP )
Set(_SET_CODEPAGE,"EN")

//cCrash++

hb_DirBuild(oFcgi:PathData)

for each aTableSchema in aSchema
    cTableName      := lower(aTableSchema[1])
    aTableStructure := aTableSchema[2]
    aTableTags      := aTableSchema[3]

    select 0
    if !File(oFcgi:PathData+cTableName+".dbf")
        DbCreate(oFcgi:PathData+cTableName+".dbf",aTableStructure,"DBFCDX",nil,,,"EN")  //Have to use nil and not .F. to not keep the table open
        SetTableCodePageToEN(oFcgi:PathData+cTableName+".dbf")
    else
        //Compare file
        if dbUseArea(.t.,"DBFCDX", oFcgi:PathData+cTableName+".dbf", cTableName, .t., .t., "EN")  // Opened Shared and readonly
            aStructureOnFile := dbStruct()  // load current table structure in an array
    
            if !(lUpdateTableStructure := (len(aStructureOnFile) <> len(aTableStructure)))
                //Same number of Elements, Compare Arrays
                for each aStructure in aTableStructure
                    if (nPos := AScan(aStructureOnFile,{|aElement|aElement[1] == allt(aStructure[1])})) == 0
                        lUpdateTableStructure := .T.  //Did not find that column on file
                        exit
                    else
                        if aStructureOnFile[nPos,2] == "@"
                            aStructureOnFile[nPos,2] := "T"
                        endif
                        if (aStructureOnFile[nPos,2] <> aStructure[2]) .or. ;
                        (aStructureOnFile[nPos,3] <> aStructure[3]) .or. ;
                        (aStructureOnFile[nPos,4] <> aStructure[4])
                            lUpdateTableStructure := .t.
                            exit
                        endif
                    endif
                endfor
    
            endif
            
            dbCloseArea()
    
            if lUpdateTableStructure   // Create an new empty structure and import the data.
                select 0
                hb_FileDelete(oFcgi:PathData+cTableName+"_Conversion.*")
                DbCreate(oFcgi:PathData+cTableName+"_Conversion.dbf",aTableStructure,"DBFCDX",.t.,"Conversion",,"EN")  //Will keep open with alias "conversion"
                SetTableCodePageToEN(oFcgi:PathData+cTableName+"_Conversion.dbf")
                __dbApp(oFcgi:PathData+cTableName+".dbf", , , , , , ,"DBFCDX", ,"EN",)  //Append Records
                dbCloseArea()

                hb_FileDelete(oFcgi:PathData+cTableName+".cdx")
                hb_FileDelete(oFcgi:PathData+cTableName+".dbf")
                hb_FileDelete(oFcgi:PathData+cTableName+".ftp")

                if !hb_dbRename(oFcgi:PathData+cTableName+"_Conversion", , oFcgi:PathData+cTableName, "DBFCDX")
                    //Report it failed
                endif
    
            endif
    
        endif
    endif

    //Compare table structure
    if len(aTableTags) > 0
        if File(oFcgi:PathData+cTableName+".cdx")
            //_M_ compare tags
        else
            select 0
            if dbUseArea(.t.,"DBFCDX", oFcgi:PathData+cTableName+".dbf", cTableName, .f., .f., "EN")
                for each aTag in aTableTags
                    ordCreate(oFcgi:PathData+cTableName+".cdx",aTag[1],aTag[2],,aTag[3])
                endfor
                dbCloseArea()
            endif
        endif
    endif

endfor

return nil
//=================================================================================================================
function SetTableCodePageToEN(par_TableFullPath)
local nFileHandle
//Mark Codepage flag as "EN"
nFileHandle := FOpen(par_TableFullPath)
if nFileHandle >= 0
    FSeek(nFileHandle,29)
    FWrite(nFileHandle,chr(1),1)
    FClose(nFileHandle)
endif
return nil
//=================================================================================================================
function BuildPageHome
local cHtml := []
local cFormName
local cActionOnSubmit
local iKey
local cName,cName_ForSearch
local cErrorText := ""
local cSourceCode := ""
local cCurrentDir
local cRunResult
local cSourceCodePPO
local oHrb, uRet
local cHBheaders1 := "~/harbour/include"
local cHBheaders2 := "c:\harbour\include"
local pHbPCode
local cPRGFLAGS := ""
local oError
local bOldErrorHandler
local l_TimeStamp1,l_TimeStamp2
local bPreviousErrorHandler
local lHRBDOErrorOccurred := .t.
static ModuleCounter := 0
local cHRBName := "Main"+trans(ModuleCounter++)   //Later could make the file name unique across instances of the FastCFGI exe. Also refactor use of file "result.txt"

if OpenTable("sandprog",.t.,.f.)

    if oFcgi:IsGet()
        cHtml += BuildPageHome_BuildListForm()
    else
        //Post
        cFormName       := oFcgi:GetInputValue("formname")
        cActionOnSubmit := oFcgi:GetInputValue("ActionOnSubmit")

        do case
        case cFormName == "List"
            do case
            case cActionOnSubmit == "New"
                // altd()
                cHtml += BuildPageHome_BuildEditForm(0)

            case left(cActionOnSubmit,10) == "EditRecord"
                iKey = val(substr(cActionOnSubmit,12))

                set order to "key"
                if dbSeek(iKey)
                    cName       := allt(field->name)
                    cSourceCode := hb_MemoRead(oFcgi:PathData+"SourceCode"+oFcgi:OSPathSeparator+"SourceCode"+trans(iKey)+".prg")
                    cHtml += BuildPageHome_BuildEditForm(iKey,cErrorText,cName,cSourceCode)
                endif

            case left(cActionOnSubmit,12) == "DeleteRecord"
                iKey = val(substr(cActionOnSubmit,14))
                if iKey > 0
                    if OpenTable("sandprog",.t.,.f.)
                        set order to "key"
                        if dbSeek(iKey)
                            if dbRLock()
                                dbDelete()
                            endif
                        endif
                    endif
                endif
                cHtml += BuildPageHome_BuildListForm()

            otherwise
                cHtml += BuildPageHome_BuildListForm()

            endcase
                
        case cFormName == "Edit"
            iKey := val(oFcgi:GetInputValue("TableKey"))
            do case
            case cActionOnSubmit == "Save" .or. cActionOnSubmit == "SaveAndStay"
                cName       := allt(oFcgi:GetInputValue("TextName"))
                cSourceCode := DecodeURIComponent( oFcgi:GetInputValue("EditorValue") )

                if empty(cName)
                    cErrorText := [A "Name" is required.]
                else
                    if OpenTable("sandprog",.t.,.f.)

                        // Test to will not create a duplicate
                        cName_ForSearch := upper(strtran(cName," ",""))
                        if iKey = 0
                            locate for upper(strtran(field->name," ","")) == cName_ForSearch
                        else
                            locate for upper(strtran(field->name," ","")) == cName_ForSearch .and. field->key <> iKey
                        endif

                        if found()  //Duplicate
                            cErrorText := [Program with the same "Name" already on file.]
                        else
                            if iKey == 0
                                //New Record
                                if dbappend()
                                    Field->sysc := hb_DateTime()
                                    Field->sysm := Field->sysc
                                    field->name := cName
                                    dbRUnlock()
                                    iKey := Field->key
                                else
                                    cErrorText := [Failed to add record!]
                                endif
                            else
                                set order to "key"
                                if dbSeek(iKey) .and. dbRLock()
                                    Field->sysm := hb_DateTime()
                                    field->name := cName
                                    dbRUnlock()
                                else
                                    cErrorText := [Failed to lock record!]
                                endif
                            endif

                            if hb_DirBuild(oFcgi:PathData+"SourceCode"+oFcgi:OSPathSeparator)
                                hb_MemoWrit(oFcgi:PathData+"SourceCode"+oFcgi:OSPathSeparator+"SourceCode"+trans(iKey)+".prg",cSourceCode)
                            endif

                        endif

                    endif
                    
                endif

                if empty(cErrorText)
                    if cActionOnSubmit == "SaveAndStay"
                        cHtml += BuildPageHome_BuildEditForm(iKey,cErrorText,cName,cSourceCode)
                    else
                        cHtml += BuildPageHome_BuildListForm()
                    endif
                else
                    cHtml += BuildPageHome_BuildEditForm(iKey,cErrorText,cName,cSourceCode)
                endif

            case cActionOnSubmit == "Demo"
                cName       := allt(oFcgi:GetInputValue("TextName"))
                cSourceCode := DecodeURIComponent( oFcgi:GetInputValue("EditorValue") )

                if empty(cSourceCode)
                    cSourceCode := [#include "hbclass.ch"] + CRLF
                    cSourceCode += "function main()" + CRLF
                    cSourceCode += "local nloop" + CRLF
                    cSourceCode += "local oLocation := Location()" + CRLF
                    cSourceCode += CRLF
                    cSourceCode += "for nloop = 1 to 5" + CRLF
                    cSourceCode += '	?"Hello World "+ltrim(str(nloop))' + CRLF
                    cSourceCode += "endfor" + CRLF
                    cSourceCode += CRLF
                    cSourceCode += [?"Location = "+oLocation:cCountry+", "+oLocation:cState+", "+oLocation:cCity] + CRLF
                    cSourceCode += CRLF
                    cSourceCode += "return nil"
                    cSourceCode += CRLF
                    cSourceCode += "class Location" + CRLF
                    cSourceCode += "    //Extra Line after class to work around bug definition" + CRLF
                    cSourceCode += [    DATA cCity    init "Seattle"] + CRLF
                    cSourceCode += [    DATA cState   init "Washington"] + CRLF
                    cSourceCode += [    DATA cCountry init "United States of America"] + CRLF
                    cSourceCode += "endclass" + CRLF
                    
                else
                    cErrorText := [Remove any source code before using the "Demo" option.]
                endif
                
                cHtml += BuildPageHome_BuildEditForm(iKey,cErrorText,cName,cSourceCode,cRunResult)

            case cActionOnSubmit == "Run"
                oFcgi:ShutDownFastCGIEXEAfterResponse()   //Needed in case the code defined some new classes
                l_TimeStamp1 := hb_DateTime()

                cName       := allt(oFcgi:GetInputValue("TextName"))
                cSourceCode := DecodeURIComponent( oFcgi:GetInputValue("EditorValue") )
                cRunResult  := ""

                // _M_ Todo: Make this multi fcgi instance aware.

                if hb_DirBuild(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator)

                    if empty(cSourceCode)
                        cErrorText := [Enter some source code first, or use the "Demo" button.]
                    else
                        hb_MemoWrit(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+cHRBName+".prg",cSourceCode)  // For debugging
                        cCurrentDir := hb_cwd(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator)

                        //Current directory
                        FErase(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt")
                        FcgiLogger( 1 )

                        try
                            cSourceCodePPO = __pp_process( v_hPP, cSourceCode )
                            hb_MemoWrit(cHRBName+".ppo",cSourceCodePPO)  // Using while testing this routine
                        catch oError
                            hb_MemoWrit(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt","Preprocessor Error")
                            cSourceCodePPO := ""
                            oHrb := ""
                        endtry

                        if !empty(cSourceCodePPO)
                            try
                                oHrb = HB_CompileFromBuf( cSourceCodePPO, .T., "-n","-I"+cHBheaders1, "-I"+cHBheaders2,"-I"+hb_GetEnv( "HB_INCLUDE" ) )
                                hb_MemoWrit(cHRBName+".hrb",oHrb)
                            catch oError
                                oHrb := ""
                                hb_MemoWrit(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt","<b>Compilation Error:</b><br>"+FcgiGetErrorInfo(oError))
                            endtry
                        endif

                        if !empty(oHrb)

                            //Will be passing cSourceCode by reference since would be out of scope otherwise
                            try
                                pHbPCode := hb_HrbLoad(1,oHrb)
                                // Set_AP_FileName(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+cHRBName+".prg")  // Was testing debugging with VSCODE

                                //Have to use the ErrorBlock() construct to catch the line number of the underlying PRG
                                try
                                    bPreviousErrorHandler := ErrorBlock( { | oError | hb_MemoWrit(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt", "<b>Execution Run Error:</b><br>"+FcgiGetErrorInfo( oError, @cSourceCode ,2 ) ), Break(oError) } )
                                    uRet = hb_HrbDo(pHbPCode, )
                                    FcgiLogger( 4, oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt" )
                                    lHRBDOErrorOccurred := .f.
                                catch oError
                                    // hb_MemoWrit(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt","Execution Error<br>"+FcgiGetErrorInfo(oError,@cSourceCode))
                                endtry
                                ErrorBlock(bPreviousErrorHandler)

                                hb_hrbUnload(pHbPCode)

                            catch oError
                                hb_MemoWrit(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt","<b>Execution Load Error:</b><br>"+FcgiGetErrorInfo(oError,@cSourceCode))

                            endtry

                        endif

                        if file(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt")
                            cRunResult := iif(lHRBDOErrorOccurred,"","<b>Run Result:</b><br>")
                            cRunResult += hb_MemoRead(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+"result.txt")
                            // altd()
                            cRunResult := strtran(cRunResult,CRLF,"<br>")

                        endif
                    endif

                    hb_FileDelete(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+cHRBName+".prg")
                    hb_FileDelete(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+cHRBName+".ppo")
                    hb_FileDelete(oFcgi:PathBackend+"CompileAndRun"+oFcgi:OSPathSeparator+cHRBName+".hrb")

                    hb_cwd(cCurrentDir)
                else
                    cErrorText := [Could not create "CompileAndRun" folder.]
                endif
                l_TimeStamp2 := hb_DateTime()

                if empty(cErrorText) .and. !Empty(cRunResult)
                    cRunResult := [<p>Compile and Run Time = ]+trans((l_TimeStamp2-l_TimeStamp1)*(24*3600*1000))+[ (ms)</p>] + cRunResult
                endif

                cHtml += BuildPageHome_BuildEditForm(iKey,cErrorText,cName,cSourceCode,cRunResult)

            otherwise
                cHtml += BuildPageHome_BuildListForm()
            endcase
        endcase

    endif

    (select("sandprog"))->(dbCloseArea())
endif

return cHtml
//=================================================================================================================
function BuildPageHome_BuildListForm()
local cHtml := ""
local cHtmlNewButton := [<input type="button" class="btn btn-primary" value="New" onclick="$('#ActionOnSubmit').val('New');document.form.submit();" role="button">]


cHtml += [<form action="" method="post" name="form">]
cHtml += [<input type="hidden" name="formname" value="List">]
cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]

cHtml += [<div class="m-2">]

    if OpenTable("sandprog",.t.,.f.)
        select sandprog
        set order to "tag1"
        goto top

        if eof()
            cHtml += [<div class="input-group">]
            cHtml += "<span>No programs on file, create your first one.<span>&nbsp;"
            cHtml += cHtmlNewButton
            cHtml += [</div>]
        else
            cHtml += [<table border="1" cellpadding="3" cellspacing="0">]
            cHtml += [<tr">]
            cHtml += [<th class="GridHeaderTopLeftCell text-center">]+cHtmlNewButton+[</th>]
            cHtml += [<th class="GridHeaderRowCells"><span>Name</span></th>]
            cHtml += [<th class="GridHeaderRowCells"><span>Last Updated On</span></th>]
            cHtml += [</tr>]

            scan for !deleted()
                cHtml += [<tr>]
                cHtml += [<td class="GridDataControlCells">]+;
                            [<input type="button" class="btn btn-primary" value="Edit" onclick="$('#ActionOnSubmit').val('EditRecord-]+trans(field->key)+[');document.form.submit();" role="button">]+;
                            [&nbsp;]+;
                            [<input type="button" class="btn btn-primary" value="Del" onclick="ConfirmDelete('DeleteRecord-]+trans(field->key)+[');" role="button">]+;
                            [</td>]
                cHtml += [<td class="GridDataRowCells">]+Allt(field->name)+[</td>]
                cHtml += [<td class="GridDataRowCells">]+hb_TtoC(field->sysm,"MM/DD/YYYY","HH:MM:SS PM")+[</td>]
                cHtml += [</tr>]
            endscan
            cHtml += [</table>]
            
        endif

        cHtml += GetConfirmationModalForms()

        cHtml += [</form>]
    endif

cHtml += [</div>]

return cHtml
//=================================================================================================================
function BuildPageHome_BuildEditForm(par_iKey,par_cErrorText,par_cName,par_cSourceCode,par_cLastRunResult)

local cHtml := ""
local cErrorText     := hb_DefaultValue(par_cErrorText,"")
local cName          := hb_DefaultValue(par_cName,"")
local cSourceCode    := hb_DefaultValue(par_cSourceCode,"")
local cLastRunResult := hb_DefaultValue(par_cLastRunResult,"")

local aLines
local cLine
local iNumberOfLines
local iLineCounter
local cMonacoValue := ""

//altd()

cHtml += [<form action="" method="post" name="form" enctype="multipart/form-data">] //Since there are text fields entry fields, encode as multipart/form-data
cHtml += [<input type="hidden" name="formname" value="Edit">]
cHtml += [<input type="hidden" id="ActionOnSubmit" name="ActionOnSubmit" value="">]
cHtml += [<input type="hidden" name="TableKey" value="]+trans(par_iKey)+[">]

cHtml += [<input type="hidden" id="EditorValue" name="EditorValue" value="">]

aLines := hb_ATokens(   StrTran(StrTran(cSourceCode,chr(13)+chr(10),chr(10)),chr(13),chr(10))    ,chr(10),.f.,.f.)
iNumberOfLines := len(aLines)

for iLineCounter := 1 to iNumberOfLines
    cLine := aLines[iLineCounter]

    cLine := strtran(cLine,"\"   ,"\\")
    cLine := strtran(cLine,chr(9),"\t")
    cLine := strtran(cLine,"'"   ,"\'")

    cMonacoValue += space(8)+"'"+cLine+iif(iLineCounter < iNumberOfLines,"',"+ CRLF,"'")

endfor

if !empty(par_cErrorText)
    cHtml += [<div class="p-3 mb-2 bg-danger text-white">]+cErrorText+[</div>]
endif

cHtml += [<div class="m-2">]
    cHtml += [<div>]
    cHtml += [<span><input type="button" class="btn btn-primary" value="Save" onclick="$('#ActionOnSubmit').val('Save');$('#EditorValue').val( encodeURIComponent(window.var1.getValue()) );document.form.submit();" role="button"></span>]
    cHtml += [&nbsp;<span><input type="button" class="btn btn-primary" value="Save And Stay" onclick="$('#ActionOnSubmit').val('SaveAndStay');$('#EditorValue').val( encodeURIComponent(window.var1.getValue()) );document.form.submit();" role="button"></span>]
    cHtml += [&nbsp;<span><input type="button" class="btn btn-primary" value="Demo" onclick="$('#ActionOnSubmit').val('Demo');$('#EditorValue').val( encodeURIComponent(window.var1.getValue()) );document.form.submit();" role="button"></span>]
    cHtml += [&nbsp;<span><input type="button" class="btn btn-primary" value="Cancel" onclick="$('#ActionOnSubmit').val('Cancel');document.form.submit();" role="button"></span>]
    cHtml += replicate([&nbsp;],5) +[<span><input type="button" class="btn btn-primary" value="Run" onclick="$('#ActionOnSubmit').val('Run');$('#EditorValue').val( encodeURIComponent(window.var1.getValue()) );document.form.submit();" role="button"></span>&nbsp;]

    cHtml += [</div>]

    cHtml += [<br>]

    cHtml += [<div><span>Name<span>&nbsp;<span><input type="text" name="TextName" id="TextName" value="]+FcgiPrepFieldForValue(cName)+[" maxlength="180" size="80"></span></div>]

    cHtml += [<br>]

    if empty(cLastRunResult)
        cHtml += [<div id="container" style="width:800px;height:600px;border:1px solid grey"></div>]
    else
        cHtml += [<table border="0" cellpadding="0" cellspacing="0"><tr>]
        cHtml += [<td valign="top"><div id="container" style="width:800px;height:600px;border:1px solid grey"></div></td>]
        cHtml += [<td valign="top" class="pl-2"><div class="p-3 bg-light"><div>]
        cHtml += cLastRunResult
        cHtml += [</div></td>]
        cHtml += [</tr></table>]
    endif

    cHtml += [<script>$('#container').resizable();</script>]
    
cHtml += [</div>]

cHtml += [<script src="monaco-editor/min/vs/loader.js"></script>] + CRLF

cHtml += [<script language="javascript" type="text/javascript">] + CRLF

cHtml += "require.config({ paths: { 'vs': 'monaco-editor/min/vs' }});" + CRLF
cHtml += "require(['vs/editor/editor.main'], function() {" + CRLF
cHtml += "var editor = monaco.editor.create(document.getElementById('container'), {" + CRLF
cHtml += "    value: [" + CRLF
cHtml += cMonacoValue
cHtml += "    ].join('\n')," + CRLF
cHtml += "    language: 'plaintext'," + CRLF
cHtml += "    automaticLayout: true," + CRLF  //To make it follow the resizing
cHtml += "    wordBasedSuggestions: false" + CRLF
cHtml += "});" + CRLF
cHtml += "window.var1 = editor;" + CRLF
cHtml += "});" + CRLF

cHtml += "</script>" + CRLF

cHtml += "<script>" + CRLF
cHtml += "    $('#TextName').focus();" + CRLF
cHtml += "</script>" + CRLF

cHtml += [</form>]

return cHtml
//=================================================================================================================
function OpenTable(par_cTableName,par_lShared,par_lReadOnly)
local lResult
(select(par_cTableName))->(dbCloseArea())
if (lResult := dbUseArea(.t.,"DBFCDX", oFcgi:PathData+par_cTableName+".dbf", par_cTableName, par_lShared, par_lReadOnly, "EN"))
    select (par_cTableName)
else
    select 0
endif
return lResult
//=================================================================================================================
function GetConfirmationModalForms()
local cHtml

TEXT TO VAR cHtml
<script>
   
function ConfirmDelete(par_Action) {
    $('#modal').find('.modal-title').text('Confirm Delete?');
    $('#modal-btn-yes').click(function(){$('#ActionOnSubmit').val(par_Action);document.form.submit(); });
    $('#modal').modal({show:true});
} ;
   
</script>

<div class="modal fade " id="modal">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h4 class="modal-title">Are You Sure?</h4>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                This action cannot be undone.
            </div>
            <div class="modal-footer">
                <a id="modal-btn-yes" class="btn btn-danger" >Yes</a>
                <button type="button" class="btn btn-primary" data-dismiss="modal">No</button>
            </div>
        </div>
    </div>
</div>
ENDTEXT

return cHtml
//=================================================================================================================
function GetPageHeader()
local cHtml

TEXT TO VAR cHtml
    <nav class="navbar navbar-default bg-secondary">
        <div class="container">
            <div class="navbar-header">
                <a class="navbar-brand text-white" href="home">FastCGI Harbour - Local Sandbox</a>
            </div>
        </div>
    </nav>
ENDTEXT

return cHtml
//=================================================================================================================
