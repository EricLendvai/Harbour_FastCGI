//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_fcgi.ch"
#include "hbhrb.ch"

// #include "hbhrb.ch"
// #include "hbclass.ch"
// #include "Directry.ch"
// #include "common.ch"
// static oFcgi := NIL

//=================================================================================================================

Function Main()

local cInput := ""
local cQUERY_STRING := ""
local cVar
local cURL
local cPRGName
local nPos
local cMod_HarbourRootFolder
local cDynamicHRBFolder
local cFileName_prg,cFileName_hrb,cCode,oHrb
local t_fileTime_hrb
local t_fileTime_prg
local lDebugMode
local lCompileToHrb
local cPRGFLAGS
local cHBheaders1 := "c:\harbour\include"
local pHbPCode
local uRet

SendToDebugView("Starting mod_harbour")

oFcgi := hb_Fcgi():New()

do while oFcgi:Wait()

    ? "<!DOCTYPE html>"

    ? "<h1>FastCGI mod_harbour 008</h1>"

    ? "<p>Request Count = "+Trans( oFcgi:RequestCount )+"</p>"

    ? "<p>Input Length = "+Trans( oFcgi:GetInputLength() )+"</p>"

    ? "<p>Query Parameter name1 = "+oFcgi:GetQueryString("namE1")+"</p>"

    cURL     := oFcgi:GetEnvironment("REDIRECT_URL")
    ? "<p>cURL = "+cURL+"</p>"

    cQUERY_STRING := oFcgi:GetEnvironment("QUERY_STRING")
    ? "<p>QUERY_STRING = "+cQUERY_STRING+"</p>"

    cInput := oFcgi:GetRawInput()
    ? "<p>INPUT = "+cInput+"</p>"

    ? "<p>hb_DirBase = "+hb_DirBase()+"</p>"


    ? "<p>FirstName = "+oFcgi:GetInputValue("FirstName")+"</p>"

    //Extract the prg name that was asked for
    cPRGName := ""
    nPos := rat("/",cURL)
    if !empty(nPos)
        cPRGName := substr(cURL,nPos+1)
        nPos := at("?",cPRGName)
        if !empty(nPos)
            cPRGName := left(cPRGName,nPos-1)
        endif
        // if upper(right(cPRGName,4)) $ {".PRG",".HRB"}   // This would require xharbour compatibility I think.
        if "*"+upper(right(cPRGName,4)) $ "*.PRG*.HRB"     // Later can use a vfp_inlist() instead
            cPRGName := left(cPRGName,len(cPRGName)-4)
        endif
    endif
    if !empty(cPRGName)
        ? "<p>cPRGName = "+cPRGName+"</p>"

        cMod_HarbourRootFolder := oFcgi:GetAppConfig("ProgramsFolder")
        cDynamicHRBFolder      := oFcgi:GetAppConfig("DynamicHRBFolder")
        lDebugMode             := file(cDynamicHRBFolder+"Mod_Harbour_Debugger.txt")

        do case
        case empty(cMod_HarbourRootFolder)
            ? [<p>Missing "ProgramsFolder" setting in "config.txt".</p>]
        case !hb_DirExists(cMod_HarbourRootFolder)
            ? [<p>Could not locate folder: ]+cMod_HarbourRootFolder+[. Update "ProgramsFolder" setting in "config.txt".</p>]
        case empty(cDynamicHRBFolder)
            ? [<p>Missing "DynamicHRBFolder" setting in "config.txt".</p>]
        case !hb_DirExists(cDynamicHRBFolder)
            ? [<p>Could not locate folder: ]+cDynamicHRBFolder+[. Update "DynamicHRBFolder" setting in "config.txt".</p>]
        otherwise
            cFileName_prg := cMod_HarbourRootFolder+cPRGName+".prg"
            //TODO. Add code to auto add the folder. Use function that is OS aware to add the "\".
            cFileName_hrb := cDynamicHRBFolder+iif(lDebugMode,"debug","release")+"\"+cPRGName+".hrb"

            SendToDebugView("cFileName_hrb = "+cFileName_hrb)
            // Altd()

            if file(cFileName_prg)
                Set_AP_FileName(cFileName_prg)

                //Since mod_harbour has some pre-text compilation instructions in the PRG,s will always have to load it, in case needed. Idea later to extract those instructions and store them in a separate file.
                cCode = hb_MemoRead(cFileName_prg)
                if empty(cCode)
                    oHrb := ""
                else
                    lCompileToHrb := !( hb_FGetDateTime(cFileName_hrb , @t_fileTime_hrb) .and. hb_FGetDateTime(cFileName_prg , @t_fileTime_prg) .and. (t_fileTime_hrb == t_fileTime_prg))
                    if lCompileToHrb
                        SendToDebugView("Compiling "+cFileName_prg+" in "+iif(lDebugMode,"debug","release")+" mode.")
                        cPRGFLAGS := oFcgi:GetAppConfig( "HB_USER_PRGFLAGS" )
                        if lDebugMode
                            if !("-B" $ cPRGFLAGS)
                                cPRGFLAGS += "-B"
                            endif
                        else
                            if "-B" $ cPRGFLAGS
                                cPRGFLAGS = strtran(cPRGFLAGS,"-B","")
                            endif
                        endif

                        // altd()

                        oHrb = HB_CompileFromBuf( cCode, .T., "-n", "-I" + cHBheaders1, "-I" + oFcgi:GetAppConfig( "HB_INCLUDE" ), cPRGFLAGS )
                        if empty(oHrb)
                            ? [Failed to compile "]+cFileName_prg+[" in "]+iif(lDebugMode,"debug","release")+[" mode.]
                            cCode := ""
                        else
                            hb_vfErase(cFileName_hrb)
                            hb_MemoWrit(cFileName_hrb, oHrb)
                            hb_FSetDateTime(cFileName_hrb, t_fileTime_prg)
                        endif
                    else
                        oHrb = hb_MemoRead(cFileName_hrb)
                    endif
                endif
            else
                cCode := ""
                oHrb  := ""
            endif

            if !empty(cCode) .and. !empty(oHrb)
                // if lDebugMode
                //     //To work around debugger starting at first line of execution.  DOES NOT WORK. BUG in Harbour VSCODE extension
                //     Altd(0)
                //     Altd(1)
                // endif
                pHbPCode := hb_HrbLoad( 1, oHrb )
                uRet = hb_HrbDo( pHbPCode )   //, ...
                // altd()
                hb_hrbUnload( pHbPCode )
            endif

        endcase

    endif

    hb_Fcgi_PrintEnvironment()

enddo

SendToDebugView("Done")

oFcgi := NIL

return NIL

//=================================================================================================================
