# Harbour FastCGI - Change Log

## 06/23/2024 v 1.10
* Made all the cookies "SameSite=Strict".

## 03/25/2024 v 1.9
* Support for Root Arrays in "application/json" input.

## 02/19/2024 v 1.8
* Code refactored to refer to Harbour_EL routines instead of Harbour_VFP

## 01/07/2024 v 1.7
* Due to a bug in Apache (non MS Windows), which would call the FastCGI exe for missing resource files, like favicon.ico, or any files with an extension, the new engine will skip any pages with an extension. DO NOT use extensions in page names, those are reserved for resource files, like .ico, .css, .js, .txt, .html, ...
* Please update any main loop by testing the new property SkipRequest as follow:
```
do while oFcgi:Wait()
    if !oFcgi:SkipRequest
        oFcgi:OnRequest()
    endif
enddo
```
Please not the RequestCount property will not be incremented for missing resource files requests.

## 11/05/2023 v 1.6
* Support to "Content Type" of "application/json".
* Code refactoring to align coding standards to other Repos in Eric Lendvai Git account.

## 09/09/2023 v 1.5
* Minor tweak in redirect method.

## 04/08/2023 v 1.4
* Changed Dockerfile of devcontainer to work around git install failure introduced around April 2023.

## 02/17/2023 v 1.4
* Fix on "scan" command. Mismatch in definition with hb_vfp.ch was detected.

## 02/11/2023 v 1.3
* When loading web site configuration, will prioritize the use of file "config_deployment.txt" instead of "config.txt". This allows for not placing in git repo the file "config_deployment.txt".

## 02/08/2023 v 1.2
* Method to avoid conflicts between config values and commends; to ensure the "//" comment marker is not part of a config value, it must be preceded with at least one blank.

## 01/29/2023
* Enhanced FastCGI interface to handle streaming row file content (including chr(0)).

## 01/23/2023
* GetAppConfig method will not support getting values from environment variables. If the value in config.txt is formatted as ${ENVIRONMENT_VARIABLE_NAME}, when the values are loaded, the named environment variable will be used.

## 01/20/2023
* If a value is used with SendToDebugView function, any carriage return or line feed is converted to the text <br>.

## 01/04/2023
* Removed LocalSandbox Example and created its own Repo  Harbour_LocalSandbox
* Updated devcontainer to use ubuntu:22.04 or DockerHub images
