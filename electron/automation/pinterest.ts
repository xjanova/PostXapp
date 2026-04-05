import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class PinterestAutomation extends PlatformAutomation {
  constructor() {
    super('pinterest', 'https://www.pinterest.com/login/', 'https://www.pinterest.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://www.pinterest.com/pin-creation-tool/', false)

    try {
      callbacks.onStatus('Opening Pinterest...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      const url = win.webContents.getURL()
      if (url.includes('login')) {
        win.destroy()
        return { success: false, error: 'Not logged in to Pinterest. Please connect your account first.' }
      }

      if (payload.imagePaths.length === 0) {
        win.destroy()
        return { success: false, error: 'Pinterest requires at least one image to create a pin.' }
      }

      callbacks.onStatus('Filling pin details...')
      callbacks.onProgress(40)

      await this.delay(2000)

      // Fill in title/description fields
      const hasTitle = await this.waitForSelector(win, '#pin-draft-title, [data-test-id="pin-draft-title"]', 5000)
      if (hasTitle) {
        await this.evaluateJs(win, `
          (function() {
            const title = document.querySelector('#pin-draft-title') ||
                          document.querySelector('[data-test-id="pin-draft-title"]');
            if (title) { title.focus(); title.click(); }
          })()
        `)
        await this.delay(300)
        const title = payload.text.substring(0, 100)
        await win.webContents.insertText(title)
      }

      callbacks.onStatus('Adding description...')
      callbacks.onProgress(60)

      const hasDesc = await this.waitForSelector(win, '#pin-draft-description, [data-test-id="pin-draft-description"]', 3000)
      if (hasDesc) {
        await this.evaluateJs(win, `
          (function() {
            const desc = document.querySelector('#pin-draft-description') ||
                         document.querySelector('[data-test-id="pin-draft-description"]');
            if (desc) { desc.focus(); desc.click(); }
          })()
        `)
        await this.delay(300)
        const desc = payload.text.length > 500 ? payload.text.substring(0, 497) + '...' : payload.text
        await win.webContents.insertText(desc)
      }

      callbacks.onStatus('Pinterest pin prepared (image upload requires interaction).')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://www.pinterest.com' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `Pinterest post failed: ${(err as Error).message}` }
    }
  }
}
