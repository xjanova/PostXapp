import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'

export class TelegramAutomation extends PlatformAutomation {
  constructor() {
    super('telegram', 'https://web.telegram.org/', 'https://web.telegram.org')
  }

  async post(payload: PostPayload, callbacks: AutomationCallbacks): Promise<PostResult> {
    const win = this.createAutomationWindow('https://web.telegram.org/k/', false)

    try {
      callbacks.onStatus('Opening Telegram Web...')
      callbacks.onProgress(10)
      await this.waitForNavigation(win)
      await this.delay(3000)

      // Telegram Web K may need QR login — check for chat list
      const hasChats = await this.waitForSelector(
        win,
        '.chatlist-container, .chat-list, #column-center',
        10000
      )

      if (!hasChats) {
        win.destroy()
        return { success: false, error: 'Not logged in to Telegram. Please connect your account first.' }
      }

      callbacks.onStatus('Finding message input...')
      callbacks.onProgress(40)

      // Need a channel/chat selected — find the message input
      const hasInput = await this.waitForSelector(
        win,
        '.input-message-input, [contenteditable="true"].input-field-input',
        5000
      )

      if (!hasInput) {
        win.destroy()
        return { success: false, error: 'Please select a channel or chat in Telegram first.' }
      }

      callbacks.onStatus('Typing message...')
      callbacks.onProgress(60)

      await this.evaluateJs(win, `
        (function() {
          const input = document.querySelector('.input-message-input') ||
                        document.querySelector('[contenteditable="true"].input-field-input');
          if (input) { input.focus(); input.click(); }
        })()
      `)
      await this.delay(500)
      await win.webContents.insertText(payload.text)
      await this.delay(1000)

      callbacks.onStatus('Sending message...')
      callbacks.onProgress(80)

      // Click send button or press Enter
      await this.evaluateJs(win, `
        (function() {
          const btn = document.querySelector('.btn-send, .send-btn, button[class*="send"]');
          if (btn) { btn.click(); return; }
          // Fallback: dispatch Enter key
          const input = document.querySelector('.input-message-input');
          if (input) {
            input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', bubbles: true }));
          }
        })()
      `)

      await this.delay(2000)
      callbacks.onStatus('Sent to Telegram!')
      callbacks.onProgress(100)

      win.destroy()
      return { success: true, postUrl: 'https://web.telegram.org' }
    } catch (err) {
      win.destroy()
      return { success: false, error: `Telegram post failed: ${(err as Error).message}` }
    }
  }
}
