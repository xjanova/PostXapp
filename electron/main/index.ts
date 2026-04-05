import { app, shell, BrowserWindow, ipcMain, session } from 'electron'
import { join } from 'path'
import { electronApp, optimizer, is } from '@electron-toolkit/utils'
import Store from 'electron-store'

const store = new Store()

let mainWindow: BrowserWindow | null = null

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1100,
    minHeight: 700,
    show: false,
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: '#070b14',
    icon: join(__dirname, '../../build/icon.png'),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false,
      contextIsolation: true,
      nodeIntegration: false
    }
  })

  mainWindow.on('ready-to-show', () => {
    mainWindow?.show()
  })

  mainWindow.webContents.setWindowOpenHandler((details) => {
    shell.openExternal(details.url)
    return { action: 'deny' }
  })

  if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
    mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

// Window controls
ipcMain.on('window:minimize', () => mainWindow?.minimize())
ipcMain.on('window:maximize', () => {
  if (mainWindow?.isMaximized()) {
    mainWindow.unmaximize()
  } else {
    mainWindow?.maximize()
  }
})
ipcMain.on('window:close', () => mainWindow?.close())
ipcMain.handle('window:isMaximized', () => mainWindow?.isMaximized())

// Store operations
ipcMain.handle('store:get', (_event, key: string) => store.get(key))
ipcMain.handle('store:set', (_event, key: string, value: unknown) => store.set(key, value))
ipcMain.handle('store:delete', (_event, key: string) => store.delete(key))

// Cookie management for platform authentication
ipcMain.handle('cookies:get', async (_event, filter: Electron.CookiesGetFilter) => {
  return session.defaultSession.cookies.get(filter)
})

ipcMain.handle('cookies:set', async (_event, cookie: Electron.CookiesSetDetails) => {
  return session.defaultSession.cookies.set(cookie)
})

ipcMain.handle('cookies:remove', async (_event, url: string, name: string) => {
  return session.defaultSession.cookies.remove(url, name)
})

// Platform login window
ipcMain.handle('platform:login', async (_event, platformUrl: string, platformId: string) => {
  return new Promise((resolve) => {
    const loginWindow = new BrowserWindow({
      width: 800,
      height: 700,
      parent: mainWindow!,
      modal: true,
      title: `Login - ${platformId}`,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true
      }
    })

    loginWindow.loadURL(platformUrl)

    loginWindow.on('closed', async () => {
      // Get cookies after login window closes
      const cookies = await session.defaultSession.cookies.get({ url: platformUrl })
      resolve({
        success: cookies.length > 0,
        cookies: cookies.map((c) => ({ name: c.name, value: c.value, domain: c.domain }))
      })
    })
  })
})

app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.xmanstudio.postxapp')

  app.on('browser-window-created', (_, window) => {
    optimizer.watchWindowShortcuts(window)
  })

  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
