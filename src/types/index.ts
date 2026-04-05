export type PlatformId =
  | 'facebook'
  | 'tiktok'
  | 'twitter'
  | 'instagram'
  | 'linkedin'
  | 'pinterest'
  | 'threads'
  | 'youtube'
  | 'bluesky'
  | 'telegram'

export type ConnectionStatus = 'connected' | 'disconnected' | 'expired'
export type PostStatus = 'idle' | 'posting' | 'success' | 'error'

export interface Platform {
  id: PlatformId
  name: string
  icon: string
  color: string
  loginUrl: string
  supportedTypes: PostType[]
  maxTextLength: number
  maxImages: number
  supportsVideo: boolean
}

export type PostType = 'text' | 'image' | 'video' | 'story' | 'reel'

export interface PlatformAccount {
  platformId: PlatformId
  username: string
  displayName: string
  avatar?: string
  connectionStatus: ConnectionStatus
  lastLogin?: string
  cookies?: Array<{ name: string; value: string; domain: string }>
}

export interface PostContent {
  text: string
  images: string[] // file paths
  video?: string // file path
  type: PostType
}

export interface PostJob {
  id: string
  content: PostContent
  targetPlatforms: PlatformId[]
  status: Record<PlatformId, PostStatus>
  createdAt: string
  scheduledAt?: string
  completedAt?: string
  errors: Record<PlatformId, string>
}

export interface PostHistory {
  id: string
  content: PostContent
  platform: PlatformId
  status: 'success' | 'error'
  postedAt: string
  error?: string
  postUrl?: string
}

export interface AppSettings {
  theme: 'dark' | 'light'
  autoRetry: boolean
  retryCount: number
  postDelay: number // ms between posts to different platforms
  defaultPlatforms: PlatformId[]
  language: 'en' | 'th'
}
