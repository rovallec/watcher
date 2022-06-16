cd c:\Users\Public\watcher
git pull
taskkill /IM "powershell.exe" /T /F
schtasks /run /tn "bandwithWatcher_6"