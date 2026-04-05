import { PlatformAutomation, PostPayload, PostResult, AutomationCallbacks } from './base'
import { FacebookAutomation } from './facebook'
import { TwitterAutomation } from './twitter'
import { InstagramAutomation } from './instagram'
import { LinkedInAutomation } from './linkedin'
import { TikTokAutomation } from './tiktok'
import { ThreadsAutomation } from './threads'
import { PinterestAutomation } from './pinterest'
import { YouTubeAutomation } from './youtube'
import { BlueskyAutomation } from './bluesky'
import { TelegramAutomation } from './telegram'

export type { PostPayload, PostResult, AutomationCallbacks }

const automations: Record<string, PlatformAutomation> = {
  facebook: new FacebookAutomation(),
  twitter: new TwitterAutomation(),
  instagram: new InstagramAutomation(),
  linkedin: new LinkedInAutomation(),
  tiktok: new TikTokAutomation(),
  threads: new ThreadsAutomation(),
  pinterest: new PinterestAutomation(),
  youtube: new YouTubeAutomation(),
  bluesky: new BlueskyAutomation(),
  telegram: new TelegramAutomation()
}

export function getAutomation(platformId: string): PlatformAutomation | undefined {
  return automations[platformId]
}

export function getAllAutomations(): Record<string, PlatformAutomation> {
  return automations
}

export async function postToMultiplePlatforms(
  platformIds: string[],
  payload: PostPayload,
  delayMs: number,
  onPlatformStatus: (platformId: string, status: string, progress: number) => void,
  onPlatformResult: (platformId: string, result: PostResult) => void
): Promise<Record<string, PostResult>> {
  const results: Record<string, PostResult> = {}

  for (let i = 0; i < platformIds.length; i++) {
    const platformId = platformIds[i]
    const automation = automations[platformId]

    if (!automation) {
      const result: PostResult = { success: false, error: `No automation for ${platformId}` }
      results[platformId] = result
      onPlatformResult(platformId, result)
      continue
    }

    const callbacks: AutomationCallbacks = {
      onStatus: (message) => onPlatformStatus(platformId, message, 0),
      onProgress: (percent) => onPlatformStatus(platformId, '', percent)
    }

    try {
      const result = await automation.post(payload, callbacks)
      results[platformId] = result
      onPlatformResult(platformId, result)
    } catch (err) {
      const result: PostResult = { success: false, error: (err as Error).message }
      results[platformId] = result
      onPlatformResult(platformId, result)
    }

    // Delay between platforms to avoid detection
    if (i < platformIds.length - 1 && delayMs > 0) {
      await new Promise((r) => setTimeout(r, delayMs))
    }
  }

  return results
}
