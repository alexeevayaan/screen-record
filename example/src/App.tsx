import { useVideoPlayer, VideoView } from 'expo-video';
import { useEffect, useRef, useState, type ComponentRef } from 'react';
import {
  Animated,
  Easing,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  recordScreen,
  recordView,
  stopRecording,
} from 'react-native-screen-record';

export default function App() {
  const stage = useRef<ComponentRef<typeof View>>(null);
  const spin = useRef(new Animated.Value(0)).current;
  const [ticks, setTicks] = useState(0);
  const [recording, setRecording] = useState(false);
  const [status, setStatus] = useState('Tap a button to record.');
  const [uri, setUri] = useState<string | null>(null);

  // Something that moves, driven by the native thread and by JS.
  useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(spin, {
        toValue: 1,
        duration: 2000,
        easing: Easing.linear,
        useNativeDriver: true,
      })
    );
    loop.start();
    const timer = setInterval(() => setTicks((value) => value + 1), 100);
    return () => {
      loop.stop();
      clearInterval(timer);
    };
  }, [spin]);

  async function run(label: string, record: () => Promise<string>) {
    setRecording(true);
    setStatus(`${label}…`);
    const started = Date.now();
    try {
      const result = await record();
      setUri(result);
      setStatus(
        `${label}: done in ${((Date.now() - started) / 1000).toFixed(1)} s`
      );
    } catch (error) {
      setStatus(`${label} failed: ${String(error)}`);
    } finally {
      setRecording(false);
    }
  }

  const rotate = spin.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>react-native-screen-record</Text>

      <View ref={stage} collapsable={false} style={styles.stage}>
        <Animated.View style={[styles.square, { transform: [{ rotate }] }]} />
        <Text style={styles.counter}>{(ticks / 10).toFixed(1)} s</Text>
      </View>

      <View style={styles.buttons}>
        <Button
          label="Record the view, 3 s"
          disabled={recording}
          onPress={() =>
            run('View', () => recordView(stage, { durationMs: 3000 }))
          }
        />
        <Button
          label="Record the screen, 3 s"
          disabled={recording}
          onPress={() =>
            run('Screen', () => recordScreen({ durationMs: 3000, width: 720 }))
          }
        />
        <Button
          label={recording ? 'Stop' : 'Record the view until stopped'}
          onPress={() =>
            recording
              ? stopRecording()
              : run('Until stopped', () => recordView(stage, { durationMs: 0 }))
          }
        />
      </View>

      <Text style={styles.status}>{status}</Text>
      {uri ? <Player key={uri} uri={uri} /> : null}
    </ScrollView>
  );
}

function Player({ uri }: { uri: string }) {
  const player = useVideoPlayer(uri, (instance) => {
    instance.loop = true;
    instance.muted = true;
    instance.play();
  });
  return (
    <View style={styles.result}>
      <VideoView
        player={player}
        nativeControls={false}
        contentFit="contain"
        style={styles.video}
      />
      <Text style={styles.uri} numberOfLines={2}>
        {uri}
      </Text>
    </View>
  );
}

function Button({
  label,
  disabled,
  onPress,
}: {
  label: string;
  disabled?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        (pressed || disabled) && styles.dimmed,
      ]}
    >
      <Text style={styles.buttonLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    gap: 16,
    paddingTop: 80,
    paddingBottom: 40,
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
  },
  stage: {
    width: 240,
    height: 240,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#5B3DF5',
  },
  square: {
    width: 110,
    height: 110,
    borderRadius: 18,
    backgroundColor: '#FFD23F',
  },
  counter: {
    position: 'absolute',
    bottom: 16,
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: '700',
    fontVariant: ['tabular-nums'],
  },
  buttons: {
    alignSelf: 'stretch',
    gap: 10,
  },
  button: {
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    backgroundColor: '#111111',
  },
  dimmed: {
    opacity: 0.5,
  },
  buttonLabel: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  status: {
    color: '#444444',
    textAlign: 'center',
  },
  result: {
    alignItems: 'center',
    gap: 8,
  },
  video: {
    width: 240,
    height: 240,
    backgroundColor: '#000000',
  },
  uri: {
    color: '#888888',
    fontSize: 11,
  },
});
