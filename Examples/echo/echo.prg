//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_fcgi.ch"

//=================================================================================================================

Function Main()

local cHtml
// local cCrash  // To test the error handler

SendToDebugView("Starting echo")

// oFcgi := hb_Fcgi():New()
oFcgi := MyFcgi():New()    // Used a subclass of hb_Fcgi

do while oFcgi:Wait()
    SendToDebugView("Request Counter",oFcgi:RequestCount)

    oFcgi:Print([<!DOCTYPE html><html><body>])

    // Following can be used to test the VSCODE debugger
    // altd()
    //cCrash++    // To test the error handler

    oFcgi:Print("<h1>FastCGI echo</h1>")
    oFcgi:Print("<p>FastCGI EXE   = "+oFcgi:FastCGIExeFullPath+"</p>")

    cHtml := [<table border="1" cellpadding="3" cellspacing="0">]
    cHtml += [<tr><td>Protocol</td>]     +[<td>]+oFcgi:RequestSettings["Protocol"]+[</td></tr>]
    cHtml += [<tr><td>Port</td>]         +[<td>]+trans(oFcgi:RequestSettings["Port"])+[</td></tr>]
    cHtml += [<tr><td>Host</td>]         +[<td>]+oFcgi:RequestSettings["Host"]+[</td></tr>]
    cHtml += [<tr><td>Site Path</td>]    +[<td>]+oFcgi:RequestSettings["SitePath"]+[</td></tr>]
    cHtml += [<tr><td>Path</td>]         +[<td>]+oFcgi:RequestSettings["Path"]+[</td></tr>]
    cHtml += [<tr><td>Page</td>]         +[<td>]+oFcgi:RequestSettings["Page"]+[</td></tr>]
    cHtml += [<tr><td>Query String</td>] +[<td>]+oFcgi:RequestSettings["QueryString"]+[</td></tr>]
    cHtml += [<tr><td>Web Server IP</td>]+[<td>]+oFcgi:RequestSettings["WebServerIP"]+[</td></tr>]
    cHtml += [<tr><td>Clien IP</td>]     +[<td>]+oFcgi:RequestSettings["ClienIP"]+[</td></tr>]
    cHtml += [</table>]
    oFcgi:Print(cHtml)
 

    // oFcgi:Print("<p>SCRIPT_NAME   = "+oFcgi:GetEnvironment("SCRIPT_NAME")+"</p>")
    // oFcgi:Print("<p>REQUEST_URI   = "+oFcgi:GetEnvironment("REQUEST_URI")+"</p>")
    // oFcgi:Print("<p>REDIRECT_URL  = "+oFcgi:GetEnvironment("REDIRECT_URL")+"</p>")
    // oFcgi:Print("<p>QUERY_STRING  = "+oFcgi:GetEnvironment("QUERY_STRING")+"</p>")
    oFcgi:Print("<p>Request Count = "+Trans( oFcgi:RequestCount )+"</p>")
    oFcgi:Print("<p>Input Length  = "+Trans( oFcgi:GetInputLength() )+"</p>")

    // Following will be abstracted to assist in making FastCGI platform independent.
    oFcgi:Print("<p>Request Environment:</p>")
    oFcgi:Print(oFcgi:ListEnvironment())

    oFcgi:Print([<p>Input Field "FirstName" = ]+oFcgi:GetInputValue("FirstName")+[</p>])
    oFcgi:Print([<p>Input Field "LastName" = ]+oFcgi:GetInputValue("LastName")+[</p>])
    oFcgi:Print([<p>Input Field "NotExistingValue" = ]+oFcgi:GetInputValue("Bogus")+[</p>])

    oFcgi:Print([<p>Uploaded File Name "File1" = ]+oFcgi:GetInputFileName("File1")+[</p>])
    oFcgi:Print([<p>Uploaded File Content Type "File1" = ]+oFcgi:GetInputFileContentType("File1")+[</p>])

    // oFcgi:SaveInputFileContent("File1","d:\281\"+oFcgi:GetInputFileName("File1"))
    // oFcgi:SaveInputFileContent("File2","d:\281\"+oFcgi:GetInputFileName("File2"))
    // oFcgi:SaveInputFileContent("File3","d:\281\"+oFcgi:GetInputFileName("File3"))
    // oFcgi:SaveInputFileContent("File4","d:\281\"+oFcgi:GetInputFileName("File4"))
    oFcgi:Print([</body></html>])

enddo

SendToDebugView("Done")

return nil

//=================================================================================================================

class MyFcgi from hb_Fcgi
    method OnFirstRequest()
    method OnShutdown()
endclass

method OnFirstRequest() class MyFcgi
    SendToDebugView("Called from method OnFirstRequest")
return nil 

method OnShutdown() class MyFcgi
    SendToDebugView("Called from method OnShutdown")
return nil 

//=================================================================================================================
