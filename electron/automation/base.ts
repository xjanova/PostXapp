import { BrowserWindow, session } from 'electron'

export interface PostPayload {
  text: string
  imagePaths: string[]
  videoPath?: string
}

export interface PostResult {
  success: boolean
  postUrl?: string
  error?: string
}

export interface AutomationCallbacks {
  onStatus: (message: string) => void
  onProgress: (percent: number) => void
}

export abstract class PlatformAutomation {
  protected platformId: string
  protected loginUrl: string
  protected baseUrl: string

  constructor(platformId: string, loginUrl: string, baseUrl: string) {
    this.platformId = platformId
    this.loginUrl = loginUrl
    this.baseUrl = baseUrl
  }

  async isLoggedIn(): Promise<boolean> {
    const cookies = await session.defaultSession.cookies.get({ url: this.baseUrl })
    return cookies.length > 0
  }

  async getCookies(): Promise<Electron.Cookie[]> {
    return session.defaultSession.cookies.get({ url: this.baseUrl })
  }

  abstract post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult>

  protected createAutomationWindow(url: string, show = false): BrowserWindow {
    const win = new BrowserWindow({
      width: 1280,
      height: 800,
      show,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true
      }
    })
    win.loadURL(url)
    return win
  }

  protected async waitForSelector(
    win: BrowserWindow,
    selector: string,
    timeout = 15000
  ): Promise<boolean> {
    const start = Date.now()
    while (Date.now() - start < timeout) {
      const found = await win.webContents.executeJavaScript(
        `!!document.querySelector('${selector.replace(/'/g, "\\'")}')`
      )
      if (found) return true
      await new Promise((r) => setTimeout(r, 500))
    }
    return false
  }

  protected async waitForNavigation(win: BrowserWindow, timeout = 15000): Promise<void> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Navigation timeout')), timeout)
      win.webContents.once('did-finish-load', () => {
        clearTimeout(timer)
        resolve()
      })
    })
  }

  protected async typeText(
    win: BrowserWindow,
    selector: string,
    text: string
  ): Promise<void> {
    await win.webContents.executeJavaScript(`
      (function() {
        const el = document.querySelector('${selector.replace(/'/g, "\\'")}');
        if (!el) throw new Error('Element not found: ${selector}');
        el.focus();
        el.click();
      })()
    `)
    // Small delay before typing
    await new Promise((r) => setTimeout(r, 300))

    // Use insertText for proper input event handling
    await win.webContents.insertText(text)
  }

  protected async clickElement(win: BrowserWindow, selector: string): Promise<void> {
    await win.webContents.executeJavaScript(`
      (function() {
        const el = document.querySelector('${selector.replace(/'/g, "\\'")}');
        if (!el) throw new Error('Element not found: ${selector}');
        el.click();
      })()
    `)
  }

  protected async evaluateJs(win: BrowserWindow, code: string): Promise<unknown> {
    return win.webContents.executeJavaScript(code)
  }

  protected delay(ms: number): Promise<void> {
    return new Promise((r) => setTimeout(r, ms))
  }
}
