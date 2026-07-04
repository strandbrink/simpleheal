@echo off
echo Deploying SimpleHeal to WoW AddOns folder...
set DEST=C:\wow\World of Warcraft\_anniversary_\Interface\AddOns\SimpleHeal
copy /Y "SimpleHeal.lua" "%DEST%\SimpleHeal.lua"
copy /Y "SimpleHeal.toc" "%DEST%\SimpleHeal.toc"
if not exist "%DEST%\Textures" mkdir "%DEST%\Textures"
copy /Y "Textures\*.tga" "%DEST%\Textures\"
echo Done! Type /reload in WoW.
pause
