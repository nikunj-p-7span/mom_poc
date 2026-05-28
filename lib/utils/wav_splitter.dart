import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WavSplitter {
  /// Splits a WAV file into smaller valid WAV files, each under maxChunkSizeBytes.
  /// Returns a list of the split files. If the file is not a WAV or splitting is not needed,
  /// returns the original file in a list.
  static Future<List<File>> splitWavFile(File inputFile, {int maxChunkSizeBytes = 20 * 1024 * 1024}) async {
    final Uint8List bytes = await inputFile.readAsBytes();
    
    // Minimum WAV header is 44 bytes
    if (bytes.length < 44) {
      return [inputFile];
    }

    // Verify RIFF and WAVE header
    final String riffStr = String.fromCharCodes(bytes.sublist(0, 4));
    final String waveStr = String.fromCharCodes(bytes.sublist(8, 12));
    if (riffStr != 'RIFF' || waveStr != 'WAVE') {
      // Not a standard RIFF/WAVE file
      return [inputFile];
    }

    // Find the 'data' chunk offset
    int offset = 12;
    int dataPayloadOffset = -1;
    int originalDataSize = -1;

    while (offset + 8 <= bytes.length) {
      final String chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final int chunkSize = ByteData.sublistView(bytes, offset + 4, offset + 8).getUint32(0, Endian.little);
      
      if (chunkId == 'data') {
        dataPayloadOffset = offset + 8;
        originalDataSize = chunkSize;
        break;
      }
      
      offset += 8 + chunkSize;
    }

    if (dataPayloadOffset == -1 || originalDataSize == -1) {
      // 'data' chunk not found
      return [inputFile];
    }

    final int totalPayloadLength = bytes.length - dataPayloadOffset;
    if (totalPayloadLength <= maxChunkSizeBytes) {
      // File payload is already small enough
      return [inputFile];
    }

    final List<File> splitFiles = [];
    final tempDir = await getTemporaryDirectory();
    final baseName = p.basenameWithoutExtension(inputFile.path);

    int chunkIndex = 0;
    int currentPayloadOffset = dataPayloadOffset;

    while (currentPayloadOffset < bytes.length) {
      // Calculate data size for this chunk
      int remainingPayload = bytes.length - currentPayloadOffset;
      int chunkDataSize = remainingPayload > maxChunkSizeBytes ? maxChunkSizeBytes : remainingPayload;

      // Extract original header prefix up to the data payload offset
      final Uint8List chunkHeader = Uint8List.fromList(bytes.sublist(0, dataPayloadOffset));
      
      // Update the RIFF size at byte index 4-7
      // RIFF Size = (dataPayloadOffset - 8) + chunkDataSize
      final int riffSize = (dataPayloadOffset - 8) + chunkDataSize;
      final ByteData riffSizeByteData = ByteData(4)..setUint32(0, riffSize, Endian.little);
      chunkHeader.setRange(4, 8, riffSizeByteData.buffer.asUint8List());

      // Update the 'data' chunk size at byte index (dataPayloadOffset - 4) to (dataPayloadOffset)
      final ByteData dataSizeByteData = ByteData(4)..setUint32(0, chunkDataSize, Endian.little);
      chunkHeader.setRange(dataPayloadOffset - 4, dataPayloadOffset, dataSizeByteData.buffer.asUint8List());

      // Combine header and the data slice
      final BytesBuilder chunkBuilder = BytesBuilder();
      chunkBuilder.add(chunkHeader);
      chunkBuilder.add(bytes.sublist(currentPayloadOffset, currentPayloadOffset + chunkDataSize));

      final Uint8List chunkBytes = chunkBuilder.takeBytes();
      
      // Save chunk to temporary file
      final String chunkPath = p.join(tempDir.path, '${baseName}_part${chunkIndex + 1}.wav');
      final File chunkFile = File(chunkPath);
      await chunkFile.writeAsBytes(chunkBytes);

      splitFiles.add(chunkFile);

      // Move to next chunk
      currentPayloadOffset += chunkDataSize;
      chunkIndex++;
    }

    return splitFiles;
  }
}
