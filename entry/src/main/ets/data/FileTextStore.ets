import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { TextStore } from './SaveRepository';

// Only flat, application-owned names are accepted. No external paths or network access.
export class FileTextStore implements TextStore {
  private directory: string;
  constructor(filesDir: string) { this.directory = filesDir; }
  private path(key: string): string {
    if (!/^[a-z0-9.-]+$/.test(key) || key.includes('..')) { throw new Error('Invalid storage key'); }
    return this.directory + '/zeroecho-' + key;
  }
  async read(key: string): Promise<string> {
    const path = this.path(key);
    if (!fileIo.accessSync(path)) { return ''; }
    if (fileIo.statSync(path).size > 1048576) { throw new Error('Storage file too large'); }
    return fileIo.readTextSync(path);
  }
  async writeAtomic(key: string, value: string): Promise<void> {
    const path = this.path(key);
    const temporary = path + '.tmp';
    const buffer = new util.TextEncoder().encodeInto(value);
    if (buffer.byteLength > 1048576) { throw new Error('Storage file too large'); }
    const file = fileIo.openSync(temporary, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      const written = fileIo.writeSync(file.fd, buffer.buffer);
      if (written !== buffer.byteLength) { throw new Error('Incomplete storage write'); }
      fileIo.fsyncSync(file.fd);
    } finally { fileIo.closeSync(file); }
    if (fileIo.readTextSync(temporary) !== value) { throw new Error('Storage verification failed'); }
    // Same-directory rename happens only after the complete temporary file is verified.
    fileIo.renameSync(temporary, path);
  }
}
