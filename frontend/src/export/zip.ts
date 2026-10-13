/**
 * Minimal ZIP writer: store method (no compression), no dependencies.
 *
 * The download-results package needs one file that the browser can save, and a
 * ZIP is what the Shiny app produces too. Compression is deliberately omitted
 * because every entry is small text and a deflate implementation would be
 * several times the size of this file; a store-only archive is still a valid
 * ZIP that Windows Explorer, macOS Archive Utility and `unzip` all open.
 *
 * This module contains no model logic: it takes text that already exists and
 * writes bytes.
 */

/** CRC-32 (IEEE 802.3, polynomial 0xEDB88320) lookup table. */
const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let n = 0; n < 256; n += 1) {
    let c = n
    for (let k = 0; k < 8; k += 1) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    }
    table[n] = c >>> 0
  }
  return table
})()

/** CRC-32 of a byte array, as ZIP requires for every entry. */
export function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff
  for (let i = 0; i < bytes.length; i += 1) {
    crc = CRC_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8)
  }
  return (crc ^ 0xffffffff) >>> 0
}

export interface ZipEntry {
  /** File name inside the archive; forward slashes separate folders. */
  name: string
  /** File contents, written as UTF-8. */
  text: string
}

function writeUint16(view: DataView, offset: number, value: number): number {
  view.setUint16(offset, value, true)
  return offset + 2
}

function writeUint32(view: DataView, offset: number, value: number): number {
  view.setUint32(offset, value >>> 0, true)
  return offset + 4
}

/** DOS date and time, the only timestamp format a ZIP header holds. */
function dosDateTime(date: Date): { time: number; date: number } {
  const time =
    (Math.floor(date.getSeconds() / 2) & 0x1f) |
    ((date.getMinutes() & 0x3f) << 5) |
    ((date.getHours() & 0x1f) << 11)
  const day =
    (date.getDate() & 0x1f) |
    (((date.getMonth() + 1) & 0x0f) << 5) |
    ((Math.max(date.getFullYear() - 1980, 0) & 0x7f) << 9)
  return { time, date: day }
}

/** Builds a complete ZIP archive from text entries. */
export function buildZip(entries: ZipEntry[], now: Date = new Date()): Uint8Array {
  const encoder = new TextEncoder()
  const { time, date } = dosDateTime(now)
  const chunks: Uint8Array[] = []
  const central: Uint8Array[] = []
  let offset = 0

  for (const entry of entries) {
    const nameBytes = encoder.encode(entry.name)
    const dataBytes = encoder.encode(entry.text)
    const crc = crc32(dataBytes)

    const header = new Uint8Array(30 + nameBytes.length)
    const headerView = new DataView(header.buffer)
    let cursor = 0
    cursor = writeUint32(headerView, cursor, 0x04034b50) // local file header
    cursor = writeUint16(headerView, cursor, 20) // version needed
    cursor = writeUint16(headerView, cursor, 0x0800) // UTF-8 file names
    cursor = writeUint16(headerView, cursor, 0) // method: store
    cursor = writeUint16(headerView, cursor, time)
    cursor = writeUint16(headerView, cursor, date)
    cursor = writeUint32(headerView, cursor, crc)
    cursor = writeUint32(headerView, cursor, dataBytes.length)
    cursor = writeUint32(headerView, cursor, dataBytes.length)
    cursor = writeUint16(headerView, cursor, nameBytes.length)
    cursor = writeUint16(headerView, cursor, 0) // extra field length
    header.set(nameBytes, cursor)

    const directory = new Uint8Array(46 + nameBytes.length)
    const directoryView = new DataView(directory.buffer)
    cursor = 0
    cursor = writeUint32(directoryView, cursor, 0x02014b50) // central directory
    cursor = writeUint16(directoryView, cursor, 20) // version made by
    cursor = writeUint16(directoryView, cursor, 20) // version needed
    cursor = writeUint16(directoryView, cursor, 0x0800)
    cursor = writeUint16(directoryView, cursor, 0) // method: store
    cursor = writeUint16(directoryView, cursor, time)
    cursor = writeUint16(directoryView, cursor, date)
    cursor = writeUint32(directoryView, cursor, crc)
    cursor = writeUint32(directoryView, cursor, dataBytes.length)
    cursor = writeUint32(directoryView, cursor, dataBytes.length)
    cursor = writeUint16(directoryView, cursor, nameBytes.length)
    cursor = writeUint16(directoryView, cursor, 0) // extra
    cursor = writeUint16(directoryView, cursor, 0) // comment
    cursor = writeUint16(directoryView, cursor, 0) // disk number
    cursor = writeUint16(directoryView, cursor, 0) // internal attributes
    cursor = writeUint32(directoryView, cursor, 0) // external attributes
    cursor = writeUint32(directoryView, cursor, offset)
    directory.set(nameBytes, cursor)

    chunks.push(header, dataBytes)
    central.push(directory)
    offset += header.length + dataBytes.length
  }

  const centralSize = central.reduce((total, chunk) => total + chunk.length, 0)
  const end = new Uint8Array(22)
  const endView = new DataView(end.buffer)
  let cursor = 0
  cursor = writeUint32(endView, cursor, 0x06054b50) // end of central directory
  cursor = writeUint16(endView, cursor, 0) // disk number
  cursor = writeUint16(endView, cursor, 0) // disk with central directory
  cursor = writeUint16(endView, cursor, entries.length)
  cursor = writeUint16(endView, cursor, entries.length)
  cursor = writeUint32(endView, cursor, centralSize)
  cursor = writeUint32(endView, cursor, offset)
  cursor = writeUint16(endView, cursor, 0) // archive comment length

  const total =
    chunks.reduce((size, chunk) => size + chunk.length, 0) + centralSize + end.length
  const archive = new Uint8Array(total)
  let position = 0
  for (const chunk of [...chunks, ...central, end]) {
    archive.set(chunk, position)
    position += chunk.length
  }
  return archive
}

/** Saves bytes to the user's downloads as the given file name. */
export function downloadBytes(bytes: Uint8Array, filename: string, type: string): void {
  const blob = new Blob([bytes as BlobPart], { type })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  // Revoke on the next tick so the download has picked the blob up.
  setTimeout(() => URL.revokeObjectURL(url), 0)
}
