echo
echo Zato Windows installation
ver

rem
rem The embedded Python version
rem
set python_version=3.10.8

rem
rem Local aliases
rem
set curdir=%~dp0
set python_bin_dir=%curdir%\windows-python-embedded-%python_version%
set python_cmd=%python_bin_dir%\python.exe

rem
rem Ensure that git considers our directory as safe
rem
git config --add safe.directory curdir\..

rem
rem Install prerequisites
rem
cd python_bin_dir
rem %python_cmd% %python_bin_dir%\get-pip.py

rem
rem Actually install all Python dependencies
rem
rem echo Setting up environment in %curdir%
start "Zato install" call %curdir%\_windows-run-install.bat
