import { app, shell, BrowserWindow, ipcMain, session } from 'electron'
import { join } from 'path'
import { electronApp, optimizer, is } from '@electron-toolkit/utils'
import { autoUpdater } from 'electron-updater'
import Store from 'electron-store'

const store = new Store()

let mainWindow: BrowserWindow | null = null

// ── Auto Updater ──────────────────────────────────────────────
autoUpdater.autoDownload = true
autoUpdater.autoInstallOnAppQuit = true

function setupAutoUpdater(): void {
  autoUpdater.on('checking-for-update', () => {
    mainWindow?.webContents.send('updater:status', { status: 'checking' })
  })

  autoUpdater.on('update-available', (info) => {
    mainWindow?.webContents.send('updater:status', {
      status: 'available',
      version: info.version
    })
  })

  autoUpdater.on('update-not-available', () => {
    mainWindow?.webContents.send('updater:status', { status: 'up-to-date' })
  })

  autoUpdater.on('download-progress', (progress) => {
    mainWindow?.webContents.send('updater:status', {
      status: 'downloading',
      percent: Math.round(progress.percent)
    })
  })

  autoUpdater.on('update-downloaded', (info) => {
    mainWindow?.webContents.send('updater:status', {
      status: 'downloaded',
      version: info.version
    })
  })

  autoUpdater.on('error', (err) => {
    mainWindow?.webContents.send('updater:status', {
      status: 'error',
      message: err.message
    })
  })
}

// ── Window ────────────────────────────────────────────────────
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

// ── IPC: Window controls ──────────────────────────────────────
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

// ── IPC: Store ────────────────────────────────────────────────
ipcMain.handle('store:get', (_event, key: string) => store.get(key))
ipcMain.handle('store:set', (_event, key: string, value: unknown) => store.set(key, value))
ipcMain.handle('store:delete', (_event, key: string) => store.delete(key))

// ── IPC: Cookies ──────────────────────────────────────────────
ipcMain.handle('cookies:get', async (_event, filter: Electron.CookiesGetFilter) => {
  return session.defaultSession.cookies.get(filter)
})

ipcMain.handle('cookies:set', async (_event, cookie: Electron.CookiesSetDetails) => {
  return session.defaultSession.cookies.set(cookie)
})

ipcMain.handle('cookies:remove', async (_event, url: string, name: string) => {
  return session.defaultSession.cookies.remove(url, name)
})

// ── IPC: Platform login ───────────────────────────────────────
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
      const cookies = await session.defaultSession.cookies.get({ url: platformUrl })
      resolve({
        success: cookies.length > 0,
        cookies: cookies.map((c) => ({ name: c.name, value: c.value, domain: c.domain }))
      })
    })
  })
})

// ── IPC: Updater ──────────────────────────────────────────────
ipcMain.handle('updater:check', () => {
  autoUpdater.checkForUpdates()
})

ipcMain.handle('updater:install', () => {
  autoUpdater.quitAndInstall(false, true)
})

// ── App lifecycle ─────────────────────────────────────────────
app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.xmanstudio.postxapp')

  app.on('browser-window-created', (_, window) => {
    optimizer.watchWindowShortcuts(window)
  })

  createWindow()
  setupAutoUpdater()

  // Check for updates after window is ready (non-dev only)
  if (!is.dev) {
    setTimeout(() => autoUpdater.checkForUpdates(), 3000)
  }

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
