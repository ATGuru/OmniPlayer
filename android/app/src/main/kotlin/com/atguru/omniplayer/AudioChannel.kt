package com.atguru.omniplayer

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Decodes any Android-supported audio file to a 16 kHz mono 16-bit PCM WAV
 * using MediaExtractor + MediaCodec — no external libraries needed.
 */
object AudioChannel {
    const val CHANNEL = "com.atguru.omniplayer/audio"
    private const val TARGET_SR = 16_000

    /** Blocking; call from a background thread. */
    fun decodeToWav(inputPath: String, outputPath: String) {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // Locate the first audio track
        var trackIdx = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                trackIdx = i; format = f; break
            }
        }
        if (trackIdx < 0 || format == null) {
            extractor.release()
            throw IllegalArgumentException("No audio track found in: $inputPath")
        }

        extractor.selectTrack(trackIdx)
        val inputSR    = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels   = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val mime       = format.getString(MediaFormat.KEY_MIME)!!

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val raw        = ByteArrayOutputStream()
        val info       = MediaCodec.BufferInfo()
        var inputDone  = false
        var outputDone = false
        var outputSR   = inputSR

        while (!outputDone) {
            // Feed compressed data
            if (!inputDone) {
                val inIdx = codec.dequeueInputBuffer(10_000L)
                if (inIdx >= 0) {
                    val buf  = codec.getInputBuffer(inIdx)!!
                    val size = extractor.readSampleData(buf, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(inIdx, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(inIdx, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }

            // Collect decoded PCM
            val outIdx = codec.dequeueOutputBuffer(info, 10_000L)
            when {
                outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val nf = codec.outputFormat
                    if (nf.containsKey(MediaFormat.KEY_SAMPLE_RATE))
                        outputSR = nf.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                }
                outIdx >= 0 -> {
                    if (info.size > 0) {
                        val outBuf = codec.getOutputBuffer(outIdx)!!
                        outBuf.position(info.offset)
                        outBuf.limit(info.offset + info.size)
                        val bytes = ByteArray(info.size)
                        outBuf.get(bytes)
                        raw.write(bytes)
                    }
                    codec.releaseOutputBuffer(outIdx, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0)
                        outputDone = true
                }
            }
        }

        codec.stop(); codec.release(); extractor.release()

        // Bytes → ShortArray (little-endian PCM-16)
        val pcmBytes = raw.toByteArray()
        val shortBuf = ByteBuffer.wrap(pcmBytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        var samples  = ShortArray(pcmBytes.size / 2).also { shortBuf.get(it) }

        // Stereo/multi → mono
        if (channels > 1) {
            samples = ShortArray(samples.size / channels) { i ->
                var s = 0L
                for (ch in 0 until channels) s += samples[i * channels + ch]
                (s / channels).toShort()
            }
        }

        // Resample to 16 kHz if needed
        if (outputSR != TARGET_SR) samples = resample(samples, outputSR, TARGET_SR)

        writeWav(samples, TARGET_SR, outputPath)
    }

    private fun resample(input: ShortArray, from: Int, to: Int): ShortArray {
        val ratio = from.toDouble() / to
        val out   = ShortArray((input.size / ratio).toInt())
        for (i in out.indices) {
            val pos = i * ratio
            val idx = pos.toInt().coerceIn(0, input.size - 1)
            val frac = (pos - idx).toFloat()
            out[i] = if (idx + 1 < input.size)
                (input[idx] * (1f - frac) + input[idx + 1] * frac).toInt().toShort()
            else
                input[idx]
        }
        return out
    }

    private fun writeWav(samples: ShortArray, sr: Int, path: String) {
        val data = samples.size * 2
        val buf  = ByteBuffer.allocate(44 + data).order(ByteOrder.LITTLE_ENDIAN)
        buf.put("RIFF".toByteArray(Charsets.US_ASCII))
        buf.putInt(36 + data)
        buf.put("WAVE".toByteArray(Charsets.US_ASCII))
        buf.put("fmt ".toByteArray(Charsets.US_ASCII))
        buf.putInt(16);  buf.putShort(1)      // PCM
        buf.putShort(1)                        // mono
        buf.putInt(sr);  buf.putInt(sr * 2)   // sample/byte rate
        buf.putShort(2); buf.putShort(16)      // block align / bit depth
        buf.put("data".toByteArray(Charsets.US_ASCII))
        buf.putInt(data)
        for (s in samples) buf.putShort(s)
        File(path).writeBytes(buf.array())
    }
}
