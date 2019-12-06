@echo off
if %DebugMode%. == on.  echo Marker>%DynamicHRBFolder%Mod_Harbour_Debugger.txt
if %DebugMode%. == off. del %DynamicHRBFolder%Mod_Harbour_Debugger.txt