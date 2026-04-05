import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class ThreadsAutomation extends PlatformAutomation {
  constructor() {
    super('threads', 'https://www.threads.net/login', 'https://www.threads.net')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://www.threads.net/', false)

    try {
      callbacks.onStatus('Opening Threads...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      const url = win.webContents.getURL()
      if (url.includes('login')) {
        win.destroy()
        return { success: false, error: 'Not logged in to Threads. Please connect your account first.' }
      }

      callbacks.onStatus('Opening new thread...')
      callbacks.onProgress(30)

      // Click the compose/new thread button
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('[aria-label="Create"]') ||
                      document.querySelector('a[href="/create"]') ||
                      Array.from(document.querySelectorAll('svg')).find(s =>
                        s.getAttribute('aria-label')?.toLowerCase().includes('create') ||
                        s.getAttribute('aria-label')?.toLowerCase().includes('new')
                      )?.closest('[role="button"], a, button');
          if (btn) btn.click();
        })()
      `)

      await this.delay(2000)
      callbacks.onStatus('Typing thread content...')
      callbacks.onProgress(50)

      const hasEditor = await this.waitForSelector(
        win,
        '[contenteditable="true"], [role="textbox"]',
        10000
      )

      if (!hasEditor) {
        win.destroy()
        return { success: false, error: 'Could not find Threads composer.' }
      }

      await this.evaluateJs(win, `
        (function() {
          const editor = document.querySelector('[contenteditable="true"]') ||
                         document.querySelector('[role="textbox"]');
          if (editor) { editor.focus(); editor.click(); }
        })()
      `)
      await this.delay(500)

      const text = payload.text.length > 500 ? payload.text.substring(0, 497) + '...' : payload.text
      await win.webContents.insertText(text)
      await this.delay(1000)

      callbacks.onStatus('Posting thread...')
      callbacks.onProgress(80)

      await this.evaluateJs(win, `
        (function() {
          const btn = Array.from(document.querySelectorAll('div[role="button"], button'))
            .find(b => b.textContent.trim() === 'Post');
          if (btn) btn.click();
        })()
      `)

      await this.delay(3000)
      callbacks.onStatus('Posted to Threads!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://www.threads.net' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `Threads post failed: ${(err as Error).message}` }
    }
  }
}
