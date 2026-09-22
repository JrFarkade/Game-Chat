const fs = require('fs');
const path = require('path');

function generateWav(filename, durationSeconds, frequencyGen) {
  const sampleRate = 44100;
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
  const blockAlign = numChannels * (bitsPerSample / 8);
  const totalSamples = Math.floor(sampleRate * durationSeconds);
  const dataSize = totalSamples * blockAlign;
  const buffer = Buffer.alloc(44 + dataSize);

  // RIFF header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);

  // 'fmt ' subchunk
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // Subchunk1Size (16 for PCM)
  buffer.writeUInt16LE(1, 20);  // AudioFormat (1 for PCM)
  buffer.writeUInt16LE(numChannels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(byteRate, 28);
  buffer.writeUInt16LE(blockAlign, 32);
  buffer.writeUInt16LE(bitsPerSample, 34);

  // 'data' subchunk
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);

  let offset = 44;
  for (let i = 0; i < totalSamples; i++) {
    const t = i / sampleRate;
    const sample = frequencyGen(t, durationSeconds);
    const clamped = Math.max(-1, Math.min(1, sample));
    const intVal = Math.floor(clamped * 32767);
    buffer.writeInt16LE(intVal, offset);
    offset += 2;
  }

  fs.writeFileSync(filename, buffer);
  console.log(`Generated: ${filename} (${buffer.length} bytes)`);
}

const targets = [
  path.join(__dirname, '..', 'mobile', 'assets', 'sounds'),
  path.join(__dirname, '..', 'sounds')
];

for (const dir of targets) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // 1. FAAAAH: descending pitch dramatic slide
  generateWav(path.join(dir, 'faaaah.wav'), 1.2, (t, dur) => {
    const freq = 600 * Math.exp(-t * 1.5) + 120;
    return Math.sin(2 * Math.PI * freq * t) * (1 - t / dur);
  });

  // 2. BRUH: deep resonant bass drop
  generateWav(path.join(dir, 'bruh.wav'), 0.9, (t, dur) => {
    const freq = 110 - (t / dur) * 35;
    return (Math.sin(2 * Math.PI * freq * t) + 0.3 * Math.sin(2 * Math.PI * (freq * 0.5) * t)) * (1 - t / dur);
  });

  // 3. HONK: dual harmonic trumpet-like honk
  generateWav(path.join(dir, 'honk.wav'), 0.5, (t, dur) => {
    const env = t < 0.05 ? t / 0.05 : 1 - (t - 0.05) / (dur - 0.05);
    return (0.7 * Math.sin(2 * Math.PI * 440 * t) + 0.3 * Math.sin(2 * Math.PI * 880 * t)) * env;
  });

  // 4. LAUGH: staccato laughing chirps
  generateWav(path.join(dir, 'laugh.wav'), 1.0, (t, dur) => {
    const chirp = Math.floor(t * 6);
    const subT = (t * 6) - chirp;
    const freq = 520 + chirp * 30;
    const env = Math.sin(Math.PI * Math.min(1, subT * 1.3));
    return Math.sin(2 * Math.PI * freq * t) * env;
  });

  // 5. AIRHORN: classic reggae airhorn chord pattern
  generateWav(path.join(dir, 'airhorn.wav'), 0.8, (t, dur) => {
    const chord = [466.16, 587.33, 698.46]; // Bb chord
    let sum = 0;
    for (const f of chord) {
      sum += Math.sin(2 * Math.PI * f * t);
    }
    const env = t < 0.03 ? t / 0.03 : 1 - (t - 0.03) / (dur - 0.03);
    return (sum / 3) * env;
  });

  // 6. SKULL (💀): sinister low warble rumble
  generateWav(path.join(dir, 'skull.wav'), 1.1, (t, dur) => {
    const freq = 90 + 20 * Math.sin(2 * Math.PI * 8 * t);
    const env = 1 - t / dur;
    return Math.sin(2 * Math.PI * freq * t) * env;
  });
}
