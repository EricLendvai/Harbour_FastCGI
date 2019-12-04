#include "hb_fcgi.ch"

//=================================================================================================================

Function Main()

local iRequestCount := 0
local iInputLength := 0
local cInput := ""
local cQUERY_STRING := ""
local cVar

SendToDebugView("Starting echo")

oFcgi := hb_Fcgi()

do while (oFcgi:MaxRequestToProcess <= 0 .or. iRequestCount < oFcgi:MaxRequestToProcess) .and. (oFcgi:Wait() >= 0)
    iRequestCount++

    oFcgi:Print("<h1>FastCGI echo 067</h1>")
    
    oFcgi:Print("<p>Request Count = "+Trans( iRequestCount )+"</p>")

    oFcgi:Print("<p>Input Length = "+Trans( oFcgi:GetInputLength() )+"</p>")

    oFcgi:Print("<p>QUERY_STRING = "+oFcgi:GetEnvironment("QUERY_STRING")+"</p>")

    oFcgi:Print("<p>Request Environment:</p>")
    oFcgi:Print(oFcgi:ListEnvironment())

    oFcgi:Print([<p>Input Field "FirstName" = ]+oFcgi:GetInputValue("FirstName")+[</p>])
    oFcgi:Print([<p>Input Field "LastName" = ]+oFcgi:GetInputValue("LastName")+[</p>])
    oFcgi:Print([<p>Input Field "NotExistingValue" = ]+oFcgi:GetInputValue("Bogus")+[</p>])

    oFcgi:Print([<p>Uploaded File Name "File1" = ]+oFcgi:GetInputFileName("File1")+[</p>])
    oFcgi:Print([<p>Uploaded File Content Type "File1" = ]+oFcgi:GetInputFileContentType("File1")+[</p>])

    oFcgi:SaveInputFileContent("File1","d:\281\"+oFcgi:GetInputFileName("File1"))
    oFcgi:SaveInputFileContent("File2","d:\281\"+oFcgi:GetInputFileName("File2"))
    oFcgi:SaveInputFileContent("File3","d:\281\"+oFcgi:GetInputFileName("File3"))
    oFcgi:SaveInputFileContent("File4","d:\281\"+oFcgi:GetInputFileName("File4"))

    // cInput := oFcgi:GetRawInput()
    // oFcgi:Print("<p>INPUT = "+cInput+"</p>")

    //hb_Fcgi_PrintEnvironment()

end

SendToDebugView("Done")

return nil

//=================================================================================================================
//=================================================================================================================
