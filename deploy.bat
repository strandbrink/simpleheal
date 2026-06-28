@echo off
echo Deploying SimpleHeal to WoW AddOns folder...
copy /Y "SimpleHeal.lua" "C:\wow\World of Warcraft\_anniversary_\Interface\AddOns\SimpleHeal\SimpleHeal.lua"
copy /Y "SimpleHeal.toc" "C:\wow\World of Warcraft\_anniversary_\Interface\AddOns\SimpleHeal\SimpleHeal.toc"
echo Done! Type /reload in WoW.
pause
