#xcommand TRY => BEGIN SEQUENCE WITH __BreakBlock()
#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->
#xcommand FINALLY => ALWAYS
#xcommand ENDTRY => END
#xcommand ENDDO => END
#xcommand ENDFOR => END

#define CRLF chr(13)+chr(10)

// #xtranslate Allt( <x> )    => alltrim( <x> )
// #xtranslate Trans( <x> )   => alltrim( str(<x>,10) )
 
function Main()
   local cAction
   local cURL
   local cProtocol
   local cPort
   local cDomain
   local cURLPath
   local cSiteRootFolder
   local cSiteBackendFolder
   local cSiteWebsiteFolder
   local cFcgiAppName
   local cFcgiExeName
   local cFcgiVersion
   local oScriptObj
   local oWmiService
   local oListOfProcess
   local oProcess
   local cProcessName
   local oHttp
   local oError
   local cConfig
   local aListExeToMarkAsKill,aExeToMarkAsKill
   local cExeFileName,cKillFileName
 
   cAction         := upper(hb_argv(1))
   cProtocol       := hb_argv(2)
   cDomain         := hb_argv(3)
   cPort           := hb_argv(4)
   cURLPath        := hb_argv(5)
   cSiteRootFolder := hb_argv(6)
   cFcgiAppName    := hb_argv(7)
   cFcgiVersion    := hb_argv(8)

   if empty(cAction)
      ? [Missing "Action"]

   elseif !(cAction == "KILL" .or. cAction == "DOWN" .or. cAction == "ACTIVATE")
      ? ["Action" must be "kill", "down" or "activate"]
      cAction := ""

   endif

   if !empty(cAction)
      if !(cProtocol == "http" .or. cProtocol == "https")
         ? ["Protocol" must be "http" or "https"]
         cAction := ""
      elseif empty(cDomain)
         ? [Missing "Domain"]
         cAction := ""
      elseif empty(cPort)
         ? [Missing "Port"]
         cAction := ""
      elseif val(cPort) < 80
         ? ["Port" must be a numeric >= 80]
         cAction := ""
      elseif empty(cURLPath)
         ? [Missing "URLPath". Use "/" for root.]
         cAction := ""
      elseif empty(cSiteRootFolder)
         ? [Missing "SiteRootFolder"]
         cAction := ""
      elseif !hb_DirExists(cSiteRootFolder)
         ? [Missing Directory "SiteRootFolder"]
         cAction := ""
      elseif !hb_DirExists(cSiteRootFolder+"backend\")
         ? [Missing Directory "SiteBackendFolder"]
         cAction := ""
      elseif !hb_DirExists(cSiteRootFolder+"website\")
         ? [Missing Directory "SiteWebsiteFolder"]
         cAction := ""
      elseif empty(cFcgiAppName)
         ? [Missing "FcgiAppName"]
         cAction := ""
      endif
   endif

   if !empty(cAction)
      cSiteBackendFolder := strtran(cSiteRootFolder+"backend\","/","\")
      cSiteWebsiteFolder := strtran(cSiteRootFolder+"website\","/","\")

      cFcgiExeName := "FCGI"+cFcgiAppName

      //Later will try to use curl instead.
      cURL := cProtocol+"://"+cDomain+":"+cPort+cURLPath
      
      do case
      case cAction == "KILL"
         //Will mark to Stop the specfic EXE
         hb_MemoWrit(cSiteBackendFolder+cFcgiExeName+cFcgiVersion+".kill","ShutdownMarker")

      case cAction == "DOWN"
         //On purpose don't force all to down.html yet, since the "kills" have to be processed.

         //Will mark to Stop all EXEs
         aListExeToMarkAsKill := hb_Directory(cSiteBackendFolder+cFcgiExeName+"*.exe")
         for each aExeToMarkAsKill in aListExeToMarkAsKill
            cExeFileName := aExeToMarkAsKill[1]
            cKillFileName := left(cExeFileName,len(cExeFileName)-3)+"kill"
            if !File(cSiteBackendFolder+cKillFileName)
               hb_MemoWrit(cSiteBackendFolder+cKillFileName,"ShutdownMarker")
            endif
         endfor

      case cAction == "ACTIVATE"
         //Blindly try to delete the .kill marker file
         DeleteFile(cSiteBackendFolder+cFcgiExeName+cFcgiVersion+".kill")

         //Will mark the EXE as default FastCGI exe
         cConfig := 'FallbackResource '+cURLPath+'AnyFile.fcgiexe' + CRLF
         cConfig += 'FcgidWrapper "'+strtran(cSiteBackendFolder,"\","/")+cFcgiExeName+cFcgiVersion+'.exe" .fcgiexe virtual'
         hb_MemoWrit(cSiteWebsiteFolder+".htaccess",cConfig)
         
         WaitPeriod(50)  //Wait 0.5 seconds, to ensure Apache will detech changes and redirect request to the activated version

         //Will stop any other versions
         aListExeToMarkAsKill := hb_Directory(cSiteBackendFolder+cFcgiExeName+"*.exe")
         for each aExeToMarkAsKill in aListExeToMarkAsKill
            cExeFileName  := aExeToMarkAsKill[1]
            cKillFileName := left(cExeFileName,len(cExeFileName)-3)+"kill"
            if lower(cExeFileName) <> lower(cFcgiExeName+cFcgiVersion+".exe")
               if !File(cSiteBackendFolder+cKillFileName)
                  hb_MemoWrit(cSiteBackendFolder+cKillFileName,"ShutdownMarker")
               endif
            endif
         endfor

      endcase
      
      try
         //oHttp := win_oleCreateObject("MSXML2.XMLHTTP.6.0")  This control May cache requests
         oHttp := win_oleCreateObject("MSXML2.ServerXMLHTTP")
      catch oError
         ? [Failed to initilalize HTTP object. Error message: ]+oError:Description
         oHttp := nil
      endtry

      if oHttp <> nil
         try
            oScriptObj     := win_OleCreateObject([wbemScripting.SwbemLocator])
            oWmiService    := oScriptObj:ConnectServer()
            oListOfProcess := oWmiService:ExecQuery("select * from Win32_Process")
         catch
            oListOfProcess := {}
         endtry
         
         for each oProcess in oListOfProcess
            cProcessName := oProcess:Name()
            if lower(left(cProcessName,len(cFcgiExeName))) <> lower(cFcgiExeName)  // Not our FCGI App.
               loop
            endif
            if lower(right(cProcessName,4)) == ".exe"  //  Windows specific (.exe)
               cProcessName := left(cProcessName,len(cProcessName)-4)
            endif
            
            if cAction == "ACTIVATE"
               if lower(cProcessName) == lower(cFcgiExeName+cFcgiVersion)
                  //Will not stop the EXE we are trying to activate
                  loop
               endif
            elseif cAction == "KILL"
               if lower(cProcessName) <> lower(cFcgiExeName+cFcgiVersion)
                  //Will only stop the EXE we are trying to stop, not any other version
                  loop
               endif

            endif
            try
               oHttp:Open( "GET", cURL+cProcessName+".exe", .f. )   // .f. = Synchronous  And Windows specific (.exe)
               oHttp:Send()
            catch oError
               ? [Failed to execute HTTP GET. Error message: ]+oError:Description
               loop
            endtry
            
         endfor

         oHttp := nil
      endif

      do case
      case cAction == "KILL"
         //Will re-enable the FastCGI EXE
         //Blindly try to delete the .kill marker file
         DeleteFile(cSiteBackendFolder+cFcgiExeName+cFcgiVersion+".kill")

      case cAction == "DOWN"
         cConfig := 'RewriteRule "^" "'+cURLPath+'down.html" [END]'
         hb_MemoWrit(cSiteWebsiteFolder+".htaccess",cConfig)
         
      case cAction == "ACTIVATE"
         //Already did to all the correct setups before the down loop

      endcase
   
   endif

return nil
//=================================================================================================================
// function SendToClipboard(cText)
//    wvt_SetClipboard(cText)
// return .T.
//=================================================================================================================
