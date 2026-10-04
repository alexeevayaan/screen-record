import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Records the view with `viewTag` (or the whole window when it's -1) into an MP4. Resolves to the file's URI once
   * `durationMs` has passed (or `stopRecording()` was called, when `durationMs` is 0) and the file is written.
   */
  startRecording(
    viewTag: number,
    durationMs: number,
    width: number,
    fps: number,
    bitRate: number
  ): Promise<string>;
  /** Ends the recording in progress early; its promise resolves with what was recorded so far. */
  stopRecording(): void;
  isRecording(): boolean;
}

export default TurboModuleRegistry.getEnforcing<Spec>('ScreenRecord');
