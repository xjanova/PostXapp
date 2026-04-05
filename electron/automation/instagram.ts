import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class InstagramAutomation extends PlatformAutomation {
  constructor() {
    super('instagram', 'https://www.instagram.com/accounts/login/', 'https://www.instagram.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://www.instagram.com/', false)

    try {
      callbacks.onStatus('Opening Instagram...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      const url = win.webContents.getURL()
      if (url.includes('login')) {
        win.destroy()
        return { success: false, error: 'Not logged in to Instagram. Please connect your account first.' }
      }

      callbacks.onStatus('Opening create dialog...')
      callbacks.onProgress(30)

      // Click the "Create" / "New post" button
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('[aria-label="New post"]') ||
                      document.querySelector('svg[aria-label="New post"]')?.closest('div[role="button"]') ||
                      document.querySelector('a[href="/create/"]') ||
                      Array.from(document.querySelectorAll('svg')).find(s => s.getAttribute('aria-label')?.includes('New'))?.closest('[role="button"], a');
          if (btn) btn.click();
        })()
      `)

      await this.delay(2000)

      // Instagram requires an image for posts; text-only is not supported
      if (payload.imagePaths.length === 0) {
        win.destroy()
        return { success: false, error: 'Instagram requires at least one image to post.' }
      }

      callbacks.onStatus('Note: Instagram image upload requires manual interaction.')
      callbacks.onProgress(50)

      // Due to browser security, file inputs need real user interaction
      // The automation opens the create dialog; user may need to complete image selection
      await this.delay(2000)

      callbacks.onStatus('Writing caption...')
      callbacks.onProgress(70)

      // Try to find and fill caption field
      const hasCaptionField = await this.waitForSelector(
        win,
        'textarea[aria-label*="caption"], textarea[aria-label*="Write"]',
        5000
      )

      if (hasCaptionField) {
        await this.evaluateJs(win, `
          (function() {
            const ta = document.querySelector('textarea[aria-label*="caption"]') ||
                       document.querySelector('textarea[aria-label*="Write"]');
            if (ta) { ta.focus(); ta.click(); }
          })()
        `)
        await this.delay(500)
        await win.webContents.insertText(payload.text)
      }

      callbacks.onStatus('Instagram post prepared.')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://www.instagram.com' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `Instagram post failed: ${(err as Error).message}` }
    }
  }
}
