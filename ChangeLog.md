# Harbour FastCGI - Change Log

## 01/29/2023
* Enhanced FastCGI interface to handle streaming row file content (including chr(0)).

## 01/23/2023
* GetAppConfig method will not support getting values from environment variables. If the value in config.txt is formatted as ${ENVIRONMENT_VARIABLE_NAME}, when the values are loaded, the named environment variable will be used.

## 01/20/2023
* If a value is used with SendToDebugView function, any carriage return or line feed is converted to the text <br>.

## 01/04/2023
* Removed LocalSandbox Example and created its own Repo  Harbour_LocalSandbox
* Updated devcontainer to use ubuntu:22.04 or DockerHub images
