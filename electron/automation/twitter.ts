import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class TwitterAutomation extends PlatformAutomation {
  constructor() {
    super('twitter', 'https://twitter.com/i/flow/login', 'https://twitter.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://twitter.com/compose/tweet', false)

    try {
      callbacks.onStatus('Opening X (Twitter)...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      // Check if we're on compose page or redirected to login
      const url = win.webContents.getURL()
      if (url.includes('login') || url.includes('flow')) {
        win.destroy()
        return { success: false, error: 'Not logged in to X. Please connect your account first.' }
      }

      callbacks.onStatus('Finding tweet composer...')
      callbacks.onProgress(30)

      // Wait for the composer textbox
      const hasComposer = await this.waitForSelector(
        win,
        '[data-testid="tweetTextarea_0"], [role="textbox"][data-testid]',
        10000
      )

      if (!hasComposer) {
        win.destroy()
        return { success: false, error: 'Could not find tweet composer.' }
      }

      callbacks.onStatus('Typing tweet...')
      callbacks.onProgress(50)

      await this.evaluateJs(win, `
        (function() {
          const box = document.querySelector('[data-testid="tweetTextarea_0"]') ||
                      document.querySelector('[role="textbox"]');
          if (box) { box.focus(); box.click(); }
        })()
      `)
      await this.delay(500)

      // Truncate to 280 chars for Twitter
      const text = payload.text.length > 280 ? payload.text.substring(0, 277) + '...' : payload.text
      await win.webContents.insertText(text)
      await this.delay(1000)

      callbacks.onStatus('Posting tweet...')
      callbacks.onProgress(80)

      // Click the Post/Tweet button
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('[data-testid="tweetButton"], [data-testid="tweetButtonInline"]');
          if (btn) btn.click();
        })()
      `)

      await this.delay(3000)
      callbacks.onStatus('Posted to X!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://twitter.com' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `X post failed: ${(err as Error).message}` }
    }
  }
}
