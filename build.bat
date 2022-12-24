@if not "%VS150COMNTOOLS%"=="" goto build
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" 

:build

del *.obj
del *.ilk

@set LJCOMPILE=cl /nologo /c /O2 /W3 /DLUAASIO_EXPORTS /D_CONSOLE /D_UNICODE /DUNICODE /D_WINDOWS /D_USRDLL /D_AMD64_ /D_WIN32_WINNT=0x0A00 /MD /EHsc
@set LJLINK=link /nologo /OPT:REF /OPT:ICF
dd
%LJCOMPILE% /Zi /I ".\asio-1.24.0" /I "F:\Dependencies\boost_1_81_0" *.cpp
%LJLINK% /DLL /DEBUG /out:asio.dll *.obj

del *.obj
del *.ilk
del asio.exp
del asio.lib
del vc140.pdb

