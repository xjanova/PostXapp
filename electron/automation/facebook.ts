import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class FacebookAutomation extends PlatformAutomation {
  constructor() {
    super('facebook', 'https://www.facebook.com/login', 'https://www.facebook.com')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://www.facebook.com', false)

    try {
      callbacks.onStatus('Opening Facebook...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(2000)

      // Check if logged in
      const isHome = await this.evaluateJs(
        win,
        `document.querySelector('[aria-label="Create a post"]') !== null ||
         document.querySelector('[role="textbox"]') !== null ||
         document.querySelector('[data-pagelet="FeedComposer"]') !== null`
      )

      if (!isHome) {
        win.destroy()
        return { success: false, error: 'Not logged in to Facebook. Please connect your account first.' }
      }

      callbacks.onStatus('Finding post composer...')
      callbacks.onProgress(30)

      // Click on "What's on your mind?" to open composer
      const opened = await this.evaluateJs(win, `
        (function() {
          // Try multiple selectors for the composer trigger
          const selectors = [
            '[aria-label="Create a post"]',
            '[role="textbox"][aria-label*="mind"]',
            '[data-pagelet="FeedComposer"] [role="button"]',
            'div[class*="sjgh65i0"]'
          ];
          for (const sel of selectors) {
            const el = document.querySelector(sel);
            if (el) { el.click(); return true; }
          }
          return false;
        })()
      `)

      if (!opened) {
        win.destroy()
        return { success: false, error: 'Could not find Facebook post composer.' }
      }

      await this.delay(2000)
      callbacks.onStatus('Typing post content...')
      callbacks.onProgress(50)

      // Find the composer textbox and type
      await this.evaluateJs(win, `
        (function() {
          const boxes = document.querySelectorAll('[role="textbox"][contenteditable="true"]');
          const box = boxes[boxes.length - 1];
          if (box) { box.focus(); box.click(); }
        })()
      `)
      await this.delay(500)
      await win.webContents.insertText(payload.text)
      await this.delay(1000)

      callbacks.onStatus('Publishing post...')
      callbacks.onProgress(80)

      // Click Post button
      await this.evaluateJs(win, `
        (function() {
          const buttons = document.querySelectorAll('[aria-label="Post"]');
          const postBtn = buttons[buttons.length - 1] || document.querySelector('div[aria-label="Post"][role="button"]');
          if (postBtn) postBtn.click();
        })()
      `)

      await this.delay(3000)
      callbacks.onStatus('Posted to Facebook!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://www.facebook.com' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `Facebook post failed: ${(err as Error).message}` }
    }
  }
}
