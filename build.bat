@if not "%VS150COMNTOOLS%"=="" goto build
call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat" x64

:build

del *.obj
del *.ilk

@set LJCOMPILE=cl /nologo /c /O2 /W3 /DLUAASIO_EXPORTS /D_WINDOWS /D_USRDLL /MD /EHsc
@set LJLINK=link /nologo

%LJCOMPILE% /Zi  /I ".\include" /I \ *.cpp
%LJLINK% /DLL /DEBUG /out:asio.dll *.obj

del *.obj
del *.ilk
del asio.exp
del asio.lib
del vc140.pdb

