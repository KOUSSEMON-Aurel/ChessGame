import math
import struct
import os

def write_wav(filename, duration=0.1, freq=440.0, vol=0.5):
    sample_rate = 44100
    n_samples = int(sample_rate * duration)
    data_size = n_samples * 2
    file_size = 36 + data_size
    
    with open(filename, 'wb') as f:
        # RIFF header
        f.write(b'RIFF')
        f.write(struct.pack('<I', file_size))
        f.write(b'WAVE')
        
        # fmt chunk
        f.write(b'fmt ')
        f.write(struct.pack('<I', 16)) # Chunk size
        f.write(struct.pack('<H', 1))  # PCM
        f.write(struct.pack('<H', 1))  # Channels
        f.write(struct.pack('<I', sample_rate))
        f.write(struct.pack('<I', sample_rate * 2)) # Byte rate
        f.write(struct.pack('<H', 2))  # Block align
        f.write(struct.pack('<H', 16)) # Bits per sample
        
        # data chunk
        f.write(b'data')
        f.write(struct.pack('<I', data_size))
        
        for i in range(n_samples):
            t = float(i) / sample_rate
            decay = 1.0 - (float(i) / n_samples)
            value = int(32767.0 * vol * decay * math.sin(2.0 * math.pi * freq * t))
            f.write(struct.pack('<h', value))

base_dir = r"c:\Users\DEXGUN\Documents\godot-chess\src\assets\audio"
os.makedirs(base_dir, exist_ok=True)

try:
    write_wav(os.path.join(base_dir, "move.wav"), duration=0.1, freq=400.0)
    write_wav(os.path.join(base_dir, "capture.wav"), duration=0.15, freq=200.0)
    write_wav(os.path.join(base_dir, "check.wav"), duration=0.3, freq=800.0)
    write_wav(os.path.join(base_dir, "start.wav"), duration=0.5, freq=600.0)
    write_wav(os.path.join(base_dir, "end.wav"), duration=0.5, freq=300.0)
    print("Audio placeholders generated successfully.")
except Exception as e:
    print(f"Error: {e}")
