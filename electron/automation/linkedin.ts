import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class LinkedInAutomation extends PlatformAutomation {
  constructor() {
    super('linkedin', 'https://www.linkedin.com/login', 'https://www.linkedin.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://www.linkedin.com/feed/', false)

    try {
      callbacks.onStatus('Opening LinkedIn...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      const url = win.webContents.getURL()
      if (url.includes('login') || url.includes('authwall')) {
        win.destroy()
        return { success: false, error: 'Not logged in to LinkedIn. Please connect your account first.' }
      }

      callbacks.onStatus('Opening post composer...')
      callbacks.onProgress(30)

      // Click "Start a post" button
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('.share-box-feed-entry__trigger') ||
                      document.querySelector('button[aria-label*="Start a post"]') ||
                      document.querySelector('.artdeco-card button.artdeco-button');
          if (btn) btn.click();
        })()
      `)

      await this.delay(2000)
      callbacks.onStatus('Typing post content...')
      callbacks.onProgress(50)

      // Find the editor and type
      const hasEditor = await this.waitForSelector(
        win,
        '.ql-editor, [role="textbox"][contenteditable="true"], [data-placeholder*="want to talk about"]',
        10000
      )

      if (!hasEditor) {
        win.destroy()
        return { success: false, error: 'Could not find LinkedIn post editor.' }
      }

      await this.evaluateJs(win, `
        (function() {
          const editor = document.querySelector('.ql-editor') ||
                         document.querySelector('[role="textbox"][contenteditable="true"]');
          if (editor) { editor.focus(); editor.click(); }
        })()
      `)
      await this.delay(500)
      await win.webContents.insertText(payload.text)
      await this.delay(1000)

      callbacks.onStatus('Publishing to LinkedIn...')
      callbacks.onProgress(80)

      // Click Post button
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('button.share-actions__primary-action') ||
                      document.querySelector('[data-control-name="share.post"]') ||
                      Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === 'Post');
          if (btn) btn.click();
        })()
      `)

      await this.delay(3000)
      callbacks.onStatus('Posted to LinkedIn!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://www.linkedin.com/feed/' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `LinkedIn post failed: ${(err as Error).message}` }
    }
  }
}
