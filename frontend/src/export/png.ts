/**
 * PNG bytes from a canvas data URL.
 *
 * ECharts hands a chart image back as a `data:image/png;base64,…` URL, and the
 * download helper takes bytes, so the base64 payload is decoded here and nothing
 * else: no pixel is read, re-encoded or resized, and no image is drawn.
 *
 * A payload that is missing or empty raises an error rather than returning an
 * empty file, so a failed export is reported as a failure instead of saving a
 * zero-byte PNG.
 */

/** The base64 payload of a data URL, decoded to bytes. */
export function bytesFromDataUrl(dataUrl: string): Uint8Array {
  const comma = dataUrl.indexOf(',')
  if (comma < 0) throw new Error('The chart image could not be read.')
  const payload = dataUrl.slice(comma + 1)
  if (payload === '') throw new Error('The chart produced an empty image.')
  const binary = atob(payload)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }
  if (bytes.length === 0) throw new Error('The chart produced an empty image.')
  return bytes
}
