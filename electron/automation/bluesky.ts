import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class BlueskyAutomation extends PlatformAutomation {
  constructor() {
    super('bluesky', 'https://bsky.app/login', 'https://bsky.app')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://bsky.app/', false)

    try {
      callbacks.onStatus('Opening Bluesky...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      const url = win.webContents.getURL()
      if (url.includes('login')) {
        win.destroy()
        return { success: false, error: 'Not logged in to Bluesky. Please connect your account first.' }
      }

      callbacks.onStatus('Opening compose dialog...')
      callbacks.onProgress(30)

      // Click the compose button
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('[aria-label="New post"]') ||
                      document.querySelector('button[aria-label*="compose"]') ||
                      document.querySelector('[data-testid="composePromptButton"]');
          if (btn) btn.click();
        })()
      `)

      await this.delay(2000)
      callbacks.onStatus('Typing post...')
      callbacks.onProgress(50)

      const hasEditor = await this.waitForSelector(
        win,
        '[data-testid="composePostView"] [role="textbox"], .ProseMirror, [contenteditable="true"]',
        10000
      )

      if (!hasEditor) {
        win.destroy()
        return { success: false, error: 'Could not find Bluesky composer.' }
      }

      await this.evaluateJs(win, `
        (function() {
          const editor = document.querySelector('[data-testid="composePostView"] [role="textbox"]') ||
                         document.querySelector('.ProseMirror') ||
                         document.querySelector('[contenteditable="true"]');
          if (editor) { editor.focus(); editor.click(); }
        })()
      `)
      await this.delay(500)

      const text = payload.text.length > 300 ? payload.text.substring(0, 297) + '...' : payload.text
      await win.webContents.insertText(text)
      await this.delay(1000)

      callbacks.onStatus('Publishing post...')
      callbacks.onProgress(80)

      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('[data-testid="composerPublishBtn"]') ||
                      Array.from(document.querySelectorAll('button'))
                        .find(b => b.textContent?.trim() === 'Post');
          if (btn) btn.click();
        })()
      `)

      await this.delay(3000)
      callbacks.onStatus('Posted to Bluesky!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://bsky.app' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `Bluesky post failed: ${(err as Error).message}` }
    }
  }
}
