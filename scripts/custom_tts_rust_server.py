# /// script
# requires-python = "==3.12"
# dependencies = [
#     "msgpack",
#     "numpy",
#     "sphn",
#     "websockets",
#     "sounddevice",
#     "tqdm",
# ]
# ///

import time
PROGRAM_START_TIME = time.time()

import argparse
import asyncio
import sys
from urllib.parse import urlencode

import msgpack
import numpy as np
import sounddevice as sd
import sphn
import tqdm
import websockets


SAMPLE_RATE = 24000
# Note that higher than 1.8 will glitch out because it can't
# render fast enough. Render speed also depends on the voice.
VOICE_SPEED = 1.8

TTS_TEXT = "Hello, this is a test of the moshi text to speech system, this should result in some nicely sounding generated voice."
DEFAULT_DSM_TTS_VOICE_REPO = "kyutai/tts-voices"
AUTH_TOKEN = "public_token"


def get_program_time():
  return time.time() - PROGRAM_START_TIME


print("Setup Complete", get_program_time())


async def receive_messages(websocket: websockets.ClientConnection, output_queue):
    with tqdm.tqdm(desc="Receiving audio", unit=" seconds generated") as pbar:
        accumulated_samples = 0
        last_seconds = 0

        async for message_bytes in websocket:
            msg = msgpack.unpackb(message_bytes)

            if msg["type"] == "Audio":
                pcm = np.array(msg["pcm"]).astype(np.float32)
                await output_queue.put(pcm)

                accumulated_samples += len(msg["pcm"])
                current_seconds = accumulated_samples // SAMPLE_RATE
                if current_seconds > last_seconds:
                    pbar.update(current_seconds - last_seconds)
                    last_seconds = current_seconds

    print("End of audio.", get_program_time())
    await output_queue.put(None)  # Signal end of audio


async def output_audio(out: str, output_queue: asyncio.Queue[np.ndarray | None]):
    if out == "-":
        # Use ffplay with tempo filter for 2x speed playback
        import subprocess

        ffplay_cmd = [
          "mpv",
          "--no-video",
          "--demuxer=rawaudio",
          "--demuxer-rawaudio-rate=24000", 
          "--demuxer-rawaudio-channels=1",
          "--demuxer-rawaudio-format=floatle",
          f"--speed={VOICE_SPEED}",
          "--input-media-keys=yes",
          "-"
        ]
       
        process = subprocess.Popen(
            ffplay_cmd,
            stdin=subprocess.PIPE,
        )
        
        try:
            while True:
                item = await output_queue.get()
                if item is None:
                    break
                
                # Convert to bytes and write to ffplay stdin
                audio_bytes = item.astype(np.float32).tobytes()
                process.stdin.write(audio_bytes)
                process.stdin.flush()
        except BrokenPipeError:
            pass  # ffplay might have exited early
        finally:
            process.stdin.close()
            process.wait()
    else:
        frames = []
        while True:
            item = await output_queue.get()
            if item is None:
                break
            frames.append(item)

        sphn.write_wav(out, np.concat(frames, -1), SAMPLE_RATE)
        print(f"Saved audio to {out}")

        
async def iter_text(source: str):
    """Yield text chunks from file or stdin."""
    if source == "-":              # stdin
        while True:
            line = await asyncio.to_thread(sys.stdin.readline)
            if not line:
                break
            yield line.rstrip("\n")
    else:                          # regular file
        with open(source, "r") as f:
            if CHUNK_SIZE:
                while chunk := f.read(CHUNK_SIZE):
                    yield chunk
            else:                  # line-by-line mode
                for line in f:
                    yield line.rstrip("\n")

                    
async def send_text_stream(websocket, source):
    async for chunk in iter_text(source):
        await websocket.send(msgpack.packb({"type": "Text", "text": chunk}))
    await websocket.send(msgpack.packb({"type": "Eos"}))

    
async def websocket_client():
    p = argparse.ArgumentParser("Use the TTS streaming API")
    p.add_argument("inp", help="Input file, - for stdin")
    p.add_argument("out", help="Output file, - to play audio")
    p.add_argument("--voice",
                   default="expresso/ex03-ex01_happy_001_channel1_334s.wav")
    p.add_argument("--url", default="ws://127.0.0.1:8080")
    p.add_argument("--api-key", default="public_token")
    args = p.parse_args()

    params = urlencode({"voice": args.voice, "format": "PcmMessagePack"})
    uri = f"{args.url}/api/tts_streaming?{params}"
    headers = {"kyutai-api-key": args.api_key}

    async with websockets.connect(uri, additional_headers=headers) as ws:
        # start all tasks concurrently
        tx = asyncio.create_task(send_text_stream(ws, args.inp))
        rx = asyncio.create_task(receive_messages(ws, output_queue := asyncio.Queue()))
        out = asyncio.create_task(output_audio(args.out, output_queue))
        await asyncio.gather(tx, rx, out)


if __name__ == "__main__":
    asyncio.run(websocket_client())
    print("Shutdown", get_program_time())
