cd c:\Users\Public\watcher
git pull
taskkill /IM "powershell.exe" /T /F
schtasks /end /tn "bandwithWatcher_6"
schtasks /run /tn "bandwithWatcher_6"