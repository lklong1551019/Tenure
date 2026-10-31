import { useSyncExternalStore } from 'react'
import type { AppModel, AppState } from './appModel'

/** The app state, re-rendering on every change. */
export const useAppState = (model: AppModel): AppState =>
  useSyncExternalStore(model.subscribe, model.getState)
