const {app,BrowserWindow,Tray,Menu,nativeImage,clipboard,dialog,shell}=require('electron');
const {spawn}=require('node:child_process');
const path=require('node:path');
const readline=require('node:readline');
const {isTrustedExternal}=require('./external-links.cjs');
const branding=require('./branding.cjs');
const {resolveDataDir}=require('./data-dir.cjs');
function openWindow({url}){try{if(ready&&new URL(url).origin===ready.url)return {action:'allow',overrideBrowserWindowOptions:{webPreferences:{nodeIntegration:false,contextIsolation:true,sandbox:true}}};if(isTrustedExternal(url))void shell.openExternal(url).catch(()=>{dialog.showErrorBox("无法打开浏览器", "请复制链接到系统浏览器中打开。")})}catch{}return {action:'deny'}}
let win,tray,child,ready,quitting=false,exitTimer;
const lock=app.requestSingleInstanceLock();
if(!lock) app.quit();
app.on('second-instance',()=>{if(win){win.show();win.focus()}});
app.on('window-all-closed',()=>{});
function show(){if(win){win.show();win.focus()}}
function stop(){
 if(!child||exitTimer)return;
 const stopping=child;
 // Give the server time to flush data, then terminate it if shutdown stalls.
 exitTimer=setTimeout(()=>{if(child===stopping)stopping.kill('SIGKILL')},11000);
 stopping.stdin.end();
}
app.on('before-quit',e=>{quitting=true;if(child){e.preventDefault();stop()} });
app.on('will-quit',()=>{clearTimeout(exitTimer);if(tray)tray.destroy()});
app.on('activate',show);
// Apply the same boundary to print popups and any later child window.
app.on('web-contents-created',(_event,contents)=>{
 const allowed=url=>{try{return ready&&new URL(url).origin===ready.url}catch{return false}};
 contents.on('will-navigate',(event,url)=>{if(!allowed(url))event.preventDefault()});
 contents.setWindowOpenHandler(openWindow);
});
async function boot(){
 if(quitting)return;
 let dir;
 try{dir=resolveDataDir({appDataDir:app.getPath('appData')})}catch(err){dialog.showErrorBox('无法确定数据目录',err.message);quitting=true;app.quit();return}
 const exe=path.join(app.isPackaged?path.join(process.resourcesPath,'backend'):path.join(__dirname,'resources'),branding.serverBinaryName(process.platform));
 child=spawn(exe,['--data-dir',dir,'--parent-stdio'],{stdio:['pipe','pipe','pipe'],windowsHide:true});
 // A server that already exited may close its input before our EOF reaches it.
 child.stdin.on('error',()=>{});
 let lastError='';child.stderr.on('data',b=>{lastError=(lastError+b.toString()).slice(-2000)});
 let booted=false;
 const timeout=setTimeout(()=>{if(!booted){dialog.showErrorBox('Questrace 启动超时','请检查数据目录权限及 questrace.log');quitting=true;stop()}},30000);
 child.on('error',err=>{clearTimeout(timeout);child=null;dialog.showErrorBox('无法启动 Questrace',err.message);app.quit()});
 child.on('exit',()=>{clearTimeout(timeout);clearTimeout(exitTimer);child=null;if(!quitting)dialog.showErrorBox('Questrace 服务已停止',lastError||'请重新启动程序，数据仍保存在本机。');quitting=true;app.quit()});
 const lines=readline.createInterface({input:child.stdout});
 lines.on('line',async line=>{let data;try{data=JSON.parse(line)}catch{return};if(data.event!=='ready'||booted||quitting)return;booted=true;clearTimeout(timeout);ready=data;
 try{const response=await fetch(data.url+'/healthz');if(!response.ok)throw Error('健康检查失败');
 if(quitting)return;
 win=new BrowserWindow({width:1280,height:850,minWidth:900,minHeight:640,title:branding.windowTitle,webPreferences:{nodeIntegration:false,contextIsolation:true,sandbox:true}});
 win.webContents.setWindowOpenHandler(openWindow);
 win.webContents.on('will-navigate',(event,url)=>{if(new URL(url).origin!==data.url)event.preventDefault()});
 win.on('close',e=>{if(!quitting){e.preventDefault();if(process.platform==='win32')app.quit();else win.hide()}});
 // Embedded PNG avoids runtime asset dependencies for the tray icon.
 const icon=nativeImage.createFromDataURL('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAASklEQVR4nO3SwQkAIAzF0O7iQg7R/VfQq1cRGqQJ9P7gN8KORs5VcQIECLgCvPY/AJ9AAA7AnxAH4BMIwAH4E+IAfAIBAnoBWrYBv+oHK1KNPpQAAAAASUVORK5CYII=');
 tray=new Tray(icon);tray.setToolTip(branding.trayTooltip);tray.setContextMenu(Menu.buildFromTemplate([{label:branding.trayOpenLabel,click:show},...data.urls.map(url=>({label:'复制 '+url,click:()=>clipboard.writeText(url)})),{type:'separator'},{label:'退出并停止服务',click:()=>app.quit()}]));tray.on('click',show);
 await win.loadURL(data.url+(data.setup_token?'/setup#token='+encodeURIComponent(data.setup_token):'/'));
 }catch(err){dialog.showErrorBox('Questrace 启动失败',err.message);quitting=true;stop()}
 });
}
if(lock)app.whenReady().then(boot);
