import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class YouTubeAutomation extends PlatformAutomation {
  constructor() {
    super('youtube', 'https://accounts.google.com/ServiceLogin', 'https://www.youtube.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    // YouTube community posts
    const win = this.createAutomationWindow('https://www.youtube.com/channel', false)

    try {
      callbacks.onStatus('Opening YouTube...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      const url = win.webContents.getURL()
      if (url.includes('accounts.google.com')) {
        win.destroy()
        return { success: false, error: 'Not logged in to YouTube. Please connect your account first.' }
      }

      callbacks.onStatus('Navigating to community tab...')
      callbacks.onProgress(30)

      // Navigate to community tab
      await this.evaluateJs(win, `
        (function() {
          const communityTab = document.querySelector('a[href*="/community"]') ||
                               Array.from(document.querySelectorAll('a, tp-yt-paper-tab'))
                                 .find(a => a.textContent?.includes('Community'));
          if (communityTab) communityTab.click();
        })()
      `)

      await this.delay(2000)
      callbacks.onStatus('Finding post area...')
      callbacks.onProgress(50)

      // Try to find the community post input
      const hasInput = await this.waitForSelector(
        win,
        '#contenteditable-textarea, [contenteditable="true"]',
        10000
      )

      if (!hasInput) {
        win.destroy()
        return { success: false, error: 'Could not find YouTube community post area. You may not have community posts enabled.' }
      }

      callbacks.onStatus('Typing community post...')
      callbacks.onProgress(70)

      await this.evaluateJs(win, `
        (function() {
          const editor = document.querySelector('#contenteditable-textarea') ||
                         document.querySelector('[contenteditable="true"]');
          if (editor) { editor.focus(); editor.click(); }
        })()
      `)
      await this.delay(500)
      await win.webContents.insertText(payload.text)
      await this.delay(1000)

      callbacks.onStatus('Posting to YouTube...')
      callbacks.onProgress(90)

      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('#submit-button, [aria-label="Post"]') ||
                      Array.from(document.querySelectorAll('button, tp-yt-paper-button'))
                        .find(b => b.textContent?.trim() === 'Post');
          if (btn) btn.click();
        })()
      `)

      await this.delay(3000)
      callbacks.onStatus('Posted to YouTube!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://www.youtube.com' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `YouTube post failed: ${(err as Error).message}` }
    }
  }
}
