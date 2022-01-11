//Copyright (c) 2021 Eric Lendvai MIT License

#include "hb_fcgi.ch"

//=================================================================================================================
Function Main()

local cHtml
// local cCrash  // To test the error handler

SendToDebugView("Starting echo")

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
endclass
//-----------------------------------------------------------------------------------------------------------------
method OnFirstRequest() class MyFcgi
    SendToDebugView("Called from method OnFirstRequest")
return nil 
//-----------------------------------------------------------------------------------------------------------------
method OnShutdown() class MyFcgi
    SendToDebugView("Called from method OnShutdown")
return nil 
//-----------------------------------------------------------------------------------------------------------------
method OnRequest() class MyFcgi
    local cHtml

    SendToDebugView("Request Counter",::RequestCount)

    ::Print([<!DOCTYPE html><html><body>])

    // Following can be used to test the VSCODE debugger
    // altd()
    //cCrash++    // To test the error handler

    ::Print("<h1>FastCGI echo</h1>")
    
    ::Print("<p>FastCGI EXE = "+::FastCGIExeFullPath+"</p>")
    cHtml := [<table border="1" cellpadding="3" cellspacing="0">]
    cHtml += [<tr><td>Protocol</td>]     +[<td>]+::RequestSettings["Protocol"]+[</td></tr>]
    cHtml += [<tr><td>Port</td>]         +[<td>]+trans(::RequestSettings["Port"])+[</td></tr>]
    cHtml += [<tr><td>Host</td>]         +[<td>]+::RequestSettings["Host"]+[</td></tr>]
    cHtml += [<tr><td>Site Path</td>]    +[<td>]+::RequestSettings["SitePath"]+[</td></tr>]
    cHtml += [<tr><td>Path</td>]         +[<td>]+::RequestSettings["Path"]+[</td></tr>]
    cHtml += [<tr><td>Page</td>]         +[<td>]+::RequestSettings["Page"]+[</td></tr>]
    cHtml += [<tr><td>Query String</td>] +[<td>]+::RequestSettings["QueryString"]+[</td></tr>]
    cHtml += [<tr><td>Web Server IP</td>]+[<td>]+::RequestSettings["WebServerIP"]+[</td></tr>]
    cHtml += [<tr><td>Client IP</td>]    +[<td>]+::RequestSettings["ClientIP"]+[</td></tr>]
    cHtml += [<tr><td>Build Info</td>]   +[<td>]+hb_buildinfo()+[</td></tr>]
    cHtml += [</table>]
    ::Print(cHtml)

    // ::Print([<p>]+::GenerateRandomString(16,"01234567890ABCDEF")+[</p>])

// altd()

// cCrash += 0

    // ::Print("<p>SCRIPT_NAME   = "+::GetEnvironment("SCRIPT_NAME")+"</p>")
    // ::Print("<p>REQUEST_URI   = "+::GetEnvironment("REQUEST_URI")+"</p>")
    // ::Print("<p>REDIRECT_URL  = "+::GetEnvironment("REDIRECT_URL")+"</p>")
    // ::Print("<p>QUERY_STRING  = "+::GetEnvironment("QUERY_STRING")+"</p>")
    ::Print("<p>Request Count = "+Trans( ::RequestCount )+"</p>")
    ::Print("<p>Input Length  = "+Trans( ::GetInputLength() )+"</p>")

    // Following will be abstracted to assist in making FastCGI platform independent.


    ::Print([<p>Input Field "FirstName" = ]+::GetInputValue("FirstName")+[</p>])
    ::Print([<p>Input Field "LastName" = ]+::GetInputValue("LastName")+[</p>])
    ::Print([<p>Input Field "NotExistingValue" = ]+::GetInputValue("Bogus")+[</p>])

    ::Print([<p>Uploaded File Name "File1" = ]+::GetInputFileName("File1")+[</p>])
    ::Print([<p>Uploaded File Content Type "File1" = ]+::GetInputFileContentType("File1")+[</p>])

    // ::SaveInputFileContent("File1","d:\281\"+::GetInputFileName("File1"))
    // ::SaveInputFileContent("File2","d:\281\"+::GetInputFileName("File2"))
    // ::SaveInputFileContent("File3","d:\281\"+::GetInputFileName("File3"))
    // ::SaveInputFileContent("File4","d:\281\"+::GetInputFileName("File4"))

    ::Print("<p>Request Environment:</p>")
    ::Print(::ListEnvironment())

    ::Print([</body></html>])

    // ::Redirect("/fcgi_localsandbox/home?action=cancel")
    

    // ::SetCookieValue("MyCookie1","123",1,)
    // ::SetCookieValue("MyCookie2","456",2,"/Bogus/")

    // ::DeleteCookie("MyCookie1")
    // ::DeleteCookie("MyCookie2","/Bogus/")


//    ::SetCookieValue("MyCookie2","123",1,"/Bogus/")
    // ::SetCookieValue("MyCookie2","456a")

return nil
//=================================================================================================================
function hb_buildinfo()
#include "BuildInfo.txt"
return l_cBuildInfo
//=================================================================================================================
