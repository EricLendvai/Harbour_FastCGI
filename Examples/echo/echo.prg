#include "hb_fcgi.ch"

//=================================================================================================================

Function Main()

local iInputLength := 0
local cInput := ""
local cQUERY_STRING := ""
local cVar

SendToDebugView("Starting echo")

oFcgi := hb_Fcgi():New()

do while oFcgi:Wait()
    oFcgi:Print("<h1>FastCGI echo version 104</h1>")
    
    oFcgi:Print("<p>FastCGI EXE   = "+oFcgi:FastCGIExeFullPath+"</p>")
    oFcgi:Print("<p>SCRIPT_NAME   = "+oFcgi:GetEnvironment("SCRIPT_NAME")+"</p>")
    oFcgi:Print("<p>REQUEST_URI   = "+oFcgi:GetEnvironment("REQUEST_URI")+"</p>")
    oFcgi:Print("<p>REDIRECT_URL  = "+oFcgi:GetEnvironment("REDIRECT_URL")+"</p>")
    oFcgi:Print("<p>QUERY_STRING  = "+oFcgi:GetEnvironment("QUERY_STRING")+"</p>")
    oFcgi:Print("<p>Request Count = "+Trans( oFcgi:RequestCount )+"</p>")
    oFcgi:Print("<p>Input Length  = "+Trans( oFcgi:GetInputLength() )+"</p>")

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

enddo

SendToDebugView("Done")

return nil

//=================================================================================================================
//=================================================================================================================
