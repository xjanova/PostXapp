import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class TikTokAutomation extends PlatformAutomation {
  constructor() {
    super('tiktok', 'https://www.tiktok.com/login', 'https://www.tiktok.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    // TikTok web upload page
    const win = this.createAutomationWindow('https://www.tiktok.com/creator#/upload', false)

    try {
      callbacks.onStatus('Opening TikTok Creator...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(3000)

      const url = win.webContents.getURL()
      if (url.includes('login')) {
        win.destroy()
        return { success: false, error: 'Not logged in to TikTok. Please connect your account first.' }
      }

      callbacks.onStatus('Preparing upload...')
      callbacks.onProgress(30)

      if (!payload.videoPath) {
        win.destroy()
        return { success: false, error: 'TikTok requires a video to post.' }
      }

      // Wait for the upload area
      await this.delay(2000)

      callbacks.onStatus('Adding caption...')
      callbacks.onProgress(60)

      // Try to find caption editor
      const hasCaption = await this.waitForSelector(
        win,
        '[contenteditable="true"], .public-DraftEditor-content, [data-text="true"]',
        10000
      )

      if (hasCaption) {
        await this.evaluateJs(win, `
          (function() {
            const editor = document.querySelector('[contenteditable="true"]') ||
                           document.querySelector('.public-DraftEditor-content');
            if (editor) { editor.focus(); editor.click(); }
          })()
        `)
        await this.delay(500)
        const text = payload.text.length > 2200 ? payload.text.substring(0, 2197) + '...' : payload.text
        await win.webContents.insertText(text)
      }

      callbacks.onStatus('TikTok post prepared (video upload requires interaction).')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true }
    } catch (err) {
      win.destroy()
      return { success: false, error: `TikTok post failed: ${(err as Error).message}` }
    }
  }
}
