import { beforeEach, describe, expect, it, jest } from '@jest/globals';
import { findNodeHandle } from 'react-native';

import NativeScreenRecord from '../NativeScreenRecord';
import { isRecording, recordScreen, recordView, stopRecording } from '../index';

jest.mock('react-native', () => ({
  findNodeHandle: jest.fn(),
}));

jest.mock('../NativeScreenRecord', () => ({
  __esModule: true,
  default: {
    startRecording: jest.fn(),
    stopRecording: jest.fn(),
    isRecording: jest.fn(),
  },
}));

const native = jest.mocked(NativeScreenRecord);
const findTag = jest.mocked(findNodeHandle);

const DEFAULTS = [5000, 1080, 30, 10_000_000];
const VIDEO = 'file:///cache/screen-record-1.mp4';

beforeEach(() => {
  jest.clearAllMocks();
  native.startRecording.mockResolvedValue(VIDEO);
  native.isRecording.mockReturnValue(false);
});

describe('recordView', () => {
  it('records the view of a ref', async () => {
    const view = { name: 'view' };
    findTag.mockReturnValue(42);

    await expect(
      recordView({ current: view as unknown as number })
    ).resolves.toBe(VIDEO);

    expect(findTag).toHaveBeenCalledWith(view);
    expect(native.startRecording).toHaveBeenCalledWith(42, ...DEFAULTS);
  });

  it('records a view by its tag', async () => {
    await recordView(7);

    expect(findTag).not.toHaveBeenCalled();
    expect(native.startRecording).toHaveBeenCalledWith(7, ...DEFAULTS);
  });

  it('takes 0 as a tag', async () => {
    await recordView(0);

    expect(native.startRecording).toHaveBeenCalledWith(0, ...DEFAULTS);
  });

  it('rejects without recording when the ref is empty', async () => {
    findTag.mockReturnValue(undefined);

    await expect(recordView({ current: null })).rejects.toThrow(
      'the view to record is not mounted'
    );
    expect(native.startRecording).not.toHaveBeenCalled();
  });

  it('passes every option it is given', async () => {
    await recordView(7, {
      durationMs: 0,
      width: 720,
      fps: 60,
      bitRate: 4_000_000,
    });

    expect(native.startRecording).toHaveBeenCalledWith(
      7,
      0,
      720,
      60,
      4_000_000
    );
  });

  it('uses the defaults for options it is not given', async () => {
    await recordView(7, { width: 720 });

    expect(native.startRecording).toHaveBeenCalledWith(
      7,
      5000,
      720,
      30,
      10_000_000
    );
  });

  it('uses the defaults for options set to undefined', async () => {
    await recordView(7, { durationMs: undefined, fps: undefined });

    expect(native.startRecording).toHaveBeenCalledWith(7, ...DEFAULTS);
  });

  it('passes on the native error', async () => {
    const busy = Object.assign(
      new Error('A recording is already in progress'),
      { code: 'E_BUSY' }
    );
    native.startRecording.mockRejectedValue(busy);

    await expect(recordView(7)).rejects.toBe(busy);
  });
});

describe('recordScreen', () => {
  it('records the window', async () => {
    await expect(recordScreen()).resolves.toBe(VIDEO);

    expect(native.startRecording).toHaveBeenCalledWith(-1, ...DEFAULTS);
  });

  it('passes its options', async () => {
    await recordScreen({ durationMs: 1000, width: 720 });

    expect(native.startRecording).toHaveBeenCalledWith(
      -1,
      1000,
      720,
      30,
      10_000_000
    );
  });
});

describe('stopRecording', () => {
  it('stops the recording in progress', () => {
    stopRecording();

    expect(native.stopRecording).toHaveBeenCalledTimes(1);
  });
});

describe('isRecording', () => {
  it('reports whether a recording is in progress', () => {
    expect(isRecording()).toBe(false);

    native.isRecording.mockReturnValue(true);
    expect(isRecording()).toBe(true);
  });
});
